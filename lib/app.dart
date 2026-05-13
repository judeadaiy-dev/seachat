import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:io';
import 'main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ==================== MyApp ====================
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sea Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Cairo',
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.button, brightness: Brightness.dark),
        scaffoldBackgroundColor: AppColors.primaryBlue,
      ),
      home: const WelcomeScreen(),
    );
  }
}

// ==================== صفحة ترحيبية خورافية ====================
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () {
      if (Supabase.instance.client.auth.currentUser!= null && mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthGate()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryBlue, Color(0xFF1E1B4B), AppColors.button],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppColors.button.withOpacity(0.5), blurRadius: 30, spreadRadius: 10)],
                      ),
                      child: const Icon(Icons.waves_rounded, size: 100, color: Colors.white),
                    ),
                    const SizedBox(height: 40),
                    const Text('Sea Chat', style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
                    const SizedBox(height: 12),
                    Text('تواصل بلا حدود', style: TextStyle(fontSize: 18, color: AppColors.textLight.withOpacity(0.8))),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthGate())),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.button,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 8,
                        ),
                        child: const Text('ابدأ الآن', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// ==================== AuthGate ====================
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    repo.updateOnlineStatus(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    repo.updateOnlineStatus(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) repo.updateOnlineStatus(true);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) repo.updateOnlineStatus(false);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(backgroundColor: AppColors.primaryBlue, body: Center(child: CircularProgressIndicator()));
        }
        final session = snapshot.data?.session;
        if (session == null) return const AuthScreen();
        return FutureBuilder<UserModel?>(
          future: repo.getCurrentUser(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(backgroundColor: AppColors.primaryBlue, body: Center(child: CircularProgressIndicator()));
            }
            final user = userSnapshot.data;
            if (user == null) return const EditProfileScreen(isFirstTime: true);
            if (user.isBanned) return const BannedScreen();
            return HomeScreen(currentUser: user);
          },
        );
      },
    );
  }
}

// ==================== تسجيل إيميل وباسورد فقط ====================
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _isLogin = true;

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      if (_isLogin) {
        await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        final res = await Supabase.instance.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        if (res.user!= null) {
          await Supabase.instance.client.from('profiles').insert({
            'id': res.user!.id,
            'email': res.user!.email,
            'name': res.user!.email!.split('@')[0],
          });
        }
      }
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.primaryBlue, AppColors.card]),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_rounded, size: 70, color: AppColors.button),
                  const SizedBox(height: 16),
                  Text(_isLogin? 'تسجيل الدخول' : 'حساب جديد', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 40),
                  _buildTextField(_emailController, 'الايميل', Icons.email_outlined),
                  const SizedBox(height: 16),
                  _buildTextField(_passwordController, 'كلمة السر', Icons.lock_outline, isPassword: true),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _loading? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.button,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _loading? const CircularProgressIndicator(color: Colors.white) : Text(_isLogin? 'دخول' : 'تسجيل', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => setState(() => _isLogin =!_isLogin),
                    child: Text(_isLogin? 'ماعندك حساب؟ سجل الآن' : 'عندك حساب؟ سجل دخول', style: const TextStyle(color: AppColors.textLight)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: AppColors.textDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textLight),
        prefixIcon: Icon(icon, color: AppColors.textLight),
        filled: true,
        fillColor: AppColors.primaryBlue.withOpacity(0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }
}

// ==================== HomeScreen ====================
class HomeScreen extends StatefulWidget {
  final UserModel currentUser;
  const HomeScreen({super.key, required this.currentUser});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        title: const Text('Sea Chat', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.settings, color: AppColors.textDark), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: widget.currentUser.id, isMe: true)))),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.button,
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: AppColors.button,
          tabs: const [Tab(text: 'غرفتي'), Tab(text: 'المجتمع')],
        ),
      ),
      body: TabBarView(controller: _tabController, children: [MyRoomsTab(), PublicRoomsTab()]),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.button,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateRoomScreen())),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class MyRoomsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RoomModel>>(
      future: repo.getMyRooms(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final rooms = snapshot.data!;
        if (rooms.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.meeting_room_outlined, size: 80, color: AppColors.textLight.withOpacity(0.3)), const SizedBox(height: 16), const Text('لم تنشئ أي غرفة بعد', style: TextStyle(color: AppColors.textLight))]));
        return ListView.builder(padding: const EdgeInsets.only(top: 8), itemCount: rooms.length, itemBuilder: (context, i) => RoomTile(room: rooms[i]));
      },
    );
  }
}

class PublicRoomsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RoomModel>>(
      future: repo.getPublicRooms(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final rooms = snapshot.data!;
        if (rooms.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.public_off, size: 80, color: AppColors.textLight.withOpacity(0.3)), const SizedBox(height: 16), const Text('لا توجد غرف عامة', style: TextStyle(color: AppColors.textLight))]));
        return ListView.builder(padding: const EdgeInsets.only(top: 8), itemCount: rooms.length, itemBuilder: (context, i) => RoomTile(room: rooms[i]));
      },
    );
  }
}

class RoomTile extends StatelessWidget {
  final RoomModel room;
  const RoomTile({required this.room});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(radius: 28, backgroundImage: room.imageUrl!= null? CachedNetworkImageProvider(room.imageUrl!) : null, backgroundColor: AppColors.button, child: room.imageUrl == null? const Icon(Icons.group, color: Colors.white) : null),
        title: Row(children: [
          Expanded(child: Text(room.roomName, style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 16))),
          if (!room.isApproved) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(6)), child: const Text('قيد المراجعة', style: TextStyle(color: Colors.white, fontSize: 10))),
        ]),
        subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text(room.description?? 'لا يوجد وصف', style: const TextStyle(color: AppColors.textLight, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(room: room))),
      ),
    );
  }
}
// ==================== ChatScreen مع إرسال صور وصوت ====================
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

// ==================== MessageBubble يدعم صور وصوت ====================
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

// ==================== مشغل الصوت ====================
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

// ==================== دردشة خاصة مع صور وصوت ====================
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
                  label:
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

// ==================== تعديل البروفايل ستايل انستا ====================
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

// ==================== إنشاء غرفة ====================
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

// ==================== شاشة الحظر ====================
class BannedScreen extends StatelessWidget {
  const BannedScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.block, size: 100, color: AppColors.error),
            const SizedBox(height: 24),
            const Text('تم حظر حسابك', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            const SizedBox(height: 8),
            const Text('تواصل مع الادارة لمعرفة السبب', style: TextStyle(color: AppColors.textLight)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => repo.signOut(),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.button, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('تسجيل خروج', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ]),
        ),
      ),
    );
  }
}
          
