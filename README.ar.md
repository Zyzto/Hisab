<!-- markdownlint-disable MD033 MD060 -->

<div dir="rtl" lang="ar">

<p align="center">
  <img src="assets/Hisab.png" alt="حساب" width="200" />
</p>

<h1 align="center">حساب — Hisab</h1>

<p align="center">
  <strong>قسّموا المصاريف. صفّوا الحسابات. واصِلوا بلا اتصال.</strong><br/>
  تطبيق لتقسيم مصاريف المجموعات وتصفية الحسابات<br/>
  في الرحلات والنزهات والسكن المشترك — مع ميزانيات شخصية.<br/>
  <span dir="ltr">Flutter</span> · يعمل أوفلاين · مزامنة سحابية اختيارية.
</p>

<p align="center">
  <a href="https://github.com/Zyzto/Hisab/releases/latest"><img alt="release" src="https://img.shields.io/github/v/release/Zyzto/Hisab?style=flat-square&color=2E7D32" /></a>
  <a href="https://github.com/Zyzto/Hisab"><img alt="repo" src="https://img.shields.io/badge/github-Zyzto%2FHisab-C0C0C0?style=flat-square" /></a>
  <a href="https://hisab.shenepoy.com"><img alt="web" src="https://img.shields.io/badge/web-hisab.shenepoy.com-2E7D32?style=flat-square" /></a>
  <a href="https://apps.obtainium.imranr.dev/redirect.html?r=obtainium://add/https://github.com/Zyzto/Hisab/releases"><img alt="Obtainium" src="https://img.shields.io/badge/Obtainium-add-2E7D32?style=flat-square&logo=android&logoColor=white" /></a>
  <img alt="flutter" src="https://img.shields.io/badge/Flutter-%3E%3D3.11-C0C0C0?style=flat-square&logo=flutter&logoColor=white" />
  <a href="LICENSE"><img alt="license" src="https://img.shields.io/badge/license-AGPL--3.0-2E7D32?style=flat-square" /></a>
</p>

<p align="center">
  <a href="https://hisab.shenepoy.com"><strong>افتح التطبيق على الويب</strong></a>
  ·
  <a href="https://github.com/Zyzto/Hisab/releases/latest">آخر إصدار</a>
  ·
  <a href="docs/README.md">الوثائق</a>
</p>

<p align="center">
  <a href="#ماذا-تقدّم">ماذا تقدّم؟</a> ·
  <a href="#لقطات">لقطات</a> ·
  <a href="#التثبيت">التثبيت</a> ·
  <a href="#التطوير">التطوير</a> ·
  <a href="#الوثائق">الوثائق</a>
  <br/>
  <a href="README.md"><span dir="ltr">English</span></a>
</p>

<p align="center">
  الاسم من العربية: <strong>حساب</strong>
  (<span dir="ltr"><em>ḥisāb</em></span>) — الحساب / التصفية / من عليه لمن.<br/>
  والاسم اللاتيني <span dir="ltr"><strong>Hisab</strong></span> مأخوذ منه.
</p>

</div>

---

<div dir="rtl" lang="ar">

## ماذا تقدّم؟

| | |
|---|---|
| **المجموعات والأشخاص** | رحلات أو نزهات أو سكن مشترك — مع ربط المشاركين بحسابات حقيقية عند الاتصال. |
| **المصاريف** | عملات متعددة، تصنيفات، إيصالات، تقسيم بالتساوي / حصص / مبالغ محددة، وتحويلات. |
| **الرصيد والتصفية** | من عليه لمن، اقتراحات بأقل دفعات ممكنة، وتسجيل الدفعات بضغطة. |
| **الملف الشخصي** | لوحة عبر المجموعات: الأرصدة، الإحصاءات، ميزانيات شخصية، ونشاط داخل التطبيق (متصل). |
| **قوائم شخصية** | تتبّع مصاريف وميزانية لك وحدك (دون واجهة تقسيم)؛ ومسودة اختيارية من ماسح إشعارات أندرويد. |
| **أوفلاين أولاً** | قاعدة محلية كاملة بـ <span dir="ltr">SQLite</span>. المزامنة والدعوات والأعضاء عند ربط خادم سحابي. |
| **اللغات** | الإنجليزية والعربية (من اليمين إلى اليسار)، وثيمات، وضبط خفيف للّون المميّز. |

**الأوضاع**

| الوضع | البيانات | إضافي |
|------|------|--------|
| **محلي فقط** (الافتراضي) | <span dir="ltr">SQLite</span> على الجهاز | كل شيء ما عدا تسجيل الدخول والمزامنة بين الأجهزة |
| **متصل** | خادم سحابي + كاش محلي | دعوات، أعضاء، إشعارات فورية، أجهزة متعددة |

