import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String receiverId;
  final String text;
  final Timestamp timestamp;
  final String status;
  final String type;
  final bool isCommunity;

  CommunityChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    required this.status,
    required this.type,
    this.isCommunity = true,
  });

  factory CommunityChatMessage.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CommunityChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      receiverId: data['receiverId'] ?? 'COMMUNITY',
      text: data['text'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      status: data['status'] ?? 'sent',
      type: data['type'] ?? 'text',
      isCommunity: data['isCommunity'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'receiverId': receiverId,
      'text': text,
      'timestamp': timestamp,
      'status': status,
      'type': type,
      'isCommunity': isCommunity,
    };
  }
} 