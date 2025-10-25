# Backend: Auth, Trials, Subscriptions, Integrity

This project includes Firebase Cloud Functions and Firestore rules to support:

- Email/password signup with 3‑day free trial
- Razorpay subscriptions: monthly ₹1499, 6‑months ₹6900, yearly ₹12000
- Secure activation via Razorpay webhook (server‑side signature verification)
- Play Integrity verification to mitigate modded APKs
- Access checks on the server for every sensitive call

## Components

1. Cloud Functions (Node 18, TypeScript) in `functions/`:
  - `onAuthCreate`: creates `users/{uid}` doc with `trial_start` and `license_status=trial`.
  - `checkAccess` (callable): validates Firebase auth, checks trial/active subscription and that integrity was passed recently.
  - `createOrder` (callable): creates a Razorpay order for the selected plan.
  - `razorpayWebhook` (HTTP): verifies Razorpay signature and activates license (`license_status=active`, sets `expiry_date`).
  - `verifyIntegrity` (callable): verifies a Play Integrity token with Google and updates `integrity_passed_at` on success.
  - `expireLicenses` (scheduled): marks expired active licenses as `expired` daily.

2. Firestore Rules in `firestore.rules`:
  - Users can read their own document.
  - Users can update only `profile`, `integrity_passed_at` and `updated_at` from the client.
  - Clients cannot set/modify `license_status` or `expiry_date` — only Cloud Functions do.

## Configure

1. Install tools and deps (Node 18+):
  - `npm --prefix functions install`

2. Set Function Config:
  - `firebase functions:config:set razorpay.key_id=YOUR_KEY_ID razorpay.key_secret=YOUR_KEY_SECRET`
  - `firebase functions:config:set webhooks.secret=YOUR_RAZORPAY_WEBHOOK_SECRET`
  - `firebase functions:config:set play.package=com.your.app`

  ### Firebase Integration Quick Checklist

  Follow these steps to finish integrating the Firebase backend (Cloud Functions + Firestore rules):

  1. Verify you are logged into the correct Firebase account:

  ```powershell
  firebase login:list
  firebase projects:list
  ```

  2. Bind this repo to the Firebase project (if not already):

  ```powershell
  firebase use --add
  # choose projectId and alias (use 'default' for the main project)
  ```

  3. Set required functions config variables (replace placeholders):

  ```powershell
  firebase functions:config:set \
    razorpay.key_id="YOUR_KEY_ID" \
    razorpay.key_secret="YOUR_KEY_SECRET" \
    webhooks.secret="YOUR_WEBHOOK_SECRET" \
    play.package="com.your.app" \
    otp.secret="<otp-secret>" \
    resend.api_key="<resend-key-if-used>" \
    resend.from="no-reply@yourdomain.example" \
    sendgrid.api_key="<sendgrid-key-if-used>" \
    sendgrid.from="no-reply@yourdomain.example"
  ```

  4. If you plan to deploy Cloud Functions, upgrade the project to Blaze (required to enable Cloud Build & Artifact Registry). Visit:

  ```
  https://console.firebase.google.com/project/<PROJECT_ID>/usage/details
  ```

  5. Deploy only rules (safe without Blaze):

  ```powershell
  firebase deploy --only "firestore:rules"
  ```

  6. Build and deploy functions (requires Blaze):

  ```powershell
  cd functions
  npm install
  npm run build
  firebase deploy --only "functions"
  ```

  7. After deploying, configure a Razorpay webhook in your Razorpay dashboard with the functions URL:

  ```
  https://<REGION>-<PROJECT>.cloudfunctions.net/razorpayWebhook/razorpay/webhook
  ```

  8. Optional: run emulators locally for development:

  ```powershell
  cd functions
  npm run serve
  ```

3. Deploy:
  - `npm --prefix functions run build`
  - `firebase deploy --only functions,firestore:rules`

## Flutter Integration (high‑level)

1. Signup UI:
  - Collect first name, last name, preferred username, email, password (+confirm, show/hide).
  - Call `FirebaseAuth.instance.createUserWithEmailAndPassword`.
  - After sign‑up, write `users/{uid}.profile` with names and username.

2. Trial & Access Gate:
  - On app start and before sensitive operations, call the callable `checkAccess`.
  - If `allowed=false`, open the paywall.

3. Payments:
  - Call `createOrder` callable to get a Razorpay order (amount/currency).
  - Use Razorpay Checkout (client SDK) to complete payment.
  - Server receives webhook and activates the license.

4. Integrity:
  - Use Play Integrity API on Android (e.g., via native plugin) to fetch an integrity token.
  - Send it to `verifyIntegrity` callable. Do this after login and weekly.

## Notes on Anti‑Tamper

- Play Integrity checks + server‑side gating significantly reduce modded APK risk, but cannot guarantee absolute prevention.
- Keep all premium features gated by `checkAccess` on the server.
- Consider Remote Config feature flags, dynamic signing key pinning, and periodic integrity checks.

# Dental Clinic App (Prototype)

This Flutter application is a prototype for a dental clinic management system featuring:

- Splash (Loading) Page
- Login Page
- Dashboard with statistics (Patients, Revenue)
- Patient List & Add Patient pages
- Patient Detail with dynamic form sections for treatment session creation:
  - General
  - Orthodontic
  - Root Canal
  - Lab Work (placeholder mention)
- Repositories with local persistence using `shared_preferences`
- Reindexing of patient display numbers after deletion

## Architecture Overview

```
lib/
  core/            # enums, constants, routing
  models/          # data models (Patient, TreatmentSession, LabWork, RevenueEntry)
  repositories/    # persistence & business logic (local storage)
  providers/       # ChangeNotifiers bridging UI and repositories
  ui/pages/        # Screens
  ui/widgets/      # Reusable widgets
```

### Patient ID Strategy
- `id`: internal UUID (never shown/editable)
- `displayNumber`: sequential number (1..N) recalculated on delete
- `customNumber`: manually editable backend field (not yet surfaced in UI editing form)

### Treatment Sessions
Currently minimal fields are implemented for the dynamic forms; prescription, follow-up chaining, media attachments, consent uploads, and payment tracking are prepared structurally but not fully implemented in UI yet.

## Missing / Next Planned Enhancements
1. Advanced validation & error states
2. WhatsApp integration (launch URL) for patient phone
3. Editable custom patient ID field in an admin/back-office panel
4. Deletion & editing of sessions
5. Orthodontic payment schedule & balance calculation UI
6. Root canal and orthodontic procedure step logging with per-step payments auto-posting to revenue
7. Lab work creation & linking from patient detail (currently only model & repo exist)
8. Media (x-ray images) picker & storage (need file picker implementation & permission handling)
9. Consent form PDF/image upload & persistent linking
10. Prescription builder (serial auto-increment + medicine dropdown + timing pattern input)
11. Follow-up session creation (template copy minus chief complaint / oral findings per requirements)
12. Export / backup (JSON export) functionality
13. Authentication (currently mock login form only)
14. Theming polish and responsive layout improvements

## Running
Install Flutter SDK, then:
```
flutter pub get
flutter run
```

## Disclaimer
This is a prototype scaffold focusing on structure. Many requested detailed behaviors (conditional forms, payment balance logic, follow-ups, dynamic backend option management) still need implementation.
