// ignore_for_file: avoid_print
//
// Cross-platform online integration test runner: starts local Supabase,
// runs integration_test/online_app_test.dart on web (with ChromeDriver) or Android,
// then stops Supabase. Logs to logs/online_tests_<timestamp>.log.
//
// Run from repo root: dart run tool/run_online_tests.dart [web|android]
// Default: web.
//
// Fail-safes: timeouts (supabase 5min, flutter 25min), line length cap (64KB), top-level catch.
// Prerequisites: Docker, Supabase CLI. For web: Chrome + ChromeDriver (port 4444). Set CHROME_EXECUTABLE if needed.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

const int _maxLineLength = 65536;
const Duration _supabaseTimeout = Duration(minutes: 5);
const Duration _flutterTestTimeout = Duration(minutes: 25);
const Duration _supabaseStatusTimeout = Duration(seconds: 30);
const Duration _supabaseStopTimeout = Duration(seconds: 30);

String _safeLine(String line) {
  if (line.length <= _maxLineLength) return line;
  return '${line.substring(0, _maxLineLength)} (truncated)';
}

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
  final platform = args.isNotEmpty ? args.first.toLowerCase() : 'web';
  if (platform != 'web' && platform != 'android') {
    print('Usage: dart run tool/run_online_tests.dart [web|android]');
    exit(1);
  }

  final projectRoot = _projectRoot();
  final timestamp = _timestamp();
  final logPath = p.join(projectRoot, 'logs', 'online_tests_$timestamp.log');
  final logFile = File(logPath);
  logFile.parent.createSync(recursive: true);
  final logSink = logFile.openWrite();

  Process? chromedriverProcess;
  int exitCode = 1;

  void tee(String line) {
    print(line);
    logSink.writeln(line);
    logSink.flush();
  }

  try {
    // ----- Prerequisites -----
    tee('==> Checking prerequisites...');
    if (!await _checkDocker()) {
      tee('ERROR: Docker is not running or not installed. Run "docker info" to check.');
    } else if (!await _checkSupabaseCli()) {
      tee('ERROR: Supabase CLI not found. Install: https://supabase.com/docs/guides/cli');
    } else if (platform == 'web' && !await _checkChromeDriver()) {
      tee('ERROR: ChromeDriver not on PATH (required for web). Version must match Chrome.');
    } else {
      // ----- Start Supabase -----
      tee('==> Starting local Supabase...');
      final startExit = await _runProcessTeeWithTimeout(
        'supabase',
        ['start'],
        workingDirectory: projectRoot,
        tee: tee,
        timeout: _supabaseTimeout,
      );
      if (startExit != 0 && startExit != _exitTimeout) {
        tee('ERROR: supabase start failed');
      } else if (startExit == _exitTimeout) {
        tee('ERROR: supabase start timed out');
      } else {
        // ----- Get credentials -----
        final statusBuffer = StringBuffer();
        final statusExit = await _runProcessTeeWithTimeout(
          'supabase',
          ['status', '--output', 'json'],
          workingDirectory: projectRoot,
          tee: tee,
          timeout: _supabaseStatusTimeout,
          collectStdout: statusBuffer,
        );
        if (statusExit != 0 && statusExit != _exitTimeout) {
          tee('ERROR: supabase status failed');
        } else if (statusExit == _exitTimeout) {
          tee('ERROR: supabase status timed out');
        } else {
          Map<String, dynamic>? status;
          try {
            status = jsonDecode(statusBuffer.toString()) as Map<String, dynamic>;
          } catch (_) {}
          final supabaseUrl = status?['API_URL'] as String?;
          final supabaseAnonKey = status?['ANON_KEY'] as String?;
          if (supabaseUrl == null || supabaseUrl.isEmpty || supabaseAnonKey == null) {
            tee('ERROR: Could not get SUPABASE_URL/ANON_KEY from supabase status');
          } else {
            tee('    SUPABASE_URL=$supabaseUrl');

            // ----- Reset database -----
            tee('==> Resetting database (migrations + seed)...');
            final resetExit = await _runProcessTeeWithTimeout(
              'supabase',
              ['db', 'reset'],
              workingDirectory: projectRoot,
              tee: tee,
              timeout: _supabaseTimeout,
            );
            if (resetExit != 0 && resetExit != _exitTimeout) {
              tee('ERROR: supabase db reset failed');
            } else if (resetExit == _exitTimeout) {
              tee('ERROR: supabase db reset timed out');
            } else {
              // ----- ChromeDriver for web -----
              if (platform == 'web') {
                final portInUse = await _isPortInUse(4444);
                if (!portInUse) {
                  chromedriverProcess = await Process.start(
                    'chromedriver',
                    ['--port=4444'],
                    workingDirectory: projectRoot,
                    environment: Platform.environment,
                    runInShell: true,
                  );
                  await Future<void>.delayed(const Duration(seconds: 3));
                }
              }

              // ----- Run tests -----
              tee('==> Running online integration tests (platform=$platform)...');
              if (platform == 'web') {
                exitCode = await _runProcessTee(
                  'flutter',
                  [
                    'drive',
                    '--driver=test_driver/integration_test.dart',
                    '--target=integration_test/online_app_test.dart',
                    '-d',
                    'web-server',
                    '--release',
                    '--dart-define=SUPABASE_URL=$supabaseUrl',
                    '--dart-define=SUPABASE_ANON_KEY=$supabaseAnonKey',
                    '--web-browser-flag=--no-sandbox',
                    '--web-browser-flag=--disable-dev-shm-usage',
                  ],
                  workingDirectory: projectRoot,
                  tee: tee,
                  timeout: _flutterTestTimeout,
                );
              } else {
                final deviceId = await _getAndroidDeviceId(projectRoot);
                if (deviceId == null) {
                  tee('ERROR: No Android device found. Run "flutter devices" to list.');
                } else {
                  exitCode = await _runProcessTee(
                    'flutter',
                    [
                      'test',
                      'integration_test/online_app_test.dart',
                      '-d',
                      deviceId,
                      '--dart-define=SUPABASE_URL=$supabaseUrl',
                      '--dart-define=SUPABASE_ANON_KEY=$supabaseAnonKey',
                    ],
                    workingDirectory: projectRoot,
                    tee: tee,
                    timeout: _flutterTestTimeout,
                  );
                }
              }
            }
          }
        }
      }
    }
  } finally {
    tee('==> Stopping local Supabase...');
    final stopProc = await Process.start(
      'supabase',
      ['stop'],
      workingDirectory: projectRoot,
      runInShell: true,
    );
    await Future.any(<Future<void>>[
      stopProc.exitCode,
      Future<void>.delayed(_supabaseStopTimeout).then((_) {
        stopProc.kill(ProcessSignal.sigterm);
        tee('supabase stop timed out; process killed.');
      }),
    ]);
    chromedriverProcess?.kill(ProcessSignal.sigterm);
    if (chromedriverProcess != null) tee('Stopped ChromeDriver.');
    if (exitCode == 0) {
      tee('Online tests: PASS');
    } else {
      tee('Online tests: FAILED (see log: $logPath)');
    }
    await logSink.close();
    exit(exitCode);
  }
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