إن انقطع الاتصال وأنت في الوضع المتصل: تُصفّ كتابة المصاريف وتُزامَن لاحقًا. الدعوات وإدارة الأعضاء تحتاج اتصالًا.

</div>

---

<div dir="rtl" lang="ar">

## لقطات

### الترحيب

<p align="center">
  <img src="screenshots/welcome-ar.png" alt="الترحيب" width="180" />
  <img src="screenshots/connection-ar.png" alt="وضع الاتصال" width="180" />
</p>

<p align="center">
  <sub>الترحيب · الاتصال (محلي فقط)</sub>
</p>

### المجموعات والمصاريف

<p align="center">
  <img src="screenshots/groups-ar.png" alt="قائمة المجموعات" width="180" />
  <img src="screenshots/add-expense-ar.png" alt="إضافة مصروف" width="180" />
  <img src="screenshots/settlement-ar.png" alt="تصفية الحساب" width="180" />
</p>

<p align="center">
  <sub>المجموعات · إضافة مصروف · تصفية الحساب</sub>
</p>

### عرض

<p align="center">
  <img src="screenshots/onboarding.gif" alt="عرض الترحيب حتى الوضع المحلي" width="220" />
  <img src="screenshots/expense-settle.gif" alt="فتح مجموعة ثم إضافة مصروف ثم التصفية" width="220" />
</p>

<p align="center">
  <sub>الترحيب · فتح مجموعة، إضافة مصروف، التصفية</sub>
</p>

<details>
<summary>السمة الداكنة</summary>

<p align="center">
  <img src="screenshots/welcome-ar-dark.png" alt="الترحيب (داكن)" width="140" />
  <img src="screenshots/connection-ar-dark.png" alt="الاتصال (داكن)" width="140" />
  <img src="screenshots/groups-ar-dark.png" alt="المجموعات (داكن)" width="140" />
  <img src="screenshots/add-expense-ar-dark.png" alt="إضافة مصروف (داكن)" width="140" />
  <img src="screenshots/settlement-ar-dark.png" alt="تصفية الحساب (داكن)" width="140" />
</p>

<p align="center">
  <sub>الترحيب · الاتصال · المجموعات · إضافة مصروف · تصفية الحساب</sub>
</p>

</details>

</div>

---

<div dir="rtl" lang="ar">

## نسختان

<span dir="ltr">Hisab</span> مفتوح النواة. هذا المستودع هو التطبيق كاملًا، ويُبنى منه تطبيق أوفلاين متكامل دون أي خادم. أما خدمة المزامنة المستضافة التي تشغّل الدعوات والمجموعات المشتركة وتعدد الأجهزة فهي مشروع منفصل ومغلق المصدر، ويتصل بالتطبيق عبر واجهة معرَّفة هنا في <span dir="ltr">[`packages/hisab_backend`](packages/hisab_backend)</span>.

| | **<span dir="ltr">FOSS</span>** | **<span dir="ltr">Cloud</span>** |
|---|---|---|
| يُبنى من | هذا المستودع وحده | هذا المستودع + حزمة خادم خاصة |
| الخادم | لا يوجد | <span dir="ltr">Supabase</span> مستضاف |
| معرّف التطبيق | <span dir="ltr">`com.shenepoy.hisab.foss`</span> | <span dir="ltr">`com.shenepoy.hisab`</span> |
| المجموعات والمصاريف والأرصدة والتصفية والميزانيات والإيصالات | نعم | نعم |
| تسجيل الدخول والدعوات والمجموعات المشتركة والإشعارات وتعدد الأجهزة | لا | نعم |
| الرخصة | <span dir="ltr">AGPL-3.0</span> | التطبيق <span dir="ltr">AGPL-3.0</span> والخادم مغلق |

