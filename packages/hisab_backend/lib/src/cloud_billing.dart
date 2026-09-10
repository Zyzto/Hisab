import 'models.dart';

/// Vendor-neutral hosted billing and entitlement interface.
///
/// Implementations own provider SDKs, purchase verification, and subscription
/// lifecycle handling. Callers only need to understand offers, entitlement
/// snapshots, and the small set of user actions below.
abstract interface class CloudBilling {
  /// Returns the last server-backed entitlement and quota snapshot.
  ///
  /// Implementations may return a cached snapshot while offline. A successful
  /// refresh must never grant access beyond what the backend has verified.
  Future<CloudBillingSnapshot> snapshot();

  /// Returns the currently configured localized offers.
  Future<List<CloudOffer>> offerings();

  /// Starts a purchase for [offer] and returns the resulting entitlement.
  ///
  /// A cancelled purchase returns [CloudPurchaseStatus.cancelled]; provider
  /// and network failures are translated to [CloudException].
  Future<CloudPurchaseResult> purchase(CloudOffer offer);

  /// Restores a store purchase, or refreshes the current web customer.
  Future<void> restorePurchases();

  /// Returns the provider's subscription-management URL when available.
  Future<Uri?> managementUrl();
}

/// The product plans understood by the app.
enum CloudBillingPlan { free, plus }

/// The server/provider lifecycle state for an entitlement.
enum CloudEntitlementStatus {
  unavailable,
  free,
  active,
  grace,
  pastDue,
  expired,
}

/// The provider that supplied the current entitlement.
enum CloudBillingSource { none, paddle, appStore, googlePlay, other }

/// A localized product exposed by the billing provider.
class CloudOffer {
  const CloudOffer({
    required this.identifier,
    required this.title,
    required this.description,
    required this.price,
    required this.currencyCode,
    required this.period,
  });

  final String identifier;
  final String title;
  final String description;
  final String price;
  final String currencyCode;
  final String period;
}

/// Usage for one hosted group.
class CloudGroupUsage {
  const CloudGroupUsage({
    required this.groupId,
    required this.people,
    required this.expenses,
    required this.plusSponsored,
  });

  final String groupId;
  final int people;
  final int expenses;
  final bool plusSponsored;
}

/// Account and group usage returned by the backend.
class CloudBillingUsage {
  const CloudBillingUsage({
    this.groups = const <CloudGroupUsage>[],
    this.receiptBytes = 0,
  });

  final List<CloudGroupUsage> groups;
  final int receiptBytes;
}

/// Limits for the current plan.
class CloudBillingLimits {
  const CloudBillingLimits({
    required this.maxGroups,
    required this.maxPeoplePerGroup,
    required this.maxExpensesPerGroup,
    required this.maxReceiptBytes,
  });

  final int? maxGroups;
  final int? maxPeoplePerGroup;
  final int? maxExpensesPerGroup;
  final int? maxReceiptBytes;
}

/// The access and quota state the UI can render without knowing a provider.
class CloudBillingSnapshot {
  const CloudBillingSnapshot({
    required this.plan,
    required this.status,
    required this.source,
    required this.usage,
    required this.limits,
    this.expiresAt,
    this.graceUntil,
    this.willRenew,
    this.configured = true,
  });

  const CloudBillingSnapshot.unavailable()
    : plan = CloudBillingPlan.free,
      status = CloudEntitlementStatus.unavailable,
      source = CloudBillingSource.none,
      usage = const CloudBillingUsage(),
      limits = const CloudBillingLimits(
        maxGroups: null,
        maxPeoplePerGroup: null,
        maxExpensesPerGroup: null,
        maxReceiptBytes: null,
      ),
      expiresAt = null,
      graceUntil = null,
      willRenew = null,
      configured = false;

  final CloudBillingPlan plan;
  final CloudEntitlementStatus status;
  final CloudBillingSource source;
  final CloudBillingUsage usage;
  final CloudBillingLimits limits;
  final DateTime? expiresAt;
  final DateTime? graceUntil;
  final bool? willRenew;
  final bool configured;

  bool get isPlus =>
      plan == CloudBillingPlan.plus &&
      (status == CloudEntitlementStatus.active ||
          status == CloudEntitlementStatus.grace ||
          status == CloudEntitlementStatus.pastDue);
}

enum CloudPurchaseStatus { completed, pending, cancelled }

class CloudPurchaseResult {
  const CloudPurchaseResult({required this.status, required this.snapshot});

  final CloudPurchaseStatus status;
  final CloudBillingSnapshot snapshot;
}