Future<bool> _checkDocker() async {
  final r = await Process.run('docker', ['info'], runInShell: true);
  return r.exitCode == 0;
}

Future<bool> _checkSupabaseCli() async {
  final r = await Process.run('supabase', ['--version'], runInShell: true);
  return r.exitCode == 0;
}

Future<bool> _checkChromeDriver() async {
  final r = await Process.run('chromedriver', ['--version'], runInShell: true);
  return r.exitCode == 0;
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

const int _exitTimeout = -2;

Future<int> _runProcessTeeWithTimeout(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
  required void Function(String) tee,
  required Duration timeout,
  StringBuffer? collectStdout,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: Platform.environment,
    runInShell: true,
  );
  void onLine(String line) {
    final safe = _safeLine(line);
    tee(safe);
    collectStdout?.writeln(safe);
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

  final result = await Future.any(<Future<int>>[
    exitCodeFuture,
    Future.delayed(timeout).then((_) async {
      process.kill(ProcessSignal.sigterm);
      try {
        await exitCodeFuture;
      } catch (_) {}
      tee(
          'Process timed out after ${timeout.inMinutes} minutes and was killed.');
      return _exitTimeout;
    }),
  ]);
  await stdoutDone.catchError((_) {});
  await stderrDone.catchError((_) {});
  return result;
}

Future<int> _runProcessTee(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
  required void Function(String) tee,
  Duration? timeout,
}) async {
  if (timeout != null) {
    return _runProcessTeeWithTimeout(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      tee: tee,
      timeout: timeout,
    );
  }
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: Platform.environment,
    runInShell: true,
  );
  void onLine(String line) => tee(_safeLine(line));
  await Future.wait(<Future<void>>[
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(onLine)
        .asFuture(),
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(onLine)
        .asFuture(),
  ]);
  return await process.exitCode;
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
