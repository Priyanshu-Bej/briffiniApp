import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Stream for incoming messages (where student is receiver)
  Stream<List<Map<String, dynamic>>> getIncomingMessages() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('messages')
        .where('receiverId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                ...data,
                'timestamp': data['timestamp']?.toDate() ?? DateTime.now(),
              };
            }).toList());
  }

  // Stream for sent messages (from student to admin)
  Stream<List<Map<String, dynamic>>> getSentMessages() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('messages')
        .where('senderId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                ...data,
                'timestamp': data['timestamp']?.toDate() ?? DateTime.now(),
              };
            }).toList());
  }

  // Send a new message
  Future<Map<String, dynamic>> sendMessage({
    required String text,
    String? replyToMessageId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to send messages');
    }

    final messageData = {
      'text': text,
      'senderId': user.uid,
      'senderName': user.displayName ?? 'Unknown User',
      'receiverId': 'ADMIN',
      'timestamp': FieldValue.serverTimestamp(),
      'statusTimestamp': FieldValue.serverTimestamp(),
      'status': 'sent',
      'type': 'text',
      if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
    };

    try {
      final docRef = await _firestore.collection('messages').add(messageData);
      return {
        'success': true,
        'id': docRef.id,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Update message status
  Future<void> updateMessageStatus(String messageId, String status) async {
    await _firestore.collection('messages').doc(messageId).update({
      'status': status,
      'statusTimestamp': FieldValue.serverTimestamp(),
    });
  }

  // Delete message (admin only)
  Future<void> deleteMessage(String messageId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be logged in');

    // Check if user is admin
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (userDoc.data()?['role'] != 'admin') {
      throw Exception('Only admins can delete messages');
    }

    await _firestore.collection('messages').doc(messageId).delete();
  }

  // Get a single message by ID
  Future<Map<String, dynamic>?> getMessage(String messageId) async {
    final doc = await _firestore.collection('messages').doc(messageId).get();
    if (!doc.exists) return null;

    final data = doc.data()!;
    return {
      'id': doc.id,
      ...data,
      'timestamp': data['timestamp']?.toDate() ?? DateTime.now(),
    };
  }
} 