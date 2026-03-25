// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/common.dart';
import 'package:integration_test/integration_test_driver.dart'
    show writeResponseData;

Future<void> main() async {
  FlutterDriver driver;
  try {
    driver = await FlutterDriver.connect();
  } catch (e) {
    print('FlutterDriver.connect failed: $e');
    exit(1);
  }

  String? jsonResult;
  try {
    jsonResult = await driver.requestData(
      null,
      timeout: const Duration(minutes: 20),
    );
  } catch (e) {
    await driver.close();
    final msg = e.toString();
    if (msg.contains('Service has disappeared') ||
        msg.contains('Service connection disposed') ||
        msg.contains('VmServiceDisappeared')) {
      print('');
      print(
        'Integration test run incomplete: device/emulator connection was lost.',
      );
      print('This is usually an emulator or ADB issue, not a test failure.');
      print('Error: $e');
      print('');
      print(
        'See test/README.md "Android emulator troubleshooting" for workarounds.',
      );
    } else {
      print('driver.requestData failed: $e');
    }
    exit(1);
  }

  await driver.close();

  final response = Response.fromJson(jsonResult);

  _printStageLog(response);

  if (response.allTestsPassed) {
    print('All tests passed.');
    await writeResponseData(response.data);
    exit(0);
  }

  print('Failure Details:');
  if (response.failureDetails != null) {
    for (final failure in response.failureDetails!) {
      print('\n=== FAILED: ${failure.methodName} ===');
      final details = failure.details;
      print((details != null && details.trim().isNotEmpty)
          ? details
          : '(no details captured — check Stage Log above for last stage)');
      print('=== END ===');
    }
  }

  await writeResponseData(response.data);
  exit(1);
}

void _printStageLog(Response response) {
  if (response.data == null) return;

  final stageLog = response.data!['stage_log'];
  if (stageLog is List && stageLog.isNotEmpty) {
    print('\n=== Stage Log ===');
    for (final entry in stageLog) {
      print('  $entry');
    }
    print('=================\n');
  }
  final lastStage = response.data!['last_stage'];
  if (lastStage != null) {
    print('Last stage: $lastStage\n');
  }
  final bootstrapError = response.data!['bootstrap_error'];
  if (bootstrapError != null) {
    print('Bootstrap Error:\n$bootstrapError\n');
  }
}
