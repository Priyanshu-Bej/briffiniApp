# Deploying Firebase Cloud Functions for Briffini App

This guide provides step-by-step instructions for deploying the Firebase Cloud Functions that handle push notifications for the Briffini App.

## Prerequisites

1. **Firebase CLI**: Make sure you have the Firebase CLI installed
   ```
   npm install -g firebase-tools
   ```

2. **Firebase Project**: Ensure you have access to the Firebase project used by the app

3. **Node.js**: Version 18 or later is required

## Initial Setup

1. **Login to Firebase**
   ```
   firebase login
   ```

2. **Select your Firebase project**
   ```
   firebase use --add
   ```
   Then select the project you want to deploy to.

3. **Install dependencies**
   ```
   cd firebase-functions
   npm install
   ```

## Configuration

### Firebase Project Settings

1. Make sure Firebase Cloud Messaging is enabled in your Firebase project
2. Ensure the Firebase Admin SDK has the necessary permissions

### Function Configuration

No additional configuration is needed for the basic functionality. The functions will automatically:
- Send notifications when an admin sends a chat message
- Clean up invalid FCM tokens daily

## Deployment

Deploy the functions to Firebase:

```
cd firebase-functions
firebase deploy --only functions
```

This will deploy two functions:
- `sendChatNotifications`: Triggers when a new message is added to the 'chats' collection
- `cleanupInvalidTokens`: Runs daily to clean up invalid FCM tokens

## Verification

After deployment, you can verify that the functions are working correctly:

1. **Check deployment status**
   ```
   firebase functions:log
   ```

2. **Test the notification flow**
   - Log in as an admin in the app
   - Send a message in the chat
   - Verify that other users receive a push notification

## Troubleshooting

### Common Issues

1. **Missing permissions**:
   - Ensure the Firebase service account has the necessary permissions
   - Check the Firebase Console > Project Settings > Service accounts

2. **Function timeouts**:
   - If functions time out, consider increasing the timeout in the function configuration
   - Add `timeoutSeconds: 300` to the function options if needed

3. **FCM token issues**:
   - Ensure FCM tokens are being properly saved in Firestore
   - Check that users are granting notification permissions

### Logs

View function logs for detailed error information:

```
firebase functions:log
```

## Updating Functions

To update the functions after making changes:

1. Make your changes to the code
2. Deploy again using the same command:
   ```
   firebase deploy --only functions
   ```

## Security Considerations

- The functions check if the message sender is an admin before sending notifications
- User tokens are stored securely in Firestore
- Invalid tokens are automatically cleaned up

## Additional Resources

- [Firebase Cloud Functions documentation](https://firebase.google.com/docs/functions)
- [Firebase Cloud Messaging documentation](https://firebase.google.com/docs/cloud-messaging)
- [Firebase Admin SDK documentation](https://firebase.google.com/docs/admin/setup) 