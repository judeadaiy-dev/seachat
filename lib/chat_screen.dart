import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';
import 'main.dart'; // للوصول إلى AppBackground و AppColors
import 'package:timeago/timeago.dart' as timeago;

class ChatScreen extends StatefulWidget {
  final RoomModel room; // تم التعديل من ChatRoom إلى RoomModel
  const ChatScreen({super.key, required this.room});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final supabase = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();
Future<void> _sendMessage() async {
  final text = _msgController.text.trim();
  if (text.isEmpty) return;

  _msgController.clear();
  try {
    await supabase.from('messages').insert({
      'room_id': widget.room.id,
      'user_id': supabase.auth.currentUser!.id,
      'content': text,           // ✅ بدلت message إلى content
      'topic': 'general',        // ✅ ضفت هذا - حقل إجباري
      'extension': 'txt',        // ✅ ضفت هذا - حقل إجباري
    });
    _scrollToBottom();
  } catch (e) {
    print('Error: $e'); // اطبع الخطأ عشان تشوفه
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل إرسال الرسالة: $e')));
  }
}

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    // استخدام حقل isPinned لتمييز الغرف الرسمية
    final isOfficial = widget.room.isPinned;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.room.roomName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(isOfficial ? 'غرفة رسمية للمسؤولين' : 'دردشة جماعية', 
                 style: const TextStyle(fontSize: 10, color: Colors.white70)),
          ],
        ),
        // استخدام اللون البني (Nature/Wood) للغرف الرسمية كما طلبت سابقاً
        backgroundColor: isOfficial ? Colors.brown.withOpacity(0.6) : Colors.transparent,
        elevation: 0,
      ),
      body: AppBackground(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                // استخدام السحب المباشر مع ربط البروفايلات لجلب الأسماء
                stream: supabase
                    .from('messages')
                    .stream(primaryKey: ['id'])
                    .eq('room_id', widget.room.id)
                    .order('created_at', ascending: false),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final msgs = snapshot.data!;
                  
                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(16, 100, 16, 20),
                    itemCount: msgs.length,
                    itemBuilder: (context, i) {
                      final msgData = msgs[i];
                      // تحويل البيانات لموديل الرسالة لسهولة التعامل
                      final msg = MessageModel.fromMap(msgData, supabase.auth.currentUser!.id);
                      
                      return _buildMessageBubble(msg);
                    },
                  );
                },
              ),
            ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel msg) {
    final bool isMe = msg.isMe;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft, // تم تصحيح الاتجاهات
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          // استخدام ألوان التطبيق الموحدة
          color: isMe ? AppColors.button.withOpacity(0.9) : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // سنحتاج لاحقاً لجلب اسم المرسل عبر join في السوبابيز
            if (!isMe) const Text('عضو الغرفة', 
                style: TextStyle(fontSize: 10, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
            Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              timeago.format(msg.createdAt, locale: 'ar'),
              style: const TextStyle(fontSize: 9, color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _msgController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'اكتب رسالتك هنا...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                  fillColor: Colors.white.withOpacity(0.1),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: AppColors.button,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

