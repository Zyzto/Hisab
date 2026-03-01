// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/common.dart';

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
      print('Integration test run incomplete: device/emulator connection was lost.');
      print('This is usually an emulator or ADB issue, not a test failure.');
      print('Error: $e');
      print('');
      print('See test/README.md "Android emulator troubleshooting" for workarounds.');
    } else {
      print('driver.requestData failed: $e');
    }
    exit(1);
  }

  await driver.close();

  final response = Response.fromJson(jsonResult);

  // Print stage diagnostic log from reportData (works on web where
  // failure details are empty).
  if (response.data != null) {
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
  }

  if (response.allTestsPassed) {
    print('All tests passed.');
    exit(0);
  }

  print('Failure Details:');
  if (response.failureDetails != null) {
    for (final failure in response.failureDetails!) {
      print('\n=== FAILED: ${failure.methodName} ===');
      print(failure.details ?? '(no details captured)');
      print('=== END ===');
    }
  }

  exit(1);
}
