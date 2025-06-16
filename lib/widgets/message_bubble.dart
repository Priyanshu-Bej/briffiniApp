import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final String status;
  final VoidCallback onReply;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
    required this.status,
    required this.onReply,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final replyToMessageId = message['replyToMessageId'] as String?;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (replyToMessageId != null)
            FutureBuilder<Map<String, dynamic>?>(
              future: FirebaseFirestore.instance
                  .collection('messages')
                  .doc(replyToMessageId)
                  .get()
                  .then((doc) => doc.exists ? {'id': doc.id, ...doc.data()!} : null),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final replyMessage = snapshot.data;
                if (replyMessage == null) return const SizedBox.shrink();

                return Container(
                  margin: EdgeInsets.only(bottom: 4),
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        replyMessage['senderName'] ?? 'Unknown',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        replyMessage['text'] ?? '',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          GestureDetector(
            onLongPress: onReply,
            child: Container(
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF323483) : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Text(
                      message['senderName'] ?? 'Unknown',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isMe ? Colors.white70 : Colors.black87,
                        fontSize: 12,
                      ),
                    ),
                  Text(
                    message['text'] ?? '',
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTimestamp(message['timestamp'] as DateTime?),
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
              if (isMe) ...[
                const SizedBox(width: 4),
                Icon(
                  status == 'sent'
                      ? Icons.check
                      : status == 'delivered'
                          ? Icons.done_all
                          : Icons.done_all,
                  size: 14,
                  color: status == 'read' ? Colors.blue : Colors.grey[600],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return '';
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inDays > 0) {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
} 