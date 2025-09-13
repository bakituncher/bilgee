const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const auth = admin.auth();
const storage = admin.storage();
const messaging = admin.messaging();

module.exports = {
  admin,
  db,
  auth,
  storage,
  messaging,
};
