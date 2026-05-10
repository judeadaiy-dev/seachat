import 'widgets.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ربط مع ملفاتك الأساسية لضمان عمل الموديلات والتصميم
import 'models.dart';
import 'main.dart';
import 'package:timeago/timeago.dart' as timeago;

class PrivateChatScreen extends StatefulWidget {
  final UserModel receiver; // المستخدم المستهدف (المستلم)

  const PrivateChatScreen({super.key, required this.receiver});

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final supabase = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();

  // دالة إرسال الرسالة - مرتبطة بجدول private_messages في سوبابيز
  Future<void> _sendPrivateMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    _msgController.clear();

    try {
      await supabase.from('private_messages').insert({
        'sender_id': myId,
        'receiver_id': widget.receiver.id,
        'message': text,
        'created_at': DateTime.now().toIso8601String(),
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending private message: $e');
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = supabase.auth.currentUser?.id;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        // ربط العنوان ببيانات المستخدم المستلم
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: (widget.receiver.avatarUrl!= null && widget.receiver.avatarUrl!.isNotEmpty)
                 ? NetworkImage(widget.receiver.avatarUrl!)
                  : null,
              child: (widget.receiver.avatarUrl == null || widget.receiver.avatarUrl!.isEmpty)
                 ? const Icon(Icons.person, size: 20)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.receiver.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
      ),
      body: AppBackground( // استخدام الخلفية الموحدة للتطبيق
        child: Column(
          children: [
            Expanded(
              child: myId == null
               ? const Center(child: Text("يرجى تسجيل الدخول"))
                : StreamBuilder<List<Map<String, dynamic>>>(
                    stream: supabase
                     .from('private_messages')
                     .stream(primaryKey: ['id'])
                     .order('created_at', ascending: false),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text("خطأ: ${snapshot.error}"));
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      // فلترة الرسائل هنا بدل.or()
                      final messages = snapshot.data!.where((msg) {
                        final sender = msg['sender_id'];
                        final receiver = msg['receiver_id'];
                        return (sender == myId && receiver == widget.receiver.id) ||
                               (sender == widget.receiver.id && receiver == myId);
                      }).toList();

                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(16, 100, 16, 20),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final bool isMe = msg['sender_id'] == myId;
                          return _buildMessageBox(msg, isMe);
                        },
                      );
                    },
                  ),
            ),
            _buildInputArea(), // كان ناقص
          ], // كان ناقص
        ), // كان ناقص
      ), // كان ناقص
    ); // كان ناقص
  } // كان ناقص

  // تصميم فقاعة الرسالة - متوافق مع نظام ألوان SeaChat
  Widget _buildMessageBox(Map<String, dynamic> msg, bool isMe) {
    return Align(
      alignment: isMe? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: isMe? AppColors.button.withOpacity(0.8) : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: isMe? const Radius.circular(15) : Radius.zero,
            bottomRight: isMe? Radius.zero : const Radius.circular(15),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              msg['message']?? "",
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              msg['created_at']!= null
                 ? timeago.format(DateTime.parse(msg['created_at']), locale: 'ar')
                  : "",
              style: const TextStyle(color: Colors.white54, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _msgController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "اكتب رسالة خاصة...",
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendPrivateMessage,
              child: CircleAvatar(
                backgroundColor: AppColors.button,
                child: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

