import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../utils/app_colors.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
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
  bool _showEmoji = false;
  bool _isReplying = false;
  String? _replyToMessage;
  String? _replyToSender;
  bool _isTyping = false;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _setupTypingListener();
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
    await FirebaseFirestore.instance.collection('typing_status').doc(user.uid).set({
      'isTyping': isTyping,
      'timestamp': FieldValue.serverTimestamp(),
      'displayName': user.displayName,
    });
  }

  Future<void> _deleteMessage(String messageId) async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return;

    // Check if user is admin
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final isAdmin = userDoc.data()?['role'] == 'admin';

    if (!isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only admins can delete messages')),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('chats').doc(messageId).delete();
  }

  Future<void> _updateMessageStatus(String messageId, String status) async {
    await FirebaseFirestore.instance.collection('chats').doc(messageId).update({
      'status': status,
      'statusTimestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onEmojiSelected(String emoji) {
    setState(() {
      _messageController.text = _messageController.text + emoji;
    });
  }

  void _toggleEmojiPicker() {
    setState(() {
      _showEmoji = !_showEmoji;
    });
  }

  void _startReply(String message, String sender) {
    setState(() {
      _isReplying = true;
      _replyToMessage = message;
      _replyToSender = sender;
    });
  }

  void _cancelReply() {
    setState(() {
      _isReplying = false;
      _replyToMessage = null;
      _replyToSender = null;
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('chats').add({
        'text': _messageController.text.trim(),
        'sender': user.displayName ?? 'User',
        'userId': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'replyTo': _isReplying ? {
          'message': _replyToMessage,
          'sender': _replyToSender,
        } : null,
      });

      _messageController.clear();
      if (_isReplying) _cancelReply();
      
      // Scroll to bottom after sending message
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF323483),
        title: Text(
          'Chat',
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
                  .where((data) => data['displayName'] != Provider.of<AuthService>(context).currentUser?.displayName)
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
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;
                final currentUser = Provider.of<AuthService>(context).currentUser;

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index].data() as Map<String, dynamic>;
                    final isMe = message['userId'] == currentUser?.uid;
                    final replyTo = message['replyTo'] as Map<String, dynamic>?;
                    final messageId = messages[index].id;

                    return GestureDetector(
                      onLongPress: () async {
                        final userDoc = await FirebaseFirestore.instance
                            .collection('users')
                            .doc(currentUser?.uid)
                            .get();
                        final isAdmin = userDoc.data()?['role'] == 'admin';

                        if (isAdmin) {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Message?'),
                              content: const Text('This action cannot be undone.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    _deleteMessage(messageId);
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            if (replyTo != null) ...[
                              Container(
                                margin: EdgeInsets.only(
                                  left: isMe ? 0 : 48,
                                  right: isMe ? 48 : 0,
                                  bottom: 4,
                                ),
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      replyTo['sender'] ?? 'Unknown',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      replyTo['message'] ?? '',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            Row(
                              mainAxisAlignment: isMe
                                  ? MainAxisAlignment.end
                                  : MainAxisAlignment.start,
                              children: [
                                if (!isMe)
                                  CircleAvatar(
                                    backgroundColor: const Color(0xFF323483),
                                    radius: 16,
                                    child: Text(
                                      (message['sender'] as String?)?.isNotEmpty == true
                                          ? (message['sender'] as String).characters.first.toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                SizedBox(width: !isMe ? 8 : 0),
                                Flexible(
                                  child: InkWell(
                                    onLongPress: () => _startReply(
                                      message['text'] ?? '',
                                      message['sender'] ?? 'Unknown',
                                    ),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isMe
                                            ? const Color(0xFF323483)
                                            : Colors.grey[200],
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: isMe
                                            ? CrossAxisAlignment.end
                                            : CrossAxisAlignment.start,
                                        children: [
                                          if (!isMe)
                                            Text(
                                              message['sender'] ?? 'Unknown',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey[800],
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
                                ),
                                SizedBox(width: isMe ? 8 : 0),
                                if (isMe)
                                  CircleAvatar(
                                    backgroundColor: const Color(0xFF323483),
                                    radius: 16,
                                    child: Text(
                                      (message['sender'] as String?)?.isNotEmpty == true
                                          ? (message['sender'] as String).characters.first.toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Reply Preview
          if (_isReplying)
            Container(
              padding: EdgeInsets.all(8),
              color: Colors.grey[200],
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Replying to ${_replyToSender}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          _replyToMessage ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: _cancelReply,
                  ),
                ],
              ),
            ),

          // Message Input
          Container(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + safeAreaBottom),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _showEmoji ? Icons.keyboard : Icons.emoji_emotions_outlined,
                    color: const Color(0xFF323483),
                  ),
                  onPressed: _toggleEmojiPicker,
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
                      fillColor: Colors.grey[200],
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.send,
                    color: const Color(0xFF323483),
                  ),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),

          // Emoji Picker
          if (_showEmoji)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                onEmojiSelected: (category, emoji) {
                  _onEmojiSelected(emoji.emoji);
                },
                config: Config(
                  columns: 7,
                  emojiSizeMax: 32 * (foundation.defaultTargetPlatform == TargetPlatform.iOS ? 1.30 : 1.0),
                  verticalSpacing: 0,
                  horizontalSpacing: 0,
                  gridPadding: EdgeInsets.zero,
                  initCategory: Category.RECENT,
                  bgColor: const Color(0xFFF2F2F2),
                  indicatorColor: const Color(0xFF323483),
                  iconColor: Colors.grey,
                  iconColorSelected: const Color(0xFF323483),
                  backspaceColor: const Color(0xFF323483),
                  skinToneDialogBgColor: Colors.white,
                  skinToneIndicatorColor: Colors.grey,
                  enableSkinTones: true,
                  showRecentsTab: true,
                  recentsLimit: 28,
                  noRecents: const Text(
                    'No Recents',
                    style: TextStyle(fontSize: 20, color: Colors.black26),
                    textAlign: TextAlign.center,
                  ),
                  tabIndicatorAnimDuration: kTabScrollDuration,
                  categoryIcons: const CategoryIcons(),
                  buttonMode: ButtonMode.MATERIAL,
                ),
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
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
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
                    message['sender'] ?? 'Unknown',
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
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTimestamp(message['timestamp'] as Timestamp?),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
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