import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../utils/app_colors.dart';
import 'package:emoji_selector/emoji_selector.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'dart:async';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  bool _showEmoji = false;
  String? _replyToMessageId;
  String? _replyToSenderName;
  String? _replyToText;
  bool _isTyping = false;
  Timer? _typingTimer;
  List<Map<String, dynamic>> _allMessages = [];
  StreamSubscription? _incomingMessagesSubscription;
  StreamSubscription? _sentMessagesSubscription;

  @override
  void initState() {
    super.initState();
    _setupMessageListeners();
    _setupTypingListener();
  }

  void _setupMessageListeners() {
    // Listen to incoming messages
    _incomingMessagesSubscription = _chatService.getIncomingMessages().listen((messages) {
      _updateMessages();
    });

    // Listen to sent messages
    _sentMessagesSubscription = _chatService.getSentMessages().listen((messages) {
      _updateMessages();
    });
  }

  void _updateMessages() {
    // Combine and sort all messages
    final incomingMessages = _chatService.getIncomingMessages().first;
    final sentMessages = _chatService.getSentMessages().first;

    incomingMessages.then((incoming) {
      sentMessages.then((sent) {
        final allMessages = [...incoming, ...sent];
        allMessages.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
        
        if (mounted) {
          setState(() {
            _allMessages = allMessages;
          });
        }
      });
    });
  }

  void _setupTypingListener() {
    _messageController.addListener(() {
      if (_messageController.text.isNotEmpty && !_isTyping) {
        _setTypingStatus(true);
      }
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () {
        _setTypingStatus(false);
      });
    });
  }

  Future<void> _setTypingStatus(bool isTyping) async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return;

    setState(() => _isTyping = isTyping);
    await FirebaseFirestore.instance
        .collection('typing_status')
        .doc(user.uid)
        .set({
          'isTyping': isTyping,
          'timestamp': FieldValue.serverTimestamp(),
          'displayName': user.displayName,
        });
  }

  void _startReply(String messageId, String senderName, String text) {
    setState(() {
      _replyToMessageId = messageId;
      _replyToSenderName = senderName;
      _replyToText = text;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyToMessageId = null;
      _replyToSenderName = null;
      _replyToText = null;
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final result = await _chatService.sendMessage(
      text: _messageController.text.trim(),
      replyToMessageId: _replyToMessageId,
    );

    if (result['success']) {
      _messageController.clear();
      if (_replyToMessageId != null) _cancelReply();

      // Scroll to bottom after sending message
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: ${result['error']}')),
      );
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _incomingMessagesSubscription?.cancel();
    _sentMessagesSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF323483),
        title: Text(
          'Chat with Admin',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Typing Indicator
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('typing_status')
                .where('isTyping', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const SizedBox.shrink();
              }

              final typingUsers = snapshot.data!.docs
                  .map((doc) => doc.data() as Map<String, dynamic>)
                  .where((data) => data['displayName'] != user?.displayName)
                  .toList();

              if (typingUsers.isEmpty) return const SizedBox.shrink();

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.grey[200],
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Text(
                      typingUsers.length == 1
                          ? '${typingUsers.first['displayName']} is typing...'
                          : '${typingUsers.length} people are typing...',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.all(16),
              itemCount: _allMessages.length,
              itemBuilder: (context, index) {
                final message = _allMessages[index];
                final isMe = message['senderId'] == user?.uid;

                return MessageBubble(
                  message: message,
                  isMe: isMe,
                  status: message['status'] ?? 'sent',
                  onReply: () => _startReply(
                    message['id'],
                    message['senderName'],
                    message['text'],
                  ),
                );
              },
            ),
          ),

          // Reply Preview
          if (_replyToMessageId != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey[100],
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _replyToSenderName ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _replyToText ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _cancelReply,
                  ),
                ],
              ),
            ),

          // Message Input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _showEmoji ? Icons.keyboard : Icons.emoji_emotions_outlined,
                  ),
                  onPressed: () {
                    setState(() => _showEmoji = !_showEmoji);
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),

          // Emoji Picker
          if (_showEmoji)
            SizedBox(
              height: 250,
              child: EmojiSelector(
                onEmojiSelected: (emoji) {
                  setState(() {
                    _messageController.text += emoji.char;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }
}

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFF323483) : Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
                  style: TextStyle(color: isMe ? Colors.white : Colors.black),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTimestamp(message['timestamp'] as Timestamp?),
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

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final now = DateTime.now();
    final date = timestamp.toDate();
    final diff = now.difference(date);

    if (diff.inDays > 0) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
