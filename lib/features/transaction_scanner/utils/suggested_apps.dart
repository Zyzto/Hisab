/// Known bank / wallet / SMS packages shown first in the app picker.
const List<({String packageName, String label})> suggestedScannerApps = [
  (packageName: 'sa.com.stcpay', label: 'STC Pay'),
  (packageName: 'com.alrajhibank.retail', label: 'Al Rajhi'),
  (packageName: 'com.alahli.mobile', label: 'SNB AlAhli'),
  (packageName: 'com.riyadbank.mobile', label: 'Riyad Bank'),
  (packageName: 'com.anb.mobile', label: 'ANB'),
  (packageName: 'com.sabb.mobile', label: 'SABB'),
  (packageName: 'com.bsf.retail', label: 'BSF'),
  (packageName: 'com.albilad', label: 'Bank Albilad'),
  (packageName: 'com.alinma', label: 'Alinma'),
  (packageName: 'com.emiratesnbd.android', label: 'Emirates NBD'),
  (packageName: 'com.adcb.bank', label: 'ADCB'),
  (packageName: 'ae.hsbc.hsbcmobilebanking', label: 'HSBC'),
  (packageName: 'com.google.android.apps.nbu.paisa.user', label: 'Google Pay'),
  (packageName: 'com.phonepe.app', label: 'PhonePe'),
  (packageName: 'net.one97.paytm', label: 'Paytm'),
  (packageName: 'com.paypal.android.p2pmobile', label: 'PayPal'),
  (packageName: 'com.revolut.revolut', label: 'Revolut'),
  (packageName: 'com.wise.android', label: 'Wise'),
  (packageName: 'com.google.android.apps.messaging', label: 'Messages'),
  (packageName: 'com.samsung.android.messaging', label: 'Samsung Messages'),
  (packageName: 'com.android.mms', label: 'SMS'),
  (packageName: 'com.google.android.gm', label: 'Gmail'),
];

bool isSuggestedScannerPackage(String packageName) =>
    suggestedScannerApps.any((a) => a.packageName == packageName);
