const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * NOTE: This file previously contained a function for sending chat notifications.
 * This functionality has been removed as it's now handled by the admin app team's
 * notification system. We maintain only the token cleanup function below.
 *
 * The student app still registers tokens in Firestore collections:
 * - user_tokens/{token}
 * - users/{userId}/tokens/{token}
 *
 * These tokens are used by the admin app's notification system.
 */

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
