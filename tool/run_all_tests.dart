// ignore_for_file: avoid_print
//
// Cross-platform test runner: (1) flutter test (unit/widget), (2) in parallel:
// Android integration (AVD + flutter test integration_test/app_test.dart) and
// web integration (ChromeDriver + flutter drive). (3) Summary and log paths.
//
// Run from repo root: dart run tool/run_all_tests.dart
// Options: --skip-unit, --skip-android, --skip-web, --no-avd, --android-drive. Example: only Android = --skip-unit --skip-web (add --android-drive if VM connection fails).
//
// Logs: logs/test_run_<timestamp>/
// Fail-safes: timeouts (unit 15min, integration 25min), line length cap (64KB), top-level catch.
// Prerequisites: Flutter SDK, Dart SDK. Android: device or AVD. Web: Chrome + ChromeDriver (port 4444). Set CHROME_EXECUTABLE if needed.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Exit code used when a process is killed due to timeout.
const int _exitTimeout = -2;

/// Max characters per line when streaming (avoids unbounded memory from runaway output).
const int _maxLineLength = 65536;

/// Timeout for unit/widget tests.
const Duration _unitTimeout = Duration(minutes: 15);

/// Timeout for integration tests (Android or web).
const Duration _integrationTimeout = Duration(minutes: 25);

Future<void> main(List<String> args) async {
  try {
    await _run(args);
  } catch (e, st) {
    print('Fatal error: $e');
    print(st);
    exit(1);
  }
}

Future<void> _run(List<String> args) async {
  final skipUnit = args.contains('--skip-unit');
  final skipAndroid = args.contains('--skip-android');
  final skipWeb = args.contains('--skip-web');
  final noAvd = args.contains('--no-avd');
  final androidDrive = args.contains('--android-drive');

  final projectRoot = _projectRoot();
  final timestamp = _timestamp();
  final logDir = Directory(p.join(projectRoot, 'logs', 'test_run_$timestamp'));
  logDir.createSync(recursive: true);

  int unitExitCode = 0;
  int androidExitCode = 0;
  int webExitCode = 0;
  Process? chromedriverProcess;

  try {
    // ----- Phase 1: Unit & widget tests -----
    if (skipUnit) {
      print('==> Phase 1: Unit & widget tests (skipped)');
      unitExitCode = -1;
    } else {
      print('==> Phase 1: Unit & widget tests');
      final unitLog = File(p.join(logDir.path, 'unit_widget.log'));
      unitExitCode = await _runProcess(
        'flutter',
        ['test'],
        workingDirectory: projectRoot,
        logFile: unitLog,
        timeout: _unitTimeout,
      );
      if (unitExitCode != 0) {
        print('Unit & widget tests failed (exit $unitExitCode). Continuing to integration phases.');
      }
    }

    // ----- Phase 2: Integration (Android + Web in parallel unless skipped) -----
    if (skipAndroid) {
      print('==> Phase 2a: Android integration (skipped)');
    }
    final androidFuture = skipAndroid
        ? Future<int>.value(-1)
        : _runIntegrationAndroid(projectRoot, logDir, noAvd, androidDrive);
    if (skipWeb) {
      print('==> Phase 2b: Web integration (skipped)');
    }
    final webFuture = skipWeb
        ? Future<int>.value(-1)
        : _runIntegrationWeb(projectRoot, logDir, (p) => chromedriverProcess = p);

    final results = await Future.wait([androidFuture, webFuture]);
    if (!skipAndroid) androidExitCode = results[0];
    if (!skipWeb) webExitCode = results[1];
  } finally {
    chromedriverProcess?.kill(ProcessSignal.sigterm);
    if (chromedriverProcess != null) print('Stopped ChromeDriver.');
  }

  // ----- Phase 3: Summary -----
  _printSummary(
    projectRoot: projectRoot,
    logDir: logDir,
    unitExitCode: skipUnit ? null : unitExitCode,
    androidExitCode: skipAndroid ? null : androidExitCode,
    webExitCode: skipWeb ? null : webExitCode,
  );

  final failed = (!skipUnit && unitExitCode != 0) ||
      (!skipAndroid && androidExitCode != 0 && androidExitCode != -1) ||
      (!skipWeb && webExitCode != 0 && webExitCode != -1);
  exit(failed ? 1 : 0);
}

