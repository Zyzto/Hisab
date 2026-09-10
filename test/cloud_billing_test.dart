import 'package:flutter_test/flutter_test.dart';
import 'package:hisab_backend/hisab_backend.dart';

void main() {
  test('unavailable billing leaves offline builds unconfigured', () {
    const snapshot = CloudBillingSnapshot.unavailable();

    expect(snapshot.configured, isFalse);
    expect(snapshot.plan, CloudBillingPlan.free);
    expect(snapshot.status, CloudEntitlementStatus.unavailable);
    expect(snapshot.isPlus, isFalse);
    expect(snapshot.usage.groups, isEmpty);
  });

  test('active, grace, and past-due Plus entitlements grant access', () {
    CloudBillingSnapshot snapshot(CloudEntitlementStatus status) =>
        CloudBillingSnapshot(
          plan: CloudBillingPlan.plus,
          status: status,
          source: CloudBillingSource.paddle,
          usage: const CloudBillingUsage(),
          limits: const CloudBillingLimits(
            maxGroups: null,
            maxPeoplePerGroup: null,
            maxExpensesPerGroup: null,
            maxReceiptBytes: null,
          ),
        );

    expect(snapshot(CloudEntitlementStatus.active).isPlus, isTrue);
    expect(snapshot(CloudEntitlementStatus.grace).isPlus, isTrue);
    expect(snapshot(CloudEntitlementStatus.pastDue).isPlus, isTrue);
    expect(snapshot(CloudEntitlementStatus.expired).isPlus, isFalse);
  });

  test('free quota models preserve per-group usage and limits', () {
    const usage = CloudBillingUsage(
      groups: [
        CloudGroupUsage(
          groupId: 'group-1',
          people: 16,
          expenses: 200,
          plusSponsored: false,
        ),
      ],
      receiptBytes: 250 * 1024 * 1024,
    );
    const limits = CloudBillingLimits(
      maxGroups: 2,
      maxPeoplePerGroup: 16,
      maxExpensesPerGroup: 200,
      maxReceiptBytes: 250 * 1024 * 1024,
    );

    expect(usage.groups.single.people, 16);
    expect(usage.groups.single.expenses, 200);
    expect(limits.maxGroups, 2);
    expect(limits.maxReceiptBytes, 250 * 1024 * 1024);
  });
}
