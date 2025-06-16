import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setupMessageListener();
  }

  void _setupMessageListener() {
    _chatService.getMessages().listen(
      (messages) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
      },
      onError: (error) {
        setState(() {
          _error = 'Error loading messages: $error';
          _isLoading = false;
        });
        print('Error in message stream: $error');
      },
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    try {
      final result = await _chatService.sendMessage(text: text);
      if (!result['success']) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${result['error']}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sending message: $e')));
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat with Admin'),
        backgroundColor: const Color(0xFF323483),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _error = null;
              });
              _setupMessageListener();
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showDebugInfo,
                    ),
                  ],
                ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
                                      onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _setupMessageListener();
              },
              child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                          );
                        }

    return Column(
                          children: [
        // Messages list
        Expanded(
          child:
              _messages.isEmpty
                  ? const Center(child: Text('No messages yet'))
                  : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final currentUser = FirebaseAuth.instance.currentUser;
                      final isMe = message['senderId'] == currentUser?.uid;

                      return _buildMessageBubble(message, isMe);
              },
            ),
          ),

        // Message input
            Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: null,
                ),
              ),
              const SizedBox(width: 8.0),
              CircleAvatar(
                backgroundColor: const Color(0xFF323483),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _sendMessage,
                ),
                ),
              ],
            ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe) {
    final timestamp =
        message['timestamp'] is Timestamp
            ? message['timestamp'].toDate()
            : message['timestamp'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) const SizedBox(width: 12),

          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 10.0,
              ),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFF323483) : Colors.grey[200],
                borderRadius: BorderRadius.circular(16.0),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        message['senderName'] ?? 'Unknown',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                          fontSize: 12.0,
                      color: isMe ? Colors.white70 : Colors.black87,
                        ),
                      ),
                  ),
                Text(
                  message['text'] ?? '',
                  style: TextStyle(color: isMe ? Colors.white : Colors.black),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                        _formatTimestamp(timestamp),
                        style: TextStyle(
                          fontSize: 10.0,
                          color: isMe ? Colors.white70 : Colors.black54,
                        ),
              ),
              if (isMe) ...[
                const SizedBox(width: 4),
                Icon(
                          message['status'] == 'read'
                      ? Icons.done_all
                              : Icons.done,
                          size: 12.0,
                          color:
                              message['status'] == 'read'
                                  ? Colors.blue[100]
                                  : Colors.white70,
                ),
              ],
            ],
          ),
                ],
              ),
            ),
          ),

          if (isMe) const SizedBox(width: 12),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
    );

    if (messageDate == today) {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  void _showDebugInfo() {
    final user = FirebaseAuth.instance.currentUser;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Debug Information'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('User ID: ${user?.uid ?? 'Not logged in'}'),
                Text('Display Name: ${user?.displayName ?? 'N/A'}'),
                const SizedBox(height: 8),
                Text('Messages loaded: ${_messages.length}'),
                const SizedBox(height: 16),
                const Text('Actions:'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _checkFirestore();
                },
                child: const Text('Check Firestore'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _sendTestMessage();
                },
                child: const Text('Send Test Message'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Future<void> _checkFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: User not logged in')),
        );
        return;
      }

      // Check messages in Firestore
      final receivedQuery =
          await FirebaseFirestore.instance
              .collection('messages')
              .where('receiverId', isEqualTo: user.uid)
              .orderBy('timestamp', descending: true)
              .limit(10)
              .get();

      final sentQuery =
          await FirebaseFirestore.instance
              .collection('messages')
              .where('senderId', isEqualTo: user.uid)
              .orderBy('timestamp', descending: true)
              .limit(10)
              .get();

      // Show results
      if (!context.mounted) return;

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Firestore Check'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Received messages: ${receivedQuery.docs.length}'),
                    Text('Sent messages: ${sentQuery.docs.length}'),
                    const SizedBox(height: 16),
                    if (receivedQuery.docs.isNotEmpty) ...[
                      const Text('Latest received message:'),
                      const SizedBox(height: 4),
                      _buildMessagePreview(receivedQuery.docs.first),
                      const SizedBox(height: 8),
                    ],
                    if (sentQuery.docs.isNotEmpty) ...[
                      const Text('Latest sent message:'),
                      const SizedBox(height: 4),
                      _buildMessagePreview(sentQuery.docs.first),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error checking Firestore: $e')));
    }
  }

  Widget _buildMessagePreview(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ID: ${doc.id}'),
          Text('Sender: ${data['senderId']}'),
          Text('Receiver: ${data['receiverId']}'),
          Text('Text: ${data['text']}'),
          Text('Timestamp: ${data['timestamp']?.toDate()}'),
        ],
      ),
    );
  }

  Future<void> _sendTestMessage() async {
    try {
      final result = await _chatService.sendMessage(
        text: 'Test message sent at ${DateTime.now()}',
      );

      if (!context.mounted) return;

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test message sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