كلتاهما منشورتان في [صفحة الإصدارات](https://github.com/Zyzto/Hisab/releases/latest) نفسها، وتُثبَّتان جنبًا إلى جنب، فتجربة إحداهما لا تحذف الأخرى.

ولستم محصورين بهما: الخادم واجهة لا مزوّدًا بعينه، فمن نفّذها على خادمه حصل على نسخة ثالثة يملكها من طرف إلى طرف. الدليل الكامل في <span dir="ltr">[docs/SELF_HOSTING.md](docs/SELF_HOSTING.md)</span>، والسلوك المتوقع من الخادم في <span dir="ltr">[docs/BACKEND_BEHAVIOUR.md](docs/BACKEND_BEHAVIOUR.md)</span>.

</div>

---

<div dir="rtl" lang="ar">

## التثبيت

### الويب / <span dir="ltr">PWA</span>

مباشر على **[hisab.shenepoy.com](https://hisab.shenepoy.com)** (<span dir="ltr">Firebase Hosting</span>) — وهي النسخة السحابية.  
ثبّته من بانر التطبيق عند ظهوره (كروم أندرويد يستخدم طلب التثبيت الأصلي؛ آيفون وآيباد والمتصفحات الأخرى عبر «إضافة للشاشة الرئيسية»). على iOS افتح تطبيق الشاشة الرئيسية لدعم إشعارات الويب. يعمل أوفلاين بعد التثبيت.

### أندرويد

| الخيار | |
|--------|--|
| **<span dir="ltr">Obtainium</span>** (موصى به) | [![Obtainium](https://img.shields.io/badge/Obtainium-add-2E7D32?style=flat-square&logo=android&logoColor=white)](https://apps.obtainium.imranr.dev/redirect.html?r=obtainium://add/https://github.com/Zyzto/Hisab/releases) — يتابع [إصدارات GitHub](https://github.com/Zyzto/Hisab/releases) |
| **<span dir="ltr">APK</span> — النسخة السحابية** | <span dir="ltr">`cloud-<abi>-release.apk`</span> من [آخر إصدار](https://github.com/Zyzto/Hisab/releases/latest) |
| **<span dir="ltr">APK</span> — نسخة <span dir="ltr">FOSS</span>** | <span dir="ltr">`app-<abi>-foss-release.apk`</span> من الإصدار نفسه — أوفلاين فقط، مبنية كليًا من هذا المستودع |
| **متجر Play** | [الصفحة](https://play.google.com/store/apps/details?id=com.shenepoy.hisab) (قيد الإعداد / عند النشر) |

اختر <span dir="ltr">`arm64-v8a`</span> إلا إن كان جهازكم قديمًا.

</div>

---

<div dir="rtl" lang="ar">

## التطوير

**المتطلبات:** <span dir="ltr">Flutter / Dart `^3.11`</span>

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

هذا كل الإعداد. لا خادم تضبطونه، ولا مفاتيح تطلبونها، ولا <span dir="ltr">`--dart-define`</span> تمرّرونه — فحزمة <span dir="ltr">`packages/hisab_cloud`</span> المرفقة فارغة عمدًا، فيعمل التطبيق **محليًا فقط** وتعمل معه كل ميزة لا تحتاج خادمًا بطبيعتها.

**الويب:** ولّد <span dir="ltr">WASM</span> مرة إن لزم:

```bash
flutter pub run powersync:setup_web
```

**أندرويد:** نكهة <span dir="ltr">`foss`</span> هي نسخة الأوفلاين، وهي الافتراضية للتطوير:

```bash
flutter run --flavor foss
```

### ربط خادم

نفّذ واجهة <span dir="ltr">`CloudBackend`</span> في حزمة خاصة بك، ثم وجّه إليها <span dir="ltr">`pubspec_overrides.yaml`</span>:

```yaml
dependency_overrides:
  hisab_cloud:
    path: ../my_hisab_cloud
```

يستدعي التطبيق <span dir="ltr">`registerHisabCloud()`</span> عند الإقلاع: فإن سجّلت حزمتُكم خادمًا عملت المصادقة والمزامنة والدعوات والإشعارات، وإلا بقي التطبيق محليًا. ولا يتغير شيء آخر في <span dir="ltr">`lib/`</span>.

الدليل الكامل: <span dir="ltr">[docs/SELF_HOSTING.md](docs/SELF_HOSTING.md)</span> · مرجع الواجهة: <span dir="ltr">[packages/hisab_backend/README.md](packages/hisab_backend/README.md)</span> · سلوك الخادم: <span dir="ltr">[docs/BACKEND_BEHAVIOUR.md](docs/BACKEND_BEHAVIOUR.md)</span>

### حلول سريعة

| المشكلة | الحل |
|-------|-----|
| يبقى محليًا فقط | هذا المتوقع دون خادم — انظر «ربط خادم» |
| تعطل <span dir="ltr">SQLite</span> على الويب | <span dir="ltr">`flutter pub run powersync:setup_web`</span> |
| بناء أندرويد لا يجد النكهة | مرّر <span dir="ltr">`--flavor foss`</span> (أو <span dir="ltr">`cloud`</span> إن كان لديكم خادم) |
| أخطاء التوليد بعد التحديث | <span dir="ltr">`dart run build_runner build --delete-conflicting-outputs`</span> |

</div>

---

<div dir="rtl" lang="ar">

## البنية (باختصار)

- **الواجهة / الحالة** — <span dir="ltr">Flutter</span>، <span dir="ltr">Riverpod 3</span> (codegen)، <span dir="ltr">GoRouter</span>
- **قاعدة محلية** — <span dir="ltr">SQLite</span> عبر حزمة <span dir="ltr">PowerSync</span> (دائمًا)
- **السحابة** — اختيارية خلف واجهة <span dir="ltr">`CloudBackend`</span>، وغائبة افتراضيًا
- **المزامنة** — الكتابة أونلاين إلى الخادم ثم الكاش؛ القراءة دائمًا من <span dir="ltr">SQLite</span>؛ طابور يُفرَّغ عند عودة الاتصال
- **المجال** — مجموعات، مشاركون، مصاريف (بالسنت)، أرصدة، تصفيات، دعوات

خريطة أعمق: [docs/CODEBASE.md](docs/CODEBASE.md)

</div>

---

<div dir="rtl" lang="ar">

## الوثائق

| الدليل | |
|-------|--|
| [فهرس الوثائق](docs/README.md) | كل المواضيع |
| [الاستضافة الذاتية](docs/SELF_HOSTING.md) | تنفيذ الواجهة على خادمكم |
| [سلوك الخادم](docs/BACKEND_BEHAVIOUR.md) | القواعد التي يفترضها التطبيق في الخادم |
| [واجهة الخادم](packages/hisab_backend/README.md) | مرجع الواجهة وجهًا وجهًا |
| [الإعداد](docs/CONFIGURATION.md) | خيارات البناء، متصل مقابل محلي |
| [الأمان](SECURITY.md) | سياسة الأسرار للمستودع العام (ما لا يُرفع أبدًا) |
| [المساهمة](CONTRIBUTING.md) | طريقة العمل واتفاقية المساهم |
| [الاختبارات](test/README.md) | وحدة، ويدجت، تكامل |

</div>

---

<div dir="rtl" lang="ar">

## الاختبار

```bash
flutter test
bash scripts/run_release_checks.sh
```

يشغّل <span dir="ltr">CI</span> الفحوص ومجموعة الاختبارات، ثم **حارس البناء الأوفلاين** الذي يتحقق أن الشجرة ما زالت تُبنى دون أي خادم (<span dir="ltr">`.github/workflows/ci.yml`</span>). ووسم <span dir="ltr">`v*`</span> يبني ملفات <span dir="ltr">FOSS APK</span> الموقّعة وينشرها (<span dir="ltr">`.github/workflows/release.yml`</span>). ولا وجود لأي بيانات اعتماد إنتاجية في هذا المستودع ولا في أسرار <span dir="ltr">Actions</span> الخاصة به.

</div>

---

<div dir="rtl" lang="ar">

## المساهمة

المساهمات مرحّب بها، و**كلها تحتاج اتفاقية مساهم** — إذ لا يستطيع المشروع أن يقدّم تطبيقًا بـ <span dir="ltr">AGPL</span> إلى جانب خادم مغلق إلا ما دامت الملكية الفكرية في يد واحدة. الشرح في فقرة واحدة داخل [CONTRIBUTING.md](CONTRIBUTING.md).

وهذا المستودع **عام**: لا ترفعوا مفاتيح حقيقية، ولا ملفات حساب خدمة <span dir="ltr">JSON</span>، ولا ملفات <span dir="ltr">define/env</span> المعبأة. انظر [SECURITY.md](SECURITY.md).

</div>

---

<div dir="rtl" lang="ar">

## الرخصة

[AGPL-3.0](LICENSE) — لكم أن تستخدموا البرنامج وتدرسوه وتعدّلوه وتعيدوا توزيعه بحرية؛ ومن شغّل نسخة معدَّلة كخدمة على الشبكة وجب أن يتيح شفرتها لمستخدميها.

<span dir="ltr"><a href="https://github.com/Zyzto/Safaeh">Safaeh</a></span> (وسم git، ليست في هذا المستودع) مرخّصة بـ <span dir="ltr"><a href="https://github.com/Zyzto/Safaeh/blob/main/LICENSE">MPL-2.0</a></span>، نفس عائلة <span dir="ltr"><a href="https://github.com/Zyzto/Edadat">Edadat</a></span> و<span dir="ltr"><a href="https://github.com/Zyzto/Siglat">Siglat</a></span>. حساب كعمل أكبر يبقى AGPL.

أما الاسم **حساب** والعلامة <span dir="ltr">**Hisab**</span> والشعار فليست مشمولة بالرخصة. اشتقّوا ما شئتم، ونرجو أن تصدر نسختكم باسم وأيقونة مختلفين. والخادم المستضاف مشروع منفصل ومغلق وليس في هذا المستودع — والمواصفة المنشورة لبناء خادمكم في <span dir="ltr">[docs/SELF_HOSTING.md](docs/SELF_HOSTING.md)</span>.

</div>
