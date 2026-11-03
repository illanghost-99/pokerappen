// Example Cloud Function (Node.js) to send push when session starts
// Deploy to Firebase Functions

const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.notifySessionStart = functions.firestore
  .document('sessions/{sessionId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    
    if (before.status !== 'active' && after.status === 'active') {
      const tokens = []; // Fetch FCM tokens of all players from users collection
      const message = {
        notification: {
          title: 'Poker Night startar nu!',
          body: `${after.name} har börjat`
        },
        tokens: tokens
      };
      await admin.messaging().sendEachForMulticast(message);
    }
  });
