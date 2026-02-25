# Google Play Console — Policy declarations reference

Use this when filling the **App content** and related declaration forms for Hisab. Answers are accurate for the current app behavior.

---

## 1. Privacy policy

- **What to do:** Add a **privacy policy URL** (required for apps that use sensitive permissions such as Camera).
- **URL:** Use a **public** URL where your policy is hosted:
  - **Firebase Hosting (custom domain):** `https://hisab.shenepoy.com/privacy` — the static page is built from `web/privacy/index.html` and deployed with the web app via Firebase Hosting (see release workflow; local deploy: after `flutter build web`, run `cp -r web/privacy build/web/` and `cp -r web/delete-account build/web/` then `firebase deploy --only hosting`).
  - **Firebase Hosting (default URL):** `https://hisab-c8eb1.web.app/privacy` if not using the custom domain
  - GitHub Pages: `https://<your-org-or-username>.github.io/Hisab/privacy` (if you add a `privacy` page there)
- **Content:** The policy text in `web/privacy/index.html` matches the in-app policy (Settings → Privacy Policy) and `assets/translations/en.json` keys `privacy_policy_*`, including the **App Permissions** section (Camera, Photos, Notifications). When updating the policy, change both the app strings and `web/privacy/index.html`.
- **Account and data deletion:** Options (delete local data, delete cloud data, request full account deletion) are described in `docs/DELETE_ACCOUNT.md`. The privacy policy’s Your Rights section matches the in-app options and points users to the account deletion page or GitHub/About for full account deletion. If the Play Console form asks for an account deletion URL, use `https://hisab.shenepoy.com/delete-account` (the static page at `web/delete-account/index.html` is deployed with the web app; same release workflow copies it to `build/web/`).

---

## 2. Ads

- **Does your app contain ads?** **No**
- Hisab does not show any ads or use ad SDKs.

---

## 3. App access

- **Are parts of your app restricted?** **Yes** (online features require sign-in).
- **Instructions to access all functionality:**  
  Example text you can use:
  > **Offline mode:** Open the app and use it without an account. All data stays on the device.  
  > **Online mode (sync, groups, invites, push notifications):** Sign in with email, Google, or GitHub (Settings or onboarding). Create or join groups to access shared expenses and settlements. No paid membership required.

Adjust if your flow differs (e.g. invite-only).

---

## 4. Content ratings

- **What to do:** Complete the **questionnaire** (IARC / rating authority).
- For Hisab (expense splitting, no adult content, no violence): typically **Everyone** or **PEGI 3** / **ESRB Everyone**. Answer honestly; the tool will suggest a rating. Submit and get the certificate.

---

## 5. Target audience and content

- **Target age group:** **18+** (or **13+** if you prefer; expense/finance apps are often 18+).
- **Is the app primarily for children?** **No**
- **Sensitive content:** No gambling, violence, etc. Select “No” for content that doesn’t apply.

---

## 6. Data safety

Declare what the app **collects** and **shares**. Below matches current behavior.

| Data type | Collected? | Purpose | Shared with third parties? | Optional? |
|-----------|------------|---------|----------------------------|-----------|
| **Email address** | Yes (online) | Account authentication | No (only with auth provider for sign-in) | No (required for online) |
| **Name** (display name) | Yes (optional) | Profile in groups | Only with group members | Yes |
| **User-generated content** (expense descriptions, group names, etc.) | Yes | App functionality, sync | Only with members of the same group | No (core feature) |
| **App activity** (e.g. events) | Yes, if user enables | Anonymous telemetry (Settings → Privacy) | No | Yes (toggle off) |
| **Device or other IDs** (FCM token) | Yes (online, if notifications on) | Push notifications | With Firebase / FCM only for delivery | Yes (user can disable notifications) |

- **Camera / Photos:** Used only for receipt scanning and picking images; no ongoing collection of photo library. On Android, the app uses the **Android Photo Picker** for gallery access (no `READ_MEDIA_IMAGES`); receipt images are selected on demand when the user taps "Scan receipt" → Gallery. Declare as needed by the form (e.g. “Photos” or “User content” if the form asks).
- **Data is not sold or shared for ads.** Data is **not** used for advertising purposes.
- **Data encryption:** Data in transit is encrypted (HTTPS). Data at rest on servers is not end-to-end encrypted (state this if the form asks).

Fill the Data safety form step-by-step; the above table maps to the questions you’ll get.

**Photo and video permissions (if the form asks):** The app uses the **Android Photo Picker** for infrequent receipt attachment. When the user taps to attach a receipt and chooses "Gallery", the system photo picker is shown; no `READ_MEDIA_IMAGES` permission is used. You can state: "We use the Android Photo Picker for one-time selection of a receipt image when the user taps to attach a receipt to an expense. We do not use READ_MEDIA_IMAGES."

---

## 7. Advertising ID

- **Does your app use an advertising ID?** **No**
- Hisab does not use Google Advertising ID or similar for ads or analytics.

---

## 8. Government apps

- **Is your app for use by a government (national, state, city, local authority)?** **No**

---

## 9. Financial features

- **Does your app offer financial features?** Depends how the form phrases it:
  - **Expense tracking / splitting / balances:** Yes — the app helps users track and split expenses and view who owes whom.
  - **Payment processing / lending / banking / investments:** No — Hisab does not process payments, extend credit, or offer financial products.
- Answer the follow-up questions accordingly: e.g. “We do not process payments or handle money; we only help users track and split expenses.”

---

## 10. Health apps

- **Does your app contain health-related features?** **No**
- Select that the app does not collect health data or fall under health app requirements.

---

## Checklist

- [ ] Privacy policy: URL set and publicly reachable (e.g. https://hisab.shenepoy.com/privacy); text matches in-app policy (including permissions). Account deletion URL set if required (e.g. https://hisab.shenepoy.com/delete-account).
- [ ] Ads: Declared as “No”.
- [ ] App access: Instructions provided for restricted (online) parts.
- [ ] Content ratings: Questionnaire completed; certificate received.
- [ ] Target audience: Age group and “not for children” set; sensitive content answered.
- [ ] Data safety: All collected/shared data and purposes declared; “no ads / no sell” reflected.
- [ ] Advertising ID: Declared as “No”.
- [ ] Government apps: Declared as “No”.
- [ ] Financial features: Declared per actual behavior (expense tracking only, no payment processing).
- [ ] Health apps: Declared as “No” / no health features.

After completing these, the “10 declarations need attention” list in Play Console should clear. If a form option doesn’t match this doc (e.g. new question), choose the option that best describes Hisab’s current behavior.
