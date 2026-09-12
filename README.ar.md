# حساب Hisab

حساب هو تطبيق مفتوح المصدر لتقسيم مصاريف الرحلات والسكن والمجموعات، مع دعم
المصاريف الشخصية. يعمل على Android وiOS والويب عبر Flutter.

النسخة العامة محلية بالكامل:

- لا تحتاج إلى حساب أو خادم أو اشتراك أو إعلانات؛
- مجموعات ومشاركون ومصاريف وتسويات غير محدودة محلياً؛
- قراءة الإيصالات محلياً على الأجهزة المدعومة؛
- ماسح معاملات محلي على Android مع مسودات وسجل؛
- تصدير واستيراد نسخ JSON وCSV وZIP.

تُحفظ البيانات في قاعدة SQLite على الجهاز. استخدم الإعدادات ← البيانات والنسخ
الاحتياطية لنقل سجلاتك بين الأجهزة. تبقى السجلات المحلية والجداول القديمة
أثناء الترقية.

## البدء السريع

```bash
flutter pub get
flutter run -d chrome
flutter run --flavor foss
```

إذا لم تكن ملفات PowerSync الخاصة بالويب موجودة في نسخة جديدة، نفّذ:

```bash
flutter pub run powersync:setup_web
```

لا تحتاج إلى مفاتيح أو متغيرات بيئة أو `dart-define`.

## البناء والفحوصات

```bash
bash scripts/ci/build_android.sh debug
bash scripts/ci/build_web.sh
bash scripts/ci/assert_offline_only.sh
bash scripts/verify_infra.sh
flutter analyze
flutter test
```

نكهة Android العامة الوحيدة هي `foss`. يستخدم iOS والويب مصادر التطبيق
المحلية نفسها.

تتحقق فحوصات الإصدار أيضاً من بقاء التطبيق مكتفياً ذاتياً. أبقِ مخرجات البناء
خارج شجرة المصدر عند تجهيز الإصدار.

## الخصوصية وحذف البيانات

راجع [سياسة الخصوصية](https://hisab.shenepoy.com/ar/privacy/) و[تعليمات حذف
البيانات المحلية](https://hisab.shenepoy.com/ar/delete-account/). لا ينشئ
التطبيق حساباً ولا يحفظ السجلات على خادم لحساب.

راجع [CONTRIBUTING.md](CONTRIBUTING.md) و[SECURITY.md](SECURITY.md) و[LICENSE](LICENSE).
