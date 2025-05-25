# Push Notification Solution for Briffini App

## Overview

This solution implements push notifications for the Briffini App, specifically to notify students when an admin sends a message in the chat. The implementation uses Firebase Cloud Functions and Firebase Cloud Messaging (FCM).

## Components

### 1. Client-Side (Flutter App)

The Flutter app already has the necessary components for receiving push notifications:

- **NotificationService**: Handles FCM token registration, permission requests, and notification display
- **Topic Subscriptions**: Users subscribe to topics like `chat` and user-specific topics
- **Token Storage**: FCM tokens are stored in Firestore for sending targeted notifications

### 2. Server-Side (Firebase Cloud Functions)

Two Firebase Cloud Functions have been implemented:

- **sendChatNotifications**: Triggers when a new message is added to the `chats` collection
  - Checks if the sender is an admin
  - Retrieves all user FCM tokens
  - Creates notification records in Firestore
  - Sends push notifications to all users except the sender

- **cleanupInvalidTokens**: Runs daily to clean up invalid FCM tokens
  - Tests all stored tokens
  - Removes invalid tokens from Firestore

## Data Flow

1. Admin sends a message in the chat
2. Message is stored in the `chats` collection in Firestore
3. `sendChatNotifications` function triggers automatically
4. Function checks if the sender has an admin role
5. Function retrieves FCM tokens for all users
6. Function creates notification records in the `notifications` collection
7. Function sends FCM messages to all user devices
8. User devices receive the notification and display it
9. When tapped, the notification opens the chat screen

## Firestore Collections

The solution uses the following Firestore collections:

- **chats**: Contains all chat messages
- **user_tokens**: Stores FCM tokens with user IDs for quick lookup
- **users/{userId}/tokens**: Stores FCM tokens under each user document
- **notifications**: Stores notification records for in-app notification display

## Security

- Only messages from users with the admin role trigger notifications
- FCM tokens are stored securely in Firestore
- Invalid tokens are automatically cleaned up
- Firestore security rules restrict access to tokens and notifications

## Testing

To test the push notification system:

1. Deploy the Firebase Cloud Functions
2. Log in as an admin in the app
3. Send a message in the chat
4. Verify that other users receive a push notification
5. Check the Firebase Functions logs for any errors

## Maintenance

- Monitor the Firebase Functions logs for errors
- Update the functions as needed
- Consider implementing additional notification types in the future 