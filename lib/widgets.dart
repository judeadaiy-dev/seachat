import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:io';
import 'main.dart';

class ChatScreen extends StatefulWidget {
  final RoomModel room;
  const ChatScreen({required this.room});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgController = TextEditingController();
  final _picker = ImagePicker();
  Timer? _typingTimer;
  bool _isRecording = false;

  void _onTyping() {
    repo.updateTypingStatus(roomId: widget.room.id, isTyping: true);
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      repo.updateTypingStatus(roomId: widget.room.id, isTyping: false);
    });
  }

  Future<void> _sendText() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();
    repo.updateTypingStatus(roomId: widget.room.id, isTyping: false);
    try {
      await repo.sendMessage(roomId: widget.room.id, text: text, messageType: 'text');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل الارسال'), backgroundColor: AppColors.error));
    }
  }

  Future<void> _sendImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;
    try {
      final url = await repo.uploadChatMedia(picked.path, 'image');
      await repo.sendMessage(roomId: widget.room.id, mediaUrl: url, messageType: 'image');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل رفع الصورة'), backgroundColor: AppColors.error));
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await repo.stopRecording();
      setState(() => _isRecording = false);
      if (path!= null) {
        try {
          final url = await repo.uploadChatMedia(path, 'audio');
          await repo.sendMessage(roomId: widget.room.id, mediaUrl: url, messageType: 'audio');
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل رفع الصوت'), backgroundColor: AppColors.error));
        }
      }
    } else {
      await repo.startRecording();
      setState(() => _isRecording = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        title: Row(children: [
          CircleAvatar(backgroundImage: widget.room.imageUrl!= null? CachedNetworkImageProvider(widget.room.imageUrl!) : null, child: widget.room.imageUrl == null? const Icon(Icons.group) : null),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.room.roomName, style: const TextStyle(color: AppColors.textDark, fontSize: 16, fontWeight: FontWeight.bold)),
              StreamBuilder<bool>(
                stream: repo.getTypingStream(roomId: widget.room.id),
                builder: (context, snapshot) => snapshot.data == true? const Text('يكتب...', style: TextStyle(color: AppColors.success, fontSize: 12)) : const SizedBox(),
              ),
            ]),
          ),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: StreamBuilder<List<MessageModel>>(
            stream: repo.getRoomMessagesStream(roomId: widget.room.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final msgs = snapshot.data!;
              return ListView.builder(reverse: true, padding: const EdgeInsets.all(8), itemCount: msgs.length, itemBuilder: (context, i) => MessageBubble(msg: msgs[i]));
            },
          ),
        ),
        _buildInputBar(),
      ]),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: AppColors.card,
      child: SafeArea(
        child: Row(children: [
          IconButton(icon: Icon(_isRecording? Icons.stop_circle : Icons.mic, color: _isRecording? AppColors.error : AppColors.textLight), onPressed: _toggleRecording),
          IconButton(icon: const Icon(Icons.image, color: AppColors.textLight), onPressed: _sendImage),
          Expanded(
            child: TextField(
              controller: _msgController,
              onChanged: (_) => _onTyping(),
              style: const TextStyle(color: AppColors.textDark),
              decoration: InputDecoration(
                hintText: 'اكتب رسالتك...',
                hintStyle: const TextStyle(color: AppColors.textLight),
                filled: true,
                fillColor: AppColors.primaryBlue,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(backgroundColor: AppColors.button, child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _sendText)),
        ]),
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final MessageModel msg;
  const MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: msg.isMe &&!msg.isDeleted? () => _showDeleteDialog(context) : null,
      child: Align(
        alignment: msg.isMe? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(top: 4, bottom: 4, left: msg.isMe? 60 : 12, right: msg.isMe? 12 : 60),
          child: Column(crossAxisAlignment: msg.isMe? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
            if (!msg.isMe && msg.user!= null) Padding(padding: const EdgeInsets.only(bottom: 4, right: 4), child: Text(msg.user!.name, style: const TextStyle(color: AppColors.textLight, fontSize: 12))),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: msg.isMe? AppColors.button : AppColors.card, borderRadius: BorderRadius.circular(16)),
              child: _buildMessageContent(),
            ),
            Padding(padding: const EdgeInsets.only(top: 4, right: 4), child: Text(DateFormat('HH:mm').format(msg.createdAt), style: const TextStyle(color: AppColors.textLight, fontSize: 10))),
          ]),
        ),
      ),
    );
  }

  Widget _buildMessageContent() {
    if (msg.isDeleted) {
      return Text(msg.text, style: const TextStyle(color: AppColors.textLight, fontStyle: FontStyle.italic));
    }

    switch (msg.messageType) {
      case 'image':
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: msg.mediaUrl!,
            width: 200,
            placeholder: (context, url) => Container(width: 200, height: 200, color: AppColors.primaryBlue, child: const Center(child: CircularProgressIndicator())),
            errorWidget: (context, url, error) => Container(
              width: 200,
              height: 150,
              color: AppColors.primaryBlue,
              child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.error_outline, color: AppColors.textLight),
                SizedBox(height: 8),
                Text('فشل تحميل الصورة', style: TextStyle(color: AppColors.textLight, fontSize: 12)),
              ])
            ),
          ),
        );
      case 'audio':
        return _AudioMessageBubble(audioUrl: msg.mediaUrl!);
      default:
        return Text(msg.text, style: const TextStyle(color: Colors.white));
    }
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف الرسالة', style: TextStyle(color: AppColors.textDark)),
        content: const Text('هل تريد حذف هذه الرسالة؟', style: TextStyle(color: AppColors.textLight)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('الغاء')),
          TextButton(
            onPressed: () {
              repo.deleteMessage(msg.id);
              Navigator.pop(context);
            },
            child: const Text('حذف', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _AudioMessageBubble extends StatefulWidget {
  final String audioUrl;
  const _AudioMessageBubble({required this.audioUrl});

  @override
  State<_AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends State<_AudioMessageBubble> {
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _isPlaying =!_isPlaying);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isPlaying? 'جاري التشغيل...' : 'تم الإيقاف'),
            backgroundColor: AppColors.button,
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_isPlaying? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.white, size: 32),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('رسالة صوتية', style: TextStyle(color: Colors.white, fontSize: 14)),
            Text(_isPlaying? 'جاري التشغيل' : 'اضغط للتشغيل', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
          ]),
        ],
      ),
    );
  }
}

