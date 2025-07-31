import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/community_chat_message.dart';
import '../utils/logger.dart';
import '../main.dart'; // For FirebaseInitState

class CommunityChatService {
  FirebaseFirestore? _firestore;
  final String _collection = 'communityChat';

  CommunityChatService() {
    _initializeFirebase();
  }

  Future<void> _initializeFirebase() async {
    try {
      await FirebaseInitState.ensureInitialized();
      _firestore = FirebaseFirestore.instance;
      Logger.i("CommunityChatService: Firebase initialized successfully");
    } catch (e) {
      Logger.e("CommunityChatService: Failed to initialize Firebase: $e");
    }
  }

  // Get stream of community chat messages
  Stream<List<CommunityChatMessage>> getCommunityMessages() {
    if (_firestore == null) {
      return Stream.value([]);
    }
    return _firestore!
        .collection(_collection)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => CommunityChatMessage.fromFirestore(doc))
                  .toList(),
        );
  }

  // Send a new message to community chat
  Future<void> sendMessage({
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    try {
      await _firestore.collection(_collection).add({
        'senderId': senderId,
        'senderName': senderName,
        'receiverId': 'COMMUNITY',
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'sent',
        'type': 'text',
        'isCommunity': true,
      });
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  // Update message status
  Future<void> updateMessageStatus({
    required String messageId,
    required String status,
  }) async {
    try {
      await _firestore.collection(_collection).doc(messageId).update({
        'status': status,
      });
    } catch (e) {
      throw Exception('Failed to update message status: $e');
    }
  }

  // Optional: Add system welcome message if collection is empty
  Future<void> addWelcomeMessageIfNeeded() async {
    final messages = await _firestore.collection(_collection).limit(1).get();
    if (messages.docs.isEmpty) {
      await _firestore.collection(_collection).add({
        'senderId': 'system',
        'senderName': 'System',
        'receiverId': 'COMMUNITY',
        'text':
            'Welcome to the Community Chat! 👋 Feel free to start a conversation with your fellow students and admins.',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'sent',
        'type': 'text',
        'isCommunity': true,
      });
    }
  }
}
