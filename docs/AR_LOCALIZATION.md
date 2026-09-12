# Arabic localization

Hisab uses clear Modern Standard Arabic with a friendly, concise tone.

## Canonical terms

| English | Arabic |
|---|---|
| Settings | الإعدادات |
| Appearance | المظهر |
| Expenses | مصاريف |
| Group | مجموعة |
| Participants | المشاركون |
| Balance | الحسابات |
| Settle up | تصفية الحساب |
| Receipt | إيصال |
| Category | فئة |
| Offline | بلا اتصال |

Keep buttons short, preserve placeholders such as {name} and {count}, and
avoid transliterating ordinary product concepts.

## Checklist

- assets/translations/en.json and assets/translations/ar.json have equal key
  sets.
- Placeholders match exactly.
- User-entered names and descriptions are never translated.
- RTL layouts are tested with both short and long Arabic strings.
- Run flutter test test/translations_test.dart after changing keys.
