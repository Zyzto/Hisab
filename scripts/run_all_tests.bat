@echo off
REM Run all tests (unit/widget, then Android + web integration in parallel).
REM Wrapper for: dart run tool/run_all_tests.dart
REM Options: --skip-unit, --skip-android, --skip-web, --no-avd
cd /d "%~dp0\.."
dart run tool/run_all_tests.dart %*
