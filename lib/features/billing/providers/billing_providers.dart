import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisab_backend/hisab_backend.dart';

import '../../../core/auth/auth_providers.dart';

/// Build-time staged rollout switch. Cloud builds opt in with
/// `--dart-define=HISAB_PLUS_ENABLED=true`; offline builds remain unchanged.
const bool hisabPlusEnabled = bool.fromEnvironment(
  'HISAB_PLUS_ENABLED',
  defaultValue: false,
);

final billingSnapshotProvider = FutureProvider<CloudBillingSnapshot>((
  ref,
) async {
  if (!hisabPlusEnabled) return const CloudBillingSnapshot.unavailable();
  ref.watch(authStateChangesProvider);
  final backend = cloudBackend;
  if (backend == null || !backend.auth.isAuthenticated) {
    return const CloudBillingSnapshot.unavailable();
  }
  return backend.billing.snapshot();
});

final billingOffersProvider = FutureProvider<List<CloudOffer>>((ref) async {
  if (!hisabPlusEnabled) return const <CloudOffer>[];
  ref.watch(authStateChangesProvider);
  final backend = cloudBackend;
  if (backend == null || !backend.auth.isAuthenticated) {
    return const <CloudOffer>[];
  }
  return backend.billing.offerings();
});

Future<CloudPurchaseResult> purchaseBillingOffer(
  WidgetRef ref,
  CloudOffer offer,
) async {
  final backend = cloudBackend;
  if (backend == null) {
    throw const CloudException(
      'Billing is unavailable in the offline build',
      kind: CloudErrorKind.invalidRequest,
      code: 'billing_unavailable',
    );
  }
  final result = await backend.billing.purchase(offer);
  ref.invalidate(billingSnapshotProvider);
  return result;
}

Future<void> restoreBillingPurchases(WidgetRef ref) async {
  final backend = cloudBackend;
  if (backend == null) return;
  await backend.billing.restorePurchases();
  ref.invalidate(billingSnapshotProvider);
}
