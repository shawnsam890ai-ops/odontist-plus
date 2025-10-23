"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.auth_verifyEmailOtp = exports.auth_requestEmailOtp = exports.expireLicenses = exports.verifyIntegrity = exports.razorpayWebhook = exports.createOrder = exports.checkAccess = exports.onAuthCreate = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const razorpay_1 = __importDefault(require("razorpay"));
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const node_fetch_1 = __importDefault(require("node-fetch"));
const crypto = __importStar(require("node:crypto"));
admin.initializeApp();
const db = admin.firestore();
// ----- Config -----
// Set via: firebase functions:config:set razorpay.key_id=xxx razorpay.key_secret=yyy webhooks.secret=zzz play.package=com.example.app
//           google.project_number=12345 play.integrity_audience=playintegrity.googleapis.com
const cfg = functions.config();
const rp = new razorpay_1.default({
    key_id: cfg?.razorpay?.key_id || '',
    key_secret: cfg?.razorpay?.key_secret || '',
});
// ----- Helpers -----
async function ensureUserDoc(uid, profile) {
    const ref = db.collection('users').doc(uid);
    const snap = await ref.get();
    if (!snap.exists) {
        await ref.set({
            profile: profile || {},
            license_status: 'trial',
            trial_start: admin.firestore.FieldValue.serverTimestamp(),
            integrity_passed_at: null,
            created_at: admin.firestore.FieldValue.serverTimestamp(),
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    }
}
function monthsToMs(m) {
    return 1000 * 60 * 60 * 24 * 30 * m; // approx months
}
function addDaysMs(days) { return 1000 * 60 * 60 * 24 * days; }
// ----- Auth trigger: provision user doc with trial -----
exports.onAuthCreate = functions.auth.user().onCreate(async (user) => {
    await ensureUserDoc(user.uid, {
        email: user.email || null,
        displayName: user.displayName || null,
    });
});
// ----- HTTPS callable: check access (token validated by callable) -----
exports.checkAccess = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Sign-in required');
    }
    const uid = context.auth.uid;
    const uref = db.collection('users').doc(uid);
    const u = await uref.get();
    if (!u.exists)
        throw new functions.https.HttpsError('not-found', 'User missing');
    const d = u.data();
    // Trial valid for 3 days from trial_start
    const trialStart = d.trial_start?.toMillis ? d.trial_start.toMillis() : (d.trial_start?._seconds ? d.trial_start._seconds * 1000 : 0);
    const now = Date.now();
    const trialValid = trialStart && (now - trialStart) <= addDaysMs(3);
    // Subscription active if license_status=active and expiry_date>now
    const expiry = d.expiry_date?.toMillis ? d.expiry_date.toMillis() : (d.expiry_date?._seconds ? d.expiry_date._seconds * 1000 : 0);
    const active = d.license_status === 'active' && expiry && expiry > now;
    // Integrity should be within last 7 days
    const integAt = d.integrity_passed_at?.toMillis ? d.integrity_passed_at.toMillis() : (d.integrity_passed_at?._seconds ? d.integrity_passed_at._seconds * 1000 : 0);
    const integrityRecent = integAt && (now - integAt) <= addDaysMs(7);
    return { allowed: !!(active || trialValid), license_status: d.license_status, trialValid, active, integrityRecent };
});
// ----- HTTPS endpoint: create Razorpay order -----
// body: { plan: 'monthly' | 'halfyear' | 'yearly' }
exports.createOrder = functions.https.onCall(async (data, context) => {
    if (!context.auth)
        throw new functions.https.HttpsError('unauthenticated', 'Sign-in required');
    const plan = (data?.plan || 'monthly');
    const amountMap = {
        monthly: 1499,
        halfyear: 6900,
        yearly: 12000,
    };
    const amount = amountMap[plan];
    if (!amount)
        throw new functions.https.HttpsError('invalid-argument', 'Invalid plan');
    const order = await rp.orders.create({ amount: amount * 100, currency: 'INR', receipt: `${context.auth.uid}-${Date.now()}`, notes: { plan } });
    return { orderId: order.id, amount: order.amount, currency: order.currency };
});
// ----- Razorpay webhook: verify signature and activate license -----
const app = (0, express_1.default)();
app.use((0, cors_1.default)({ origin: true }));
app.use(express_1.default.json({ type: '*/*' }));
app.post('/razorpay/webhook', async (req, res) => {
    try {
        const signature = req.headers['x-razorpay-signature'];
        const secret = cfg?.webhooks?.secret || '';
        const crypto = await Promise.resolve().then(() => __importStar(require('node:crypto')));
        const expected = crypto.createHmac('sha256', secret).update(JSON.stringify(req.body)).digest('hex');
        if (signature !== expected)
            return res.status(401).json({ ok: false, error: 'invalid signature' });
        const event = req.body;
        if (event.event !== 'payment.captured' && event.event !== 'order.paid')
            return res.json({ ok: true });
        const plan = event.payload?.payment?.entity?.notes?.plan || event.payload?.order?.entity?.notes?.plan || 'monthly';
        const receipt = event.payload?.payment?.entity?.receipt || event.payload?.order?.entity?.receipt || '';
        const uid = receipt?.split('-')[0];
        if (!uid)
            return res.status(400).json({ ok: false, error: 'uid missing' });
        const months = plan === 'yearly' ? 12 : (plan === 'halfyear' ? 6 : 1);
        const now = Date.now();
        await db.runTransaction(async (tx) => {
            const ref = db.collection('users').doc(uid);
            const snap = await tx.get(ref);
            const prev = snap.exists ? snap.data() : {};
            const currentExpiry = prev.expiry_date?._seconds ? prev.expiry_date._seconds * 1000 : 0;
            const startFrom = Math.max(now, currentExpiry || 0);
            const newExpiry = new Date(startFrom + monthsToMs(months));
            tx.set(ref, {
                license_status: 'active',
                expiry_date: admin.firestore.Timestamp.fromDate(newExpiry),
                updated_at: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        });
        res.json({ ok: true });
    }
    catch (e) {
        console.error(e);
        res.status(500).json({ ok: false, error: e.message });
    }
});
exports.razorpayWebhook = functions.https.onRequest(app);
// ----- Verify Play Integrity token (client sends token) -----
// Requires service account with Play Integrity permissions; provide access token via default credentials.
exports.verifyIntegrity = functions.https.onCall(async (data, context) => {
    if (!context.auth)
        throw new functions.https.HttpsError('unauthenticated', 'Sign-in required');
    const token = data?.integrityToken;
    const packageName = cfg?.play?.package || '';
    if (!token || !packageName)
        throw new functions.https.HttpsError('invalid-argument', 'Missing token/package');
    try {
        // Exchange for access token via default credentials
        const auth = await admin.credential.applicationDefault().getAccessToken();
        const resp = await (0, node_fetch_1.default)(`https://playintegrity.googleapis.com/v1/packageNames/${packageName}:decodeIntegrityToken`, {
            method: 'POST',
            headers: { 'Authorization': `Bearer ${auth.access_token}`, 'Content-Type': 'application/json' },
            body: JSON.stringify({ integrityToken: token }),
        });
        if (!resp.ok)
            throw new Error(`Integrity API ${resp.status}`);
        const body = await resp.json();
        // Basic checks (deviceIntegrity, appIntegrity, accountIntegrity)
        const verdicts = body?.deviceIntegrity?.deviceRecognitionVerdict || [];
        const appLic = body?.appLicensingVerdict || 'UNKNOWN';
        const passed = verdicts.includes('MEETS_DEVICE_INTEGRITY') || verdicts.includes('MEETS_BASIC_INTEGRITY');
        if (!passed)
            throw new Error('integrity failed');
        await db.collection('users').doc(context.auth.uid).set({ integrity_passed_at: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
        return { ok: true, appLicensingVerdict: appLic, verdicts };
    }
    catch (e) {
        console.error(e);
        throw new functions.https.HttpsError('permission-denied', e.message);
    }
});
// ----- Scheduled cleanup: expire licenses past due -----
exports.expireLicenses = functions.pubsub.schedule('every 24 hours').onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const q = await db.collection('users').where('license_status', '==', 'active').where('expiry_date', '<', now).get();
    const batch = db.batch();
    q.docs.forEach((d) => batch.set(d.ref, { license_status: 'expired', updated_at: admin.firestore.FieldValue.serverTimestamp() }, { merge: true }));
    await batch.commit();
    return `Expired ${q.size}`;
});
// =============================
// Passwordless Email OTP (custom)
// =============================
function hashOtp(code, email) {
    const secret = cfg?.otp?.secret || 'dev-secret';
    return crypto.createHash('sha256').update(`${code}:${email}:${secret}`).digest('hex');
}
async function sendEmail(to, subject, text) {
    // Try Resend
    const resend = cfg?.resend?.api_key;
    if (resend) {
        try {
            const r = await (0, node_fetch_1.default)('https://api.resend.com/emails', {
                method: 'POST',
                headers: { 'Authorization': `Bearer ${resend}`, 'Content-Type': 'application/json' },
                body: JSON.stringify({ from: cfg?.resend?.from || 'no-reply@yourapp.example', to, subject, text }),
            });
            if (!r.ok)
                console.error('Resend send failed', await r.text());
            return;
        }
        catch (e) {
            console.error('Resend error', e);
        }
    }
    // Try SendGrid
    const sg = cfg?.sendgrid?.api_key;
    if (sg) {
        try {
            const r = await (0, node_fetch_1.default)('https://api.sendgrid.com/v3/mail/send', {
                method: 'POST',
                headers: { 'Authorization': `Bearer ${sg}`, 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    personalizations: [{ to: [{ email: to }] }],
                    from: { email: cfg?.sendgrid?.from || 'no-reply@yourapp.example' },
                    subject,
                    content: [{ type: 'text/plain', value: text }],
                }),
            });
            if (!r.ok)
                console.error('SendGrid send failed', await r.text());
            return;
        }
        catch (e) {
            console.error('SendGrid error', e);
        }
    }
    console.log(`DEV EMAIL to=${to} subject=${subject} text=${text}`);
}
// Request a code to be emailed to the user.
exports.auth_requestEmailOtp = functions.https.onCall(async (data, context) => {
    const email = (data?.email || '').toString().trim().toLowerCase();
    if (!email || !/^[^@]+@[^@]+\.[^@]+$/.test(email)) {
        throw new functions.https.HttpsError('invalid-argument', 'Valid email required');
    }
    // Ensure a Firebase Auth user exists for this email
    let user = null;
    try {
        user = await admin.auth().getUserByEmail(email);
    }
    catch { /* not found */ }
    if (!user) {
        user = await admin.auth().createUser({ email, emailVerified: false, disabled: false });
    }
    await ensureUserDoc(user.uid, { email });
    const now = Date.now();
    const otpRef = db.collection('users').doc(user.uid).collection('auth_otp').doc('email');
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const codeHash = hashOtp(otp, email);
    const expiresAt = new Date(now + 10 * 60 * 1000); // 10 minutes
    // Optional simple rate limit: resend after 30s
    const existing = await otpRef.get();
    const nextAllowed = existing.exists && existing.data()?.next_allowed ? existing.data().next_allowed.toMillis?.() || (existing.data().next_allowed._seconds * 1000) : 0;
    if (nextAllowed && now < nextAllowed) {
        throw new functions.https.HttpsError('resource-exhausted', 'Please wait before requesting another code');
    }
    await otpRef.set({
        code_hash: codeHash,
        expires_at: admin.firestore.Timestamp.fromDate(expiresAt),
        attempts: 0,
        next_allowed: admin.firestore.Timestamp.fromMillis(now + 30 * 1000),
        created_at: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    await sendEmail(email, 'Your Odontist Plus sign-in code', `Your code is ${otp}. It expires in 10 minutes.`);
    return { ok: true };
});
// Verify the code and issue a custom token
exports.auth_verifyEmailOtp = functions.https.onCall(async (data, context) => {
    const email = (data?.email || '').toString().trim().toLowerCase();
    const code = (data?.code || '').toString().trim();
    if (!email || !code)
        throw new functions.https.HttpsError('invalid-argument', 'Email and code required');
    let user = null;
    try {
        user = await admin.auth().getUserByEmail(email);
    }
    catch { }
    if (!user)
        throw new functions.https.HttpsError('not-found', 'User not found');
    const otpRef = db.collection('users').doc(user.uid).collection('auth_otp').doc('email');
    const snap = await otpRef.get();
    if (!snap.exists)
        throw new functions.https.HttpsError('failed-precondition', 'No code requested');
    const d = snap.data();
    const expMs = d.expires_at?.toMillis ? d.expires_at.toMillis() : (d.expires_at?._seconds ? d.expires_at._seconds * 1000 : 0);
    if (!expMs || Date.now() > expMs) {
        throw new functions.https.HttpsError('deadline-exceeded', 'Code expired');
    }
    if ((d.attempts || 0) >= 5)
        throw new functions.https.HttpsError('resource-exhausted', 'Too many attempts');
    const ok = d.code_hash === hashOtp(code, email);
    await otpRef.set({ attempts: (d.attempts || 0) + 1 }, { merge: true });
    if (!ok)
        throw new functions.https.HttpsError('permission-denied', 'Invalid code');
    // success: clear OTP and return custom token
    await otpRef.delete();
    const token = await admin.auth().createCustomToken(user.uid);
    await ensureUserDoc(user.uid, { email });
    return { customToken: token };
});
