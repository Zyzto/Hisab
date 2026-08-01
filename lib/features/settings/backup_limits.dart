/// Payload caps for backup parse/import (fail closed).
abstract final class BackupLimits {
  static const int maxFileBytes = 40 * 1024 * 1024; // 40 MB
  static const int maxUncompressedZipBytes = 80 * 1024 * 1024;
  static const int maxZipEntries = 2000;
  static const int maxReceiptBytes = 8 * 1024 * 1024;

  static const int maxGroups = 200;
  static const int maxParticipants = 2000;
  static const int maxExpenses = 20000;
  static const int maxTags = 2000;

  static const int maxGroupName = 200;
  static const int maxParticipantName = 100;
  static const int maxExpenseTitle = 500;
  static const int maxDescription = 20000;
  static const int maxTagLabel = 100;
  static const int maxTagIconName = 80;
  static const int maxGroupIcon = 80;
  static const int maxImagePaths = 10;
  static const int maxImagePathLength = 2000;
  static const int maxLineItems = 200;
  static const int maxSplitShareEntries = 200;
  static const int maxSnapshotJsonBytes = 500000;
  static const int maxLineItemsJsonBytes = 200000;
}