String _safeLine(String line) {
  if (line.length <= _maxLineLength) return line;
  return '${line.substring(0, _maxLineLength)} (truncated)';
}

String _projectRoot() {
  final scriptPath = Platform.script.toFilePath();
  return p.dirname(p.dirname(scriptPath));
}

String _timestamp() {
  final now = DateTime.now();
  return '${now.year}'
      '${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}_'
      '${now.hour.toString().padLeft(2, '0')}'
      '${now.minute.toString().padLeft(2, '0')}'
      '${now.second.toString().padLeft(2, '0')}';
}

Future<int> _runProcess(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
  File? logFile,
  Map<String, String>? environment,
  Duration? timeout,
}) async {
  final env = environment ?? Map<String, String>.from(Platform.environment);
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: env,
    runInShell: true,
  );
  final sink = logFile?.openWrite();
  void onLine(String line) {
    final safe = _safeLine(line);
    print(safe);
    sink?.writeln(safe);
  }

  final stdoutDone = process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(onLine)
      .asFuture();
  final stderrDone = process.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(onLine)
      .asFuture();

  final exitCodeFuture = process.exitCode;

  if (timeout != null) {
    final result = await Future.any(<Future<int>>[
      exitCodeFuture,
      Future.delayed(timeout).then((_) async {
        process.kill(ProcessSignal.sigterm);
        try {
          await exitCodeFuture;
        } catch (_) {}
        final msg =
            'Process timed out after ${timeout.inMinutes} minutes and was killed.';
        print(msg);
        sink?.writeln(msg);
        return _exitTimeout;
      }),
    ]);
    await stdoutDone.catchError((_) {});
    await stderrDone.catchError((_) {});
    await sink?.flush();
    await sink?.close();
    return result;
  }

  await Future.wait(<Future<void>>[stdoutDone, stderrDone]);
  await sink?.flush();
  await sink?.close();
  return await exitCodeFuture;
}

Future<int> _runIntegrationAndroid(String projectRoot, Directory logDir, bool noAvd, bool useDrive) async {
  print('==> Phase 2a: Android integration${useDrive ? ' (flutter drive)' : ''}');
  String? deviceId = await _getAndroidDeviceId(projectRoot);
  if (deviceId == null && !noAvd) {
    final launched = await _launchFirstEmulator(projectRoot);
    if (launched) deviceId = await _waitForAndroidDevice(projectRoot, timeoutSeconds: 120);
  }
  if (deviceId == null) {
    print('No Android device available. Skip Android integration.');
    return -1;
  }
  final logFile = File(p.join(logDir.path, 'integration_android.log'));
  final args = useDrive
      ? [
          'drive',
          '--driver=test_driver/integration_test.dart',
          '--target=integration_test/app_test.dart',
          '-d',
          deviceId,
        ]
      : ['test', 'integration_test/app_test.dart', '-d', deviceId];
  return _runProcess(
    'flutter',
    args,
    workingDirectory: projectRoot,
    logFile: logFile,
    timeout: _integrationTimeout,
  );
}

Future<String?> _getAndroidDeviceId(String projectRoot) async {
  final result = await Process.run(
    'flutter',
    ['devices', '--machine'],
    workingDirectory: projectRoot,
    runInShell: true,
  );
  if (result.exitCode != 0) return null;
  try {
    final list = jsonDecode(result.stdout as String) as List<dynamic>;
    for (final d in list) {
      final map = d as Map<String, dynamic>;
      final id = map['id'] as String?;
      final targetPlatform = map['targetPlatform'] as String? ?? map['platform'] as String?;
      if (id != null &&
          targetPlatform != null &&
          targetPlatform.toLowerCase().contains('android')) {
        return id;
      }
    }
  } catch (_) {}
  return null;
}

