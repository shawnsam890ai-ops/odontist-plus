Firebase Cloud Functions setup for Odontist Plus

This folder contains TypeScript Cloud Functions used by the Odontist Plus app:
- auth triggers (user provisioning & trial)
- callable endpoints: checkAccess, createOrder, verifyIntegrity, auth_requestEmailOtp, auth_verifyEmailOtp
- Razorpay webhook endpoint: `/razorpay/webhook`
- scheduled task: expireLicenses

Prerequisites
- Firebase CLI installed (>=14)
- Node.js 18+ and npm
- A Firebase project (console) and billing plan: Blaze is required to deploy functions that use Cloud Build/Artifact Registry.

Local development (emulators)
1. Install deps
   cd functions
   npm install

2. Build once (or watch while developing)
   npm run build

3. Start emulators (Auth, Functions, Firestore)
   npm run serve

This will build the functions and run the Firebase emulators locally. By default the callable functions will be available at the emulator's functions host.

Production deployment checklist
1. Enable Blaze plan for your project
   - Visit: https://console.firebase.google.com/project/<PROJECT_ID>/usage/details and upgrade to Blaze.

2. Set required runtime config variables
   Replace placeholders with real secrets (Razorpay account, webhook secret, email provider keys, Play package):

```bash
# Example (PowerShell)
firebase functions:config:set \
  razorpay.key_id="YOUR_KEY_ID" \
  razorpay.key_secret="YOUR_KEY_SECRET" \
  webhooks.secret="YOUR_WEBHOOK_SECRET" \
  play.package="com.your.app" \
  resend.api_key="<resend-key-if-used>" \
  resend.from="no-reply@yourdomain.example" \
  sendgrid.api_key="<sendgrid-key-if-used>" \
  sendgrid.from="no-reply@yourdomain.example" \
  otp.secret="<otp-secret>"
```

3. Deploy Firestore rules (already done in repo):

```bash
firebase deploy --only "firestore:rules"
```

4. Build and deploy functions

```bash
cd functions
npm run build
firebase deploy --only "functions"
```

5. Add Razorpay webhook
- In Razorpay dashboard configure a webhook to point at:
  https://REGION-PROJECT.cloudfunctions.net/razorpayWebhook/razorpay/webhook
  (Replace REGION/PROJECT with your Cloud Functions URL shown after deploy.)
- Use the `webhooks.secret` value set in functions config.

Notes
- The functions expect to run with the service account credentials of your Firebase project. For server-to-server Play Integrity calls you must grant the service account the required Play Integrity API permissions.
- If you want to test payments end-to-end without deploying to production, use the emulator for functions and keep Razorpay in test mode. The webhook will still need to be exercised manually (or with a forwarded tunnel) to the emulator.

Troubleshooting
- If `firebase deploy` fails due to missing APIs (cloudbuild/artifactregistry), upgrade the project to Blaze and re-run the deploy.
- If you need to rotate webhook secret, update the functions config and redeploy (or redeploy only functions).

Contact
- If you want I can also add a small `scripts/deploy-functions.ps1` PowerShell helper that runs the build + deploy steps with confirmation prompts.