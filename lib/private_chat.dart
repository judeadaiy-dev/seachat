import 'package:flutter/material.dart';
import 'app.dart';
// 1. شاشة قائمة المحادثات الخاصة - main.dart يستدعيها بهذا الاسم
class PrivateChatsScreen extends StatelessWidget {
  const PrivateChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .neq('id', Supabase.instance.client.auth.currentUser?.id?? ''),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.button));
          }
          if (snapshot.hasError) {
            return Center(child: Text('خطأ: ${snapshot.error}', style: const TextStyle(color: AppColors.textDark)));
          }
          final users = snapshot.data?? [];
          if (users.isEmpty) {
            return const Center(child: Text('لا يوجد مستخدمين', style: TextStyle(color: AppColors.textDark)));
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = UserModel.fromMap(users[index]);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PrivateChatScreen(receiver: user)),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.icon,
                      backgroundImage: (user.avatarUrl!= null && user.avatarUrl!.isNotEmpty)
                      ? NetworkImage(user.avatarUrl!)
                        : null,
                      child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                      ? const Icon(Icons.person, color: Colors.white)
                        : null,
                    ),
                    title: Text(user.name, style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600)),
                    subtitle: Text(user.username?? '', style: TextStyle(color: AppColors.textDark.withOpacity(0.7))),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.button),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// 2. شاشة المحادثة المفردة
class PrivateChatScreen extends StatefulWidget {
  final UserModel receiver;

  const PrivateChatScreen({super.key, required this.receiver});

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final supabase = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();

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
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.icon,
              backgroundImage: (widget.receiver.avatarUrl!= null && widget.receiver.avatarUrl!.isNotEmpty)
              ? NetworkImage(widget.receiver.avatarUrl!)
                : null,
              child: (widget.receiver.avatarUrl == null || widget.receiver.avatarUrl!.isEmpty)
              ? const Icon(Icons.person, size: 20, color: Colors.white)
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
        backgroundColor: const Color(0xFF4DD0E1), // فيروزي
        elevation: 0,
      ),
      body: Container(
        color: AppColors.primaryBlue,
        child: Column(
          children: [
            Expanded(
              child: myId == null
              ? const Center(child: Text("يرجى تسجيل الدخول", style: TextStyle(color: AppColors.textDark)))
                : StreamBuilder<List<Map<String, dynamic>>>(
                    stream: supabase
                    .from('private_messages')
                    .stream(primaryKey: ['id'])
                    .order('created_at', ascending: false),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text("خطأ: ${snapshot.error}", style: const TextStyle(color: AppColors.textDark)));
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.button));
                      }

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
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBox(Map<String, dynamic> msg, bool isMe) {
    return Align(
      alignment: isMe? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: isMe? AppColors.button : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: isMe? const Radius.circular(15) : Radius.zero,
            bottomRight: isMe? Radius.zero : const Radius.circular(15),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
        ),
        child: Column(
          crossAxisAlignment: isMe? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              msg['message']?? "",
              style: TextStyle(color: isMe? Colors.white : AppColors.textDark, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              msg['created_at']!= null
              ? timeago.format(DateTime.parse(msg['created_at']), locale: 'ar')
                : "",
              style: TextStyle(color: isMe? Colors.white70 : Colors.grey, fontSize: 9),
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
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _msgController,
                style: const TextStyle(color: AppColors.textDark),
                decoration: InputDecoration(
                  hintText: "اكتب رسالة خاصة...",
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: AppColors.primaryBlue.withOpacity(0.3),
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
