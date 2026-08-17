const admin = require('firebase-admin');

let app = null;

function getFirebaseApp() {
  if (app) return app;

  const projectId = process.env.FIREBASE_PROJECT_ID || process.env.FCM_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL || process.env.FCM_CLIENT_EMAIL;
  // Env vars store literal "\n" — real newlines are restored here.
  const privateKey = (process.env.FIREBASE_PRIVATE_KEY || process.env.FCM_PRIVATE_KEY || '').replace(/\\n/g, '\n');

  if (!projectId || !clientEmail || !privateKey) {
    throw new Error('FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL and FIREBASE_PRIVATE_KEY must be set');
  }

  app = admin.initializeApp({
    credential: admin.credential.cert({ projectId, clientEmail, privateKey }),
  });
  return app;
}

function fcmReady() {
  try {
    getFirebaseApp();
    return true;
  } catch (_) {
    return false;
  }
}

function messaging() {
  return admin.messaging(getFirebaseApp());
}

module.exports = { messaging, fcmReady };
