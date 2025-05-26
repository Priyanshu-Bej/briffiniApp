/**
 * Example FCM payload for testing notifications in the student app.
 * 
 * Instructions:
 * 1. Replace YOUR_FCM_TOKEN with a real FCM token from the student app
 * 2. Update the Firebase Admin SDK initialization with your credentials
 * 3. Run this script with Node.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('./your-firebase-credentials.json'); // Path to your service account file

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

// Replace with a real FCM token from your app
const FCM_TOKEN = 'YOUR_FCM_TOKEN';

// Test notification with both notification and data fields (recommended)
const message = {
  notification: {
    title: 'Test Message',
    body: 'This is a test notification',
  },
  data: {
    type: 'chat',
    chatId: 'test-chat-id',
    senderId: 'admin',
    senderName: 'Admin Tester',
    click_action: 'FLUTTER_NOTIFICATION_CLICK',
  },
  android: {
    notification: {
      channel_id: 'chat_channel',
      priority: 'high',
      sound: 'default',
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    },
    priority: 'high',
  },
  token: FCM_TOKEN,
};

// Send the message
admin.messaging().send(message)
  .then(response => {
    console.log('Successfully sent message:', response);
  })
  .catch(error => {
    console.error('Error sending message:', error);
  });

// Alternative: Data-only message (for testing foreground notification handling)
const dataOnlyMessage = {
  data: {
    title: 'Data Only Test',
    body: 'This message only has data fields',
    type: 'chat',
    chatId: 'test-chat-id',
    senderId: 'admin',
    senderName: 'Admin Tester',
    click_action: 'FLUTTER_NOTIFICATION_CLICK',
  },
  android: {
    priority: 'high',
  },
  token: FCM_TOKEN,
};

// Uncomment to send data-only message
/*
admin.messaging().send(dataOnlyMessage)
  .then(response => {
    console.log('Successfully sent data-only message:', response);
  })
  .catch(error => {
    console.error('Error sending data-only message:', error);
  });
*/ 