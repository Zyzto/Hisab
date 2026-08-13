# Arabic localization (Spacetoon / Venus)

<!-- markdownlint-disable MD060 -->

Hisab Arabic UI follows polished **Modern Standard Arabic (Fusha)** in the classic Spacetoon / Venus Centre register: clear, welcoming, slightly heroic—never dry dictionary calques, never heavy dialect.

Engineering wiring (keys, `.tr()`, parity tests) lives in [I18N.md](I18N.md). This doc owns **voice and terminology**.

## Principles

1. **Spacetoon / Venus tone** — Expressive, precise MSA. Inspiring and friendly; fit for beloved 90s/2000s Arabic dubbing, adapted for software UI.
2. **Anti-calque** — Do not mirror English word order, phrasal verbs, or awkward transliteration. Prefer natural Arabic (VSO or natural nominal sentences).
3. **UI brevity** — Buttons, tabs, and chips stay short. Eloquence without archaic words that confuse users.
4. **Encouraging errors** — Soften failures. Prefer «عذراً، لم تكتمل العملية. حاول مجدداً.» over harsh «فشل…» when length allows. Never use nonsensical phrases like «تعهدت العملية بالنجاح».
5. **Placeholders** — Keep the same tokens as English (`{name}`, `{count}`, `{}`, …). Never translate or reorder placeholder names.

## Glossary (canonical)

| Concept | Canonical AR | Notes |
|---------|----------------|--------|
| App / software | تطبيق | |
| Settings | الإعدادات | |
| Profile | الملف الشخصي | |
| Theme (`theme`) | السمة | Distinct from Appearance `المظهر` |
| Appearance (`appearance`) | المظهر | |
| Tag / category | فئة | Not وسم |
| Share / part (split) | حصة / حصص | Not جزء for split UI |
| Loading | جاري التحميل… | Match existing ellipsis style in nearby keys |
| Expenses | مصاريف | Never `مصروفات` |
| Settle up | تصفية الحساب / تصفية | |
| All settled | اتصفّت الحسابات | Or polished twin with same meaning |
| Balance **tab / settle screen** (`balance`) | الحسابات | Group balances between people — **not** الرصيد |
| Balance **money amount** | الرصيد / رصيدك / أرصدتك | `your_balance`, `profile_*` |
| Receipt (scan / photo) | إيصال / إيصالات | Not فاتورة for this product sense |
| Bill breakdown (line items) | تفصيل الإيصال | |
| Analytics | الإحصاءات | Not التحليلات |
| Push notifications | إشعارات فورية | Not إشعارات الدفع |
| Paid by | دفعها {name} | Not `دفع {name}` |
| Group | مجموعة | |
| Invite | دعوة | |
| Split | تقسيم | |
| Split equally (`equal`) | بالتساوي | Not متساوي alone |
| Split by shares (`parts`) | حصص | Not أجزاء |
| Exact amounts (`amounts`) | مبالغ محددة | Not bare مبالغ |
| How to settle (`settlement_method`) | طريقة التصفية | Group settings section: كيف نُصفّي |
| Partners only | بينكم | Pairwise settlement |
| Minimal moves | أقل عمليات | Greedy settlement |
| Full breakdown | لكل مصروف | Consolidated settlement |
| One wallet | أمين المجموعة | Treasurer settlement |
| Budget | ميزانية | |
| Sync | مزامنة | |
| Offline | أوفلاين | Or بلا اتصال when fuller phrasing fits |

Brand / provider names stay Latin and match English (`Google`, `Gemini`, `Supabase`, …).

## Do / don’t (real keys)

| Key | Avoid | Prefer |
|-----|--------|--------|
| `create_group_desc` | قسّموا المصاريف مع أصحابكم أو أهلكم | قسّموا المصاريف مع الأصدقاء أو العائلة |
| `onboarding_settle_up_desc` | يشوف لك من يدفع لمن عشان… | يعرض من يدفع لمن حتى تتصافى الحسابات… |
| `notifications_enabled` | إشعارات الدفع | إشعارات فورية |
| `analytics` | التحليلات | الإحصاءات |
| `paid_by` | دفع {name} | دفعها {name} |
| `scan_receipt` / `receipt` | مسح الفاتورة / الفاتورة | مسح الإيصال / الإيصال |
| `generic_error` | حدث خطأ (bare) | عذراً، حدث خطأ ما |

Dialect markers to reject in UI copy: `عشان`, `يشوف`, `تشوف`, `ليش`, `أصحابكم`, `لما تصير`, and similar.

## Privacy exception

Keys `privacy_policy_*` use **legal-formal MSA** only—no Spacetoon flair, no marketing drama.

When product labels change in UI (e.g. إشعارات فورية, إيصالات), update the same terms inside privacy bodies so Settings paths stay accurate. Do **not** change legal meaning. Keep [PLAY_CONSOLE_DECLARATIONS.md](PLAY_CONSOLE_DECLARATIONS.md) sync in mind (`en` / `ar` / `web/privacy`).

## Push notifications (Edge)

Arabic strings in `supabase/functions/send-notification` (`NOTIFICATION_STRINGS.ar`) must stay aligned with app keys:

- `notification_expense_updated`
- `notification_expense_deleted`
- `notification_member_joined`

Keep push prefixes short.

## Checklist (new or edited Arabic)

- [ ] Same keys as `en.json`; placeholders identical
- [ ] Glossary terms respected (`balance` tab vs money; إيصال; مصاريف; إشعارات فورية)
- [ ] No dialect / no English calques
- [ ] Errors encouraging where space allows
- [ ] Privacy keys legal-formal; product terms synced
- [ ] Edge AR updated if notification copy changed
