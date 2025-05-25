const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Cloud Function that triggers when a new message is added to the chats
 * collection. If the message is from an admin, it sends a notification to
 * all users.
 */
exports.sendChatNotifications = functions.firestore
  .document("chats/{messageId}")
  .onCreate(async (snapshot, context) => {
    try {
      const messageData = snapshot.data();
      const messageId = context.params.messageId;

      // Check if the message exists and has required fields
      if (!messageData) {
        console.log("No message data found");
        return null;
      }

      // Get the sender's user ID
      const senderId = messageData.userId;
      if (!senderId) {
        console.log("No sender ID found in message");
        return null;
      }

      // Check if the sender is an admin
      const senderDoc = await admin.firestore()
        .collection("users")
        .doc(senderId)
        .get();
      const senderData = senderDoc.data();

      if (!senderData || senderData.role !== "admin") {
        console.log("Sender is not an admin, skipping notification");
        return null;
      }

      console.log("Admin message detected, preparing notifications");

      // Get all user tokens except the sender's
      const tokensSnapshot = await admin.firestore()
        .collection("user_tokens")
        .where("userId", "!=", senderId)
        .get();

      if (tokensSnapshot.empty) {
        console.log("No user tokens found to send notifications");
        return null;
      }

      // Prepare notification data
      const notificationData = {
        title: `New message from ${messageData.sender || "Admin"}`,
        body: messageData.text || "You have a new message",
        type: "chat",
        chatId: messageId,
        senderId: senderId,
        senderName: messageData.sender || "Admin",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      };

      // Create a batch of notification records
      const batch = admin.firestore().batch();

      // Collect all tokens for FCM
      const tokens = [];

      // For each user, create a notification record and collect their tokens
      tokensSnapshot.docs.forEach((tokenDoc) => {
        const tokenData = tokenDoc.data();
        const userId = tokenData.userId;
        const token = tokenData.token;

        if (token) {
          tokens.push(token);
        }

        if (userId) {
          // Create a notification record for this user
          const notificationRef = admin.firestore()
            .collection("notifications")
            .doc();
          batch.set(notificationRef, {
            ...notificationData,
            userId: userId,
            read: false,
          });
        }
      });

      // Commit the notification records
      await batch.commit();
      console.log(`Created ${tokensSnapshot.size} notification records`);

      // If no tokens to send to, exit
      if (tokens.length === 0) {
        console.log("No valid tokens found for sending push notifications");
        return null;
      }

      // Prepare the FCM message
      const message = {
        notification: {
          title: notificationData.title,
          body: notificationData.body,
        },
        data: {
          type: "chat",
          chatId: messageId,
          senderId: senderId,
          senderName: messageData.sender || "Admin",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        tokens: tokens,
      };

      // Send the FCM message
      const response = await admin.messaging().sendMulticast(message);
      console.log(
        `Successfully sent message: ${response.successCount} successful, ` +
        `${response.failureCount} failed`,
      );

      // Handle failures if needed
      if (response.failureCount > 0) {
        const failedTokens = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            failedTokens.push(tokens[idx]);
          }
        });
        console.log("List of tokens that caused failures: ", failedTokens);
      }

      return {success: true, sentCount: response.successCount};
    } catch (error) {
      console.error("Error sending notifications:", error);
      return {error: error.message};
    }
  });

/**
 * Cloud Function to clean up invalid tokens
 * Runs on a schedule (once a day) to remove tokens that are no longer valid
 */
exports.cleanupInvalidTokens = functions.pubsub
  .schedule("every 24 hours")
  .onRun(async (context) => {
    try {
      const tokensSnapshot = await admin.firestore()
        .collection("user_tokens")
        .get();

      if (tokensSnapshot.empty) {
        console.log("No tokens to clean up");
        return null;
      }

      const tokens = tokensSnapshot.docs.map((doc) => ({
        token: doc.id,
        data: doc.data(),
      }));

      // Check tokens in batches of 500 (FCM limit)
      for (let i = 0; i < tokens.length; i += 500) {
        const batch = tokens.slice(i, i + 500);
        const tokenValues = batch.map((t) => t.token);

        try {
          const response = await admin.messaging().sendMulticast({
            data: {test: "true"},
            tokens: tokenValues,
          });

          // Process the failed tokens
          if (response.failureCount > 0) {
            const failedTokens = [];
            response.responses.forEach((resp, idx) => {
              if (!resp.success) {
                failedTokens.push(batch[idx].token);
              }
            });

            // Delete the invalid tokens
            const deletePromises = failedTokens.map(async (token) => {
              const tokenData = batch.find((t) => t.token === token)?.data;
              const userId = tokenData?.userId;

              // Delete from user_tokens collection
              await admin.firestore()
                .collection("user_tokens")
                .doc(token)
                .delete();

              // If we have a userId, also delete from the user's tokens collection
              if (userId) {
                await admin.firestore()
                  .collection("users")
                  .doc(userId)
                  .collection("tokens")
                  .doc(token)
                  .delete();
              }
            });

            await Promise.all(deletePromises);
            console.log(`Deleted ${failedTokens.length} invalid tokens`);
          }
        } catch (error) {
          console.error(`Error checking token batch ${i}-${i+500}:`, error);
        }
      }

      return {success: true};
    } catch (error) {
      console.error("Error cleaning up tokens:", error);
      return {error: error.message};
    }
  });
