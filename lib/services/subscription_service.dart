import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/logger.dart';

/// Service for managing user subscriptions and course access validation
class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get all subscriptions for a specific user
  Future<List<Map<String, dynamic>>> getUserSubscriptions(
    String userId, {
    bool forceRefresh = false,
  }) async {
    try {
      Logger.i(
        '📋 Fetching subscriptions for user: $userId (forceRefresh: $forceRefresh)',
      );

      final querySnapshot = await _firestore
          .collection('subscriptions')
          .where('userId', isEqualTo: userId)
          .get(forceRefresh ? const GetOptions(source: Source.server) : null);

      final subscriptions = <Map<String, dynamic>>[];

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        subscriptions.add({
          'id': doc.id,
          ...data,
          'startDate':
              (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'endDate':
              (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
        });
      }

      Logger.i(
        '📋 Found ${subscriptions.length} subscriptions for user $userId',
      );
      return subscriptions;
    } catch (error) {
      Logger.e('❌ Error fetching user subscriptions: $error');
      return [];
    }
  }

  /// Check if user has at least one active subscription
  Future<bool> checkUserActiveSubscription(
    String userId, {
    bool forceRefresh = false,
  }) async {
    try {
      Logger.i(
        '🔍 Checking active subscription for user: $userId (forceRefresh: $forceRefresh)',
      );

      final subscriptions = await getUserSubscriptions(
        userId,
        forceRefresh: forceRefresh,
      );

      // Check if user has at least one active subscription
      final hasActiveSubscription = subscriptions.any((subscription) {
        final status = subscription['status'] as String?;
        final endDate = subscription['endDate'] as DateTime?;

        return status == 'active' &&
            endDate != null &&
            endDate.isAfter(DateTime.now());
      });

      Logger.i(
        '🔍 User $userId has active subscription: $hasActiveSubscription',
      );
      return hasActiveSubscription;
    } catch (error) {
      Logger.e('❌ Error checking user active subscription: $error');
      return false;
    }
  }

  /// Check if user has access to a specific course (combines assignment + subscription check)
  Future<bool> hasAccessToCourse(
    String userId,
    String courseId, {
    bool forceRefresh = false,
  }) async {
    try {
      Logger.i(
        '🔐 Checking course access for user $userId, course $courseId (forceRefresh: $forceRefresh)',
      );

      // Get user data
      final userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get(forceRefresh ? const GetOptions(source: Source.server) : null);

      if (!userDoc.exists) {
        Logger.w('⚠️ User document not found: $userId');
        return false;
      }

      final userData = userDoc.data()!;

      // Check if course is assigned
      final assignedCourseIds = List<String>.from(
        userData['assignedCourseIds'] ?? [],
      );
      final isAssignedToCourse = assignedCourseIds.contains(courseId);

      if (!isAssignedToCourse) {
        Logger.w('⚠️ Course $courseId not assigned to user $userId');
        return false;
      }

      // CRITICAL: Check if user has an active subscription
      final hasActiveSubscription = await checkUserActiveSubscription(
        userId,
        forceRefresh: forceRefresh,
      );

      if (!hasActiveSubscription) {
        Logger.w(
          '⚠️ User $userId has no active subscription for course $courseId',
        );
        return false;
      }

      Logger.i('✅ User $userId has access to course $courseId');
      return true;
    } catch (error) {
      Logger.e('❌ Error checking course access: $error');
      return false;
    }
  }

  /// Get current user's subscription status
  Future<Map<String, dynamic>?> getCurrentUserSubscriptionStatus({
    bool forceRefresh = false,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        Logger.w('⚠️ No current user for subscription status check');
        return null;
      }

      final subscriptions = await getUserSubscriptions(
        currentUser.uid,
        forceRefresh: forceRefresh,
      );

      if (subscriptions.isEmpty) {
        return {
          'hasSubscription': false,
          'isActive': false,
          'message': 'No subscription found',
        };
      }

      // Find the most recent active subscription
      final activeSubscriptions =
          subscriptions.where((sub) {
            final status = sub['status'] as String?;
            final endDate = sub['endDate'] as DateTime?;
            return status == 'active' &&
                endDate != null &&
                endDate.isAfter(DateTime.now());
          }).toList();

      if (activeSubscriptions.isNotEmpty) {
        final latestSub = activeSubscriptions.first;
        return {
          'hasSubscription': true,
          'isActive': true,
          'endDate': latestSub['endDate'],
          'daysRemaining':
              (latestSub['endDate'] as DateTime)
                  .difference(DateTime.now())
                  .inDays,
          'subscription': latestSub,
        };
      }

      // Check for expired subscriptions
      final expiredSubs =
          subscriptions.where((sub) {
            final endDate = sub['endDate'] as DateTime?;
            return endDate != null && endDate.isBefore(DateTime.now());
          }).toList();

      if (expiredSubs.isNotEmpty) {
        return {
          'hasSubscription': true,
          'isActive': false,
          'message': 'Subscription expired',
          'lastEndDate': expiredSubs.first['endDate'],
        };
      }

      return {
        'hasSubscription': false,
        'isActive': false,
        'message': 'No valid subscription',
      };
    } catch (error) {
      Logger.e('❌ Error getting current user subscription status: $error');
      return null;
    }
  }

  /// Listen to real-time changes in user's subscription status
  Stream<bool> subscriptionStatusStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().asyncMap((
      doc,
    ) async {
      if (!doc.exists) return false;

      final userData = doc.data()!;
      final assignedCourseIds = List<String>.from(
        userData['assignedCourseIds'] ?? [],
      );

      // If no courses assigned, subscription likely expired
      if (assignedCourseIds.isEmpty) {
        return false;
      }

      // Double-check with subscription validation
      return await checkUserActiveSubscription(userId);
    });
  }

  /// Check if subscription is expiring soon (within specified days)
  Future<bool> isSubscriptionExpiringSoon(
    String userId, {
    int daysThreshold = 7,
  }) async {
    try {
      final subscriptions = await getUserSubscriptions(userId);

      for (final subscription in subscriptions) {
        final status = subscription['status'] as String?;
        final endDate = subscription['endDate'] as DateTime?;

        if (status == 'active' && endDate != null) {
          final daysUntilExpiry = endDate.difference(DateTime.now()).inDays;
          if (daysUntilExpiry <= daysThreshold && daysUntilExpiry > 0) {
            Logger.i('⚠️ Subscription expiring in $daysUntilExpiry days');
            return true;
          }
        }
      }

      return false;
    } catch (error) {
      Logger.e('❌ Error checking subscription expiry: $error');
      return false;
    }
  }
}