Future<bool> _launchFirstEmulator(String projectRoot) async {
  final result = await Process.run(
    'flutter',
    ['emulators', '--machine'],
    workingDirectory: projectRoot,
    runInShell: true,
  );
  if (result.exitCode != 0) return false;
  try {
    final list = jsonDecode(result.stdout as String) as List<dynamic>;
    final first = list.isNotEmpty ? list.first as Map<String, dynamic> : null;
    final id = first?['id'] as String?;
    if (id == null) return false;
    final launch = await Process.run(
      'flutter',
      ['emulators', '--launch', id],
      workingDirectory: projectRoot,
      runInShell: true,
    );
    return launch.exitCode == 0;
  } catch (_) {
    return false;
  }
}

Future<String?> _waitForAndroidDevice(String projectRoot, {int timeoutSeconds = 120}) async {
  final deadline = DateTime.now().add(Duration(seconds: timeoutSeconds));
  while (DateTime.now().isBefore(deadline)) {
    final id = await _getAndroidDeviceId(projectRoot);
    if (id != null) return id;
    await Future<void>.delayed(const Duration(seconds: 3));
  }
  return null;
}

Future<bool> _isPortInUse(int port) async {
  try {
    final socket = await Socket.connect('localhost', port, timeout: const Duration(seconds: 1));
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}

Future<int> _runIntegrationWeb(
  String projectRoot,
  Directory logDir,
  void Function(Process?) setChromeDriver,
) async {
  print('==> Phase 2b: Web integration');
  final portInUse = await _isPortInUse(4444);
  if (!portInUse) {
    final proc = await Process.start(
      'chromedriver',
      ['--port=4444'],
      workingDirectory: projectRoot,
      environment: Platform.environment,
      runInShell: true,
    );
    setChromeDriver(proc);
    await Future<void>.delayed(const Duration(seconds: 3));
  }
  final logFile = File(p.join(logDir.path, 'integration_web.log'));
  final exitCode = await _runProcess(
    'flutter',
    [
      'drive',
      '--driver=test_driver/integration_test.dart',
      '--target=integration_test/app_test.dart',
      '-d',
      'web-server',
      '--release',
      '--web-browser-flag=--no-sandbox',
      '--web-browser-flag=--disable-dev-shm-usage',
    ],
    workingDirectory: projectRoot,
    logFile: logFile,
    timeout: _integrationTimeout,
  );
  return exitCode;
}

void _printSummary({
  required String projectRoot,
  required Directory logDir,
  int? unitExitCode,
  int? androidExitCode,
  int? webExitCode,
}) {
  String result(int? code) {
    if (code == null) return 'SKIP';
    if (code == -1) return 'SKIP';
    if (code == _exitTimeout) return 'TIMEOUT';
    return code == 0 ? 'PASS' : 'FAIL';
  }

  final rel = p.relative(logDir.path, from: projectRoot);
  print('');
  print('=== Summary ===');
  print('Phase                 | Result | Log');
  print('----------------------|--------|---------------------------');
  print('Unit & widget         | ${result(unitExitCode)}    | $rel/unit_widget.log');
  print('Integration (Android) | ${result(androidExitCode)}    | $rel/integration_android.log');
  print('Integration (Web)     | ${result(webExitCode)}    | $rel/integration_web.log');
  print('');

  final failed = (unitExitCode != null && unitExitCode != 0 && unitExitCode != -1) ||
      (androidExitCode != null && androidExitCode != -1 && androidExitCode != 0) ||
      (webExitCode != null && webExitCode != -1 && webExitCode != 0);
  if (failed) {
    print('Errors in: $rel');
  }
}
