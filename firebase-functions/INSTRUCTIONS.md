# Push Notification Implementation for Briffini App

This document provides instructions for implementing push notifications in the Briffini App, specifically for chat messages from admins to students.

## Overview

The implementation consists of two parts:
1. **Client-side**: The Flutter app that receives and displays notifications
2. **Server-side**: Firebase Cloud Functions that send notifications when admins post messages

## Implementation Details

### Client-Side (Flutter App)

The client-side implementation is already in place:

- `NotificationService` class handles FCM token registration and notification display
- Users subscribe to topics like `chat` and user-specific topics (`user_$userId`)
- FCM tokens are stored in Firestore for targeted notifications

### Server-Side (Firebase Cloud Functions)

Two Firebase Cloud Functions have been implemented:

1. **sendChatNotifications**: Triggers when a new message is added to the `chats` collection
   - Checks if the sender is an admin
   - Retrieves all user FCM tokens
   - Creates notification records in Firestore
   - Sends push notifications to all users except the sender

2. **cleanupInvalidTokens**: Runs daily to clean up invalid FCM tokens
   - Tests all stored tokens
   - Removes invalid tokens from Firestore

## Deployment Steps

1. Install Firebase CLI:
   ```
   npm install -g firebase-tools
   ```

2. Login to Firebase:
   ```
   firebase login
   ```

3. Navigate to the firebase-functions directory:
   ```
   cd firebase-functions
   ```

4. Install dependencies:
   ```
   npm install
   ```

5. Deploy the functions:
   ```
   firebase deploy --only functions
   ```

## Testing

To test the push notification system:

1. Log in as an admin in the app
2. Send a message in the chat
3. Verify that other users receive a push notification
4. Check the Firebase Functions logs for any errors:
   ```
   firebase functions:log
   ```

## Troubleshooting

If notifications are not being received:

1. Check if the user has granted notification permissions
2. Verify that FCM tokens are being stored correctly in Firestore
3. Check the Firebase Functions logs for errors
4. Ensure the user's device is connected to the internet
5. Verify that the sender has the admin role in Firestore

## Firestore Structure

The solution uses the following Firestore collections:

- **chats**: Contains all chat messages
- **user_tokens**: Stores FCM tokens with user IDs for quick lookup
- **users/{userId}/tokens**: Stores FCM tokens under each user document
- **notifications**: Stores notification records for in-app notification display

## Security Considerations

- Only messages from users with the admin role trigger notifications
- FCM tokens are stored securely in Firestore
- Invalid tokens are automatically cleaned up
- Firestore security rules restrict access to tokens and notifications 