class PrivateChatScreen extends StatefulWidget {
  final UserModel otherUser;
  const PrivateChatScreen({required this.otherUser});
  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final _msgController = TextEditingController();
  final _picker = ImagePicker();
  Timer? _typingTimer;
  bool _isRecording = false;

  void _onTyping() {
    repo.updateTypingStatus(receiverId: widget.otherUser.id, isTyping: true);
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      repo.updateTypingStatus(receiverId: widget.otherUser.id, isTyping: false);
    });
  }

  Future<void> _sendText() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();
    repo.updateTypingStatus(receiverId: widget.otherUser.id, isTyping: false);
    try {
      await repo.sendMessage(receiverId: widget.otherUser.id, text: text, messageType: 'text');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل الارسال'), backgroundColor: AppColors.error));
    }
  }

  Future<void> _sendImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;
    try {
      final url = await repo.uploadChatMedia(picked.path, 'image');
      await repo.sendMessage(receiverId: widget.otherUser.id, mediaUrl: url, messageType: 'image');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل رفع الصورة'), backgroundColor: AppColors.error));
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await repo.stopRecording();
      setState(() => _isRecording = false);
      if (path!= null) {
        try {
          final url = await repo.uploadChatMedia(path, 'audio');
          await repo.sendMessage(receiverId: widget.otherUser.id, mediaUrl: url, messageType: 'audio');
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل رفع الصوت'), backgroundColor: AppColors.error));
        }
      }
    } else {
      await repo.startRecording();
      setState(() => _isRecording = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        title: Row(children: [
          Stack(children: [
            CircleAvatar(backgroundImage: widget.otherUser.avatarUrl!= null? CachedNetworkImageProvider(widget.otherUser.avatarUrl!) : null, child: widget.otherUser.avatarUrl == null? const Icon(Icons.person) : null),
            if (widget.otherUser.isOnline) Positioned(bottom: 0, right: 0, child: Container(width: 12, height: 12, decoration: BoxDecoration(color: AppColors.online, shape: BoxShape.circle, border: Border.all(color: AppColors.card, width: 2)))),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.otherUser.name, style: const TextStyle(color: AppColors.textDark, fontSize: 16, fontWeight: FontWeight.bold)),
              StreamBuilder<bool>(
                stream: repo.getTypingStream(otherUserId: widget.otherUser.id),
                builder: (context, snapshot) {
                  if (snapshot.data == true) return const Text('يكتب...', style: TextStyle(color: AppColors.success, fontSize: 12));
                  if (widget.otherUser.isOnline) return const Text('نشط الآن', style: TextStyle(color: AppColors.online, fontSize: 12));
                  if (widget.otherUser.lastSeen!= null) return Text('آخر ظهور ${timeago.format(widget.otherUser.lastSeen!, locale: 'ar')}', style: const TextStyle(color: AppColors.textLight, fontSize: 11));
                  return const SizedBox();
                },
              ),
            ]),
          ),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: StreamBuilder<List<MessageModel>>(
            stream: repo.getPrivateMessagesStream(otherUserId: widget.otherUser.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final msgs = snapshot.data!;
              return ListView.builder(reverse: true, padding: const EdgeInsets.all(8), itemCount: msgs.length, itemBuilder: (context, i) => MessageBubble(msg: msgs[i]));
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: AppColors.card,
          child: SafeArea(
            child: Row(children: [
              IconButton(icon: Icon(_isRecording? Icons.stop_circle : Icons.mic, color: _isRecording? AppColors.error : AppColors.textLight), onPressed: _toggleRecording),
              IconButton(icon: const Icon(Icons.image, color: AppColors.textLight), onPressed: _sendImage),
              Expanded(
                child: TextField(
                  controller: _msgController,
                  onChanged: (_) => _onTyping(),
                  style: const TextStyle(color: AppColors.textDark),
                  decoration: InputDecoration(
                    hintText: 'اكتب رسالتك...',
                    hintStyle: const TextStyle(color: AppColors.textLight),
                    filled: true,
                    fillColor: AppColors.primaryBlue,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(backgroundColor: AppColors.button, child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _sendText)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  final String userId;
  final bool isMe;
  const ProfileScreen({required this.userId, this.isMe = false});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final u = await repo.getUserById(widget.userId);
    if (mounted) setState(() {
      user = u;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: AppColors.primaryBlue, body: Center(child: CircularProgressIndicator()));
    if (user == null) return const Scaffold(backgroundColor: AppColors.primaryBlue, body: Center(child: Text('المستخدم غير موجود', style: TextStyle(color: AppColors.textLight))));

    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        title: Text(user!.username?? user!.name, style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
        actions: [
          if (widget.isMe) IconButton(icon: const Icon(Icons.edit, color: AppColors.textDark), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())).then((_) => _loadUser())),
          if (widget.isMe) IconButton(icon: const Icon(Icons.logout, color: AppColors.error), onPressed: () => repo.signOut()),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(children: [
          const SizedBox(height: 20),
          Stack(children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.button,
              backgroundImage: user!.avatarUrl!= null? CachedNetworkImageProvider(user!.avatarUrl!) : null,
              child: user!.avatarUrl == null? const Icon(Icons.person, size: 50, color: Colors.white) : null,
            ),
            if (user!.isOnline) Positioned(bottom: 5, right: 5, child: Container(width: 16, height: 16, decoration: BoxDecoration(color: AppColors.online, shape: BoxShape.circle, border: Border.all(color: AppColors.primaryBlue, width: 3)))),
          ]),
          const SizedBox(height: 16),
          Text(user!.name, style: const TextStyle(color: AppColors.textDark, fontSize: 22, fontWeight: FontWeight.bold)),
          if (user!.username!= null) Text('@${user!.username}', style: const TextStyle(color: AppColors.textLight, fontSize: 14)),
          const SizedBox(height: 8),
          Text(user!.isOnline? 'نشط الآن' : user!.lastSeen!= null? 'آخر ظهور ${timeago.format(user!.lastSeen!, locale: 'ar')}' : 'غير متصل', style: TextStyle(color: user!.isOnline? AppColors.online : AppColors.textLight, fontSize: 13)),
          const SizedBox(height: 20),

          if (user!.bio!= null && user!.bio!.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
              child: Text(user!.bio!, style: const TextStyle(color: AppColors.textDark, fontSize: 14), textAlign: TextAlign.center),
            ),

          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(children: [
              if (!widget.isMe) Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PrivateChatScreen(otherUser: user!))),
                  icon: const Icon(Icons.message, size: 18),
                  label: const Text('مراسلة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.button,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  final bool isFirstTime;
  const EditProfileScreen({this.isFirstTime = false});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  String? _avatarUrl;
  bool _loading = false;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await repo.getCurrentUser();
    if (user!= null && mounted) {
      setState(() {
        _currentUser = user;
        _nameController.text = user.name;
        _usernameController.text = user.username?? '';
        _bioController.text = user.bio?? '';
        _avatarUrl = user.avatarUrl;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked!= null) {
      setState(() => _loading = true);
      try {
        final url = await repo.uploadAvatar(picked.path);
        setState(() => _avatarUrl = url);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل رفع الصورة'), backgroundColor: AppColors.error));
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteImage() async {
    setState(() => _loading = true);
    try {
      await repo.deleteAvatar();
      setState(() => _avatarUrl = null);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل حذف الصورة'), backgroundColor: AppColors.error));
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الاسم مطلوب'), backgroundColor: AppColors.error));
      return;
    }
    setState(() => _loading = true);
    try {
      await repo.updateProfile(
        name: _nameController.text.trim(),
        username: _usernameController.text.trim().isEmpty? null : _usernameController.text.trim(),
        bio: _bioController.text.trim().isEmpty? null : _bioController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        if (widget.isFirstTime) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthGate()));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل الحفظ'), backgroundColor: AppColors.error));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        title: Text(widget.isFirstTime? 'اكمل ملفك' : 'تعديل البروفايل', style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
        actions: [TextButton(onPressed: _loading? null : _save, child: const Text('حفظ', style: TextStyle(color: AppColors.button, fontSize: 16, fontWeight: FontWeight.bold)))],
      ),
      body: _loading? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Stack(alignment: Alignment.bottomRight, children: [
            CircleAvatar(
              radius: 55,
              backgroundColor: AppColors.button,
              backgroundImage: _avatarUrl!= null? CachedNetworkImageProvider(_avatarUrl!) : null,
              child: _avatarUrl == null? const Icon(Icons.person, size: 55, color: Colors.white) : null,
            ),
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.button,
              child: IconButton(padding: EdgeInsets.zero, icon: const Icon(Icons.camera_alt, color: Colors.white, size: 18), onPressed: _pickImage),
            ),
          ]),
          if (_avatarUrl!= null) TextButton(onPressed: _deleteImage, child: const Text('حذف الصورة', style: TextStyle(color: AppColors.error, fontSize: 13))),
          const SizedBox(height: 32),
          _buildField('الاسم', _nameController, Icons.person_outline),
          const SizedBox(height: 16),
          _buildField('اسم المستخدم', _usernameController, Icons.alternate_email, hint: 'بدون @'),
          const SizedBox(height: 16),
          _buildField('النبذة التعريفية', _bioController, Icons.info_outline, maxLines: 3),
        ]),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {int maxLines = 1, String? hint}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppColors.textLight, fontSize: 13)),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: AppColors.textDark, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.textLight.withOpacity(0.5)),
          prefixIcon: Icon(icon, color: AppColors.textLight, size: 20),
          filled: true,
          fillColor: AppColors.card,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    ]);
  }
}

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});
  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _loading = false;

  Future<void> _create() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await repo.createRoom(roomName: _nameController.text.trim(), description: _descController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم ارسال الطلب. بانتظار موافقة الادمن'), backgroundColor: AppColors.success));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل انشاء الغرفة'), backgroundColor: AppColors.error));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      appBar: AppBar(backgroundColor: AppColors.card, title: const Text('انشاء غرفة', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold))),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          _buildField('اسم الغرفة *', _nameController, Icons.meeting_room_outlined),
          const SizedBox(height: 16),
          _buildField('وصف الغرفة', _descController, Icons.description_outlined, maxLines: 3),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _loading? null : _create,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.button, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: _loading? const CircularProgressIndicator(color: Colors.white) : const Text('ارسال طلب', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.textDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textLight),
        prefixIcon: Icon(icon, color: AppColors.textLight),
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }
}
