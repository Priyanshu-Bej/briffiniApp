# Firebase Cloud Functions for Briffini App

This directory contains the Firebase Cloud Functions for the Briffini App.

## Functions

1. **sendChatNotifications** - Sends push notifications to users when an admin sends a chat message.
2. **storeNotification** - Creates notification records in the database when an admin sends a chat message.

## Deployment Instructions

### Prerequisites

1. Install Firebase CLI if you haven't already:
   ```
   npm install -g firebase-tools
   ```

2. Login to Firebase:
   ```
   firebase login
   ```

3. Install dependencies:
   ```
   cd firebase-functions
   npm install
   ```

### Deploy Functions

To deploy the functions to Firebase:

```
cd firebase-functions
firebase deploy --only functions
```

### Test Functions Locally

To test the functions locally:

```
cd firebase-functions
firebase emulators:start --only functions
```

## Troubleshooting

If you encounter any issues with the functions, check the Firebase Functions logs:

```
firebase functions:log
```

## Structure

- `index.js` - Contains the Cloud Functions code
- `package.json` - Node.js dependencies and configuration

## Notes

- Make sure the Firebase project is properly set up with Firestore and Firebase Cloud Messaging.
- The functions are configured to run on Node.js 18. 