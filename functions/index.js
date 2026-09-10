/**
 * Optional Cloud Function: send FCM when a call document is created.
 *
 * Deploy (bonus / background ringing):
 *   npm install -g firebase-tools
 *   firebase init functions
 *   firebase deploy --only functions
 */
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

exports.onCallCreated = functions.firestore
  .document('calls/{callId}')
  .onCreate(async (snap) => {
    const call = snap.data();
    if (!call || call.status !== 'ringing') return;

    const callee = await admin.firestore().collection('users').doc(call.calleeId).get();
    const token = callee.get('fcmToken');
    if (!token) return;

    await admin.messaging().send({
      token,
      notification: {
        title: `Incoming ${call.type === 'video' ? 'video' : 'audio'} call`,
        body: `${call.callerName} is calling you`,
      },
      data: {
        callId: call.id || snap.id,
        type: String(call.type || 'audio'),
      },
      android: {
        priority: 'high',
      },
    });
  });
