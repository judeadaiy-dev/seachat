import 'dart:io';
import 'dart:ui';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'config/app_config.dart';
import 'data/supabase_repository.dart';
import 'models.dart';
import 'admin_panel.dart'; // استيراد اللوحة

class AppColors {
  static const Color backgroundStart = Color(0xFF81B7EC);
  static const Color backgroundEnd = Color(0xFF655B77);
  static const Color button = Color(0xFF443C50);
  static const Color icon = Color(0xFF968A98);
  static const Color cardGlass = Color(0x40FFFFFF);
  static const Color textDark = Color(0xFF1A1821);
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color officialWood = Color(0xFF1A1821);
  static const Color officialGold = Color(0xFF81B7EC);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey);
  runApp(const SeaChatApp());
}

class SeaChatApp extends StatelessWidget {
  const SeaChatApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Cairo', useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: AppColors.button)),
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          final session = snapshot.hasData? snapshot.data!.session : null;
          if (session!= null) {
            return FutureBuilder(
              future: Supabase.instance.client.from('profiles').select('is_banned').eq('id', session.user.id).maybeSingle(),
              builder: (context, banSnapshot) {
                if (banSnapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
                if (banSnapshot.data?['is_banned'] == true) {
                  Supabase.instance.client.auth.signOut();
                  return Scaffold(body: AppBackground(child: Center(child: GlassCard(margin: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.block, size: 60, color: Colors.red), const SizedBox(height: 16), const Text('تم حظر حسابك', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)), const SizedBox(height: 8), const Text('تواصل مع الإدارة لرفع الحظر', style: TextStyle(color: AppColors.textLight))])))));
                }
                return const MainScreen();
              },
            );
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}

class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.backgroundStart, AppColors.backgroundEnd])), child: child);
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.borderRadius = 24, this.onTap, this.margin});
  @override
  Widget build(BuildContext context) {
    return Container(margin: margin, child: ClipRRect(borderRadius: BorderRadius.circular(borderRadius), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), child: Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(borderRadius), child: Container(padding: padding, decoration: BoxDecoration(color: AppColors.cardGlass, borderRadius: BorderRadius.circular(borderRadius), border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5)), child: child))))));
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passController = TextEditingController();
  final repo = SupabaseRepository();
  bool isLoading = false;
  @override
  void dispose() {
    emailController.dispose();
    passController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(hintText: hint, prefixIcon: Icon(icon, color: AppColors.icon), filled: true, fillColor: Colors.white.withOpacity(0.5), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none));
  }

  Future<void> _handleLogin() async {
    if (emailController.text.trim().isEmpty || passController.text.trim().isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('املأ البريد وكلمة المرور')));
      return;
    }
    setState(() => isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(email: emailController.text.trim(), password: passController.text);
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل تسجيل الدخول: ${e.message}')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _handleSignUp() async {
    if (emailController.text.trim().isEmpty || passController.text.trim().isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('املأ البريد وكلمة المرور')));
      return;
    }
    setState(() => isLoading = true);
    try {
      final res = await Supabase.instance.client.auth.signUp(email: emailController.text.trim(), password: passController.text);
      if (res.user!= null && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء الحساب بنجاح')));
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل إنشاء الحساب: ${e.message}')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: AppBackground(child: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: GlassCard(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.waves_rounded, size: 60, color: AppColors.button), const SizedBox(height: 12), const Text(AppConfig.appName, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.button)), const SizedBox(height: 32), TextField(controller: emailController, keyboardType: TextInputType.emailAddress, decoration: _inputDecoration('البريد الإلكتروني', Icons.email_outlined)), const SizedBox(height: 16), TextField(controller: passController, obscureText: true, decoration: _inputDecoration('كلمة المرور', Icons.lock_outline)), const SizedBox(height: 24), Row(children: [Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.button, minimumSize: const Size(0, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), onPressed: isLoading? null : _handleLogin, child: isLoading? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('تسجيل الدخول', style: TextStyle(fontSize: 16, color: Colors.white)))), const SizedBox(width: 12), Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.button), minimumSize: const Size(0, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), onPressed: isLoading? null : _handleSignUp, child: const Text('حساب جديد', style: TextStyle(fontSize: 16, color: AppColors.button))))]), const SizedBox(height: 12), SizedBox(width: double.infinity, height: 50, child: OutlinedButton.icon(style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.button), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), onPressed: () async => await repo.signInWithGoogle(), icon: const Icon(Icons.g_mobiledata_rounded, color: AppColors.button, size: 28), label: const Text('المتابعة عبر Google', style: TextStyle(color: AppColors.button))))])))))));
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int currentIndex = 0;
  final screens = const [HomeScreen(), ProfileScreen()];
  @override
  Widget build(BuildContext context) {
    return Scaffold(extendBody: true, drawer: const AppDrawer(), body: AppBackground(child: screens[currentIndex]), bottomNavigationBar: Padding(padding: const EdgeInsets.all(16), child: GlassCard(padding: const EdgeInsets.symmetric(vertical: 8), borderRadius: 20, child: BottomNavigationBar(currentIndex: currentIndex, onTap: (i) => setState(() => currentIndex = i), backgroundColor: Colors.transparent, elevation: 0, selectedItemColor: AppColors.button, unselectedItemColor: AppColors.icon, items: const [BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'الرئيسية'), BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'الملف الشخصي')]))));
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = SupabaseRepository();
    return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('الغرف'), leading: Builder(builder: (context) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(context).openDrawer()))),
        body: StreamBuilder<List<RoomModel>>(
            stream: repo.getRoomsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.button));
              if (snapshot.hasError) return Center(child: Text('خطأ: ${snapshot.error}'));
              final rooms = snapshot.data?? [];
              if (rooms.isEmpty) return const Center(child: Text('لا توجد غرف حالياً'));
              return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: rooms.length,
                  itemBuilder: (context, i) {
                    final room = rooms[i];
                    final isOfficial = room.roomType == 'official';
                    return Padding(padding: const EdgeInsets.only(bottom: 12), child: isOfficial? buildOfficialRoomCard(context, room) : buildUserRoomCard(context, room));
                  });
            }));
  }

  Widget buildOfficialRoomCard(BuildContext context, RoomModel room) {
    return GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(room: room))),
        child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(colors: [Color(0xFF2C1810), Color(0xFF4A3728), Color(0xFF6B4F3A)], begin: Alignment.topLeft, end: Alignment.bottomRight), boxShadow: [BoxShadow(color: AppColors.officialGold.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))], border: Border.all(color: AppColors.officialGold.withOpacity(0.6), width: 2)),
            child: Stack(children: [
              Positioned(right: -30, top: -30, child: Icon(Icons.account_balance, size: 120, color: Colors.white.withOpacity(0.03))),
              Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(children: [
                    Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.officialGold.withOpacity(0.15), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.officialGold, width: 1.5)), child: const Icon(Icons.verified, size: 32, color: AppColors.officialGold)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [Text(room.roomName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)), const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: AppColors.officialGold, borderRadius: BorderRadius.circular(8)), child: const Text('رسمية', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.officialWood)))]),
                      const SizedBox(height: 6),
                      Text(room.description?? 'الغرفة الرسمية - أهلاً بالجميع', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13))
                    ])),
                    const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.officialGold)
                  ]))
            ])));
  }

  Widget buildUserRoomCard(BuildContext context, RoomModel room) {
    return GlassCard(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(room: room))), child: ListTile(leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.button, AppColors.button.withOpacity(0.7)]), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.groups_2_rounded, color: Colors.white)), title: Text(room.roomName, style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: Text(room.description?? 'غرفة جماعية', style: const TextStyle(fontSize: 12, color: AppColors.textLight)), trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.icon)));
  }
}

class ChatScreen extends StatefulWidget {
  final RoomModel room;
  const ChatScreen({super.key, required this.room});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final repo = SupabaseRepository();
  final msgController = TextEditingController();
  final supabase = Supabase.instance.client;
  final _record = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  bool isRecording = false;
  bool isOwner = false;
  bool isJoined = false;
  String? currentUserRole;
  String? currentUserId;
  bool isAdmin = false;
  @override
  void initState() {
    super.initState();
    final user = supabase.auth.currentUser;
    if (user == null) {
      Navigator.pop(context);
      return;
    }
    currentUserId = user.id;
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final isOfficial = widget.room.roomType == 'official';
    final userProfile = await supabase.from('profiles').select('role').eq('id', currentUserId!).maybeSingle();
    isAdmin = userProfile?['role'] == 'admin';
    if (isOfficial) {
      isOwner = isAdmin;
      final member = await supabase.from('room_members').select().eq('room_id', widget.room.id).eq('user_id', currentUserId!).maybeSingle();
      isJoined = member!= null;
    } else {
      final member = await supabase.from('room_members').select('role').eq('room_id', widget.room.id).eq('user_id', currentUserId!).maybeSingle();
      currentUserRole = member?['role'];
      isOwner = member?['role'] == 'owner';
      isJoined = member!= null;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    msgController.dispose();
    _record.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = msgController.text.trim();
    if (text.isEmpty) return;
    await repo.sendMessage(roomId: widget.room.id, message: text);
    msgController.clear();
    if (!isOwner && widget.room.roomType!= 'official' &&!text.startsWith('[VOICE]')) {
      await supabase.rpc('increment_points', params: {'room_id': widget.room.id, 'user_id': currentUserId});
    }
  }

  Future<void> _startRecording() async {
    try {
      if (!await _record.hasPermission()) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يوجد اذن للمايك')));
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice.m4a';
      await _record.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      setState(() => isRecording = true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ بالتسجيل: $e')));
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _record.stop();
      setState(() => isRecording = false);
      if (path!= null) {
        final file = File(path);
        final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await supabase.storage.from('voices').upload(fileName, file);
        final url = supabase.storage.from('voices').getPublicUrl(fileName);
        await repo.sendMessage(roomId: widget.room.id, message: '[VOICE]$url');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ برفع الصوت: $e')));
    }
  }

  Future<void> _joinRoom() async {
    await repo.joinRoom(widget.room.id);
    setState(() => isJoined = true);
  }

  Future<void> _leaveRoom() async {
    await repo.leaveRoom(widget.room.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _copyInviteLink() async {
    final link = 'https://seachat.app/room/${widget.room.id}';
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ رابط الدعوة')));
  }

  Future<void> _deleteRoom() async {
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('حذف الغرفة'), content: const Text('هل أنت متأكد؟ سيتم حذف جميع الرسائل'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف', style: TextStyle(color: Colors.red)))]));
    if (confirm == true) {
      await repo.deleteRoom(widget.room.id);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _showMembers() {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
            decoration: const BoxDecoration(color: AppColors.backgroundEnd, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.icon, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('أعضاء الغرفة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                  child: FutureBuilder<List<RoomMemberModel>>(
                      future: repo.getRoomMembers(widget.room.id),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        final members = snapshot.data!;
                        return ListView.builder(
                            itemCount: members.length,
                            itemBuilder: (context, i) {
                              final member = members[i];
                              final rank = i < 3? ['🥇', '🥈', '🥉'][i] : '${i + 1}';
                              return ListTile(
                                  leading: Stack(children: [CircleAvatar(backgroundImage: member.user?.avatarUrl!= null? NetworkImage(member.user!.avatarUrl!) : null, child: member.user?.avatarUrl == null? Text(member.user?.name[0]?? 'U') : null), if (i < 3) Positioned(right: -2, bottom: -2, child: Text(rank, style: const TextStyle(fontSize: 16)))]),
                                  title: Text(member.user?.name?? 'مستخدم'),
                                  subtitle: Text('نقاط: ${member.points} | ${member.role == 'owner'? 'المشرف' : 'عضو'}'),
                                  trailing: isOwner && member.role!= 'owner'
                                   ? PopupMenuButton<String>(
                                          onSelected: (value) {
                                            if (value == 'ban') _banMember(member.userId);
                                            if (value == 'kick') _kickMember(member.userId);
                                          },
                                          itemBuilder: (context) => [
                                            const PopupMenuItem(value: 'ban', child: Text('حظر')),
                                            const PopupMenuItem(value: 'kick', child: Text('إزالة')),
                                          ],
                                        )
                                      : null);
                            });
                      }))
            ])));
  }

  Future<void> _banMember(String userId) async {
    await repo.banUser(userId);
    await repo.kickMember(widget.room.id, userId);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حظر العضو من التطبيق')));
  }

  Future<void> _kickMember(String userId) async {
    await repo.kickMember(widget.room.id, userId);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إزالة العضو')));
  }

  @override
  Widget build(BuildContext context) {
    final isOfficial = widget.room.roomType == 'official';
    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(backgroundColor: Colors.transparent, title: Text(widget.room.roomName), actions: [
          if (!isOfficial && isOwner) PopupMenuButton(icon: const Icon(Icons.more_vert), itemBuilder: (context) => [PopupMenuItem(child: const Text('عرض الأعضاء'), onTap: () => _showMembers()), PopupMenuItem(child: const Text('نسخ رابط الدعوة'), onTap: () => _copyInviteLink()), PopupMenuItem(child: const Text('حذف الغرفة', style: TextStyle(color: Colors.red)), onTap: () => _deleteRoom())]),
          if (!isJoined) TextButton(onPressed: _joinRoom, child: const Text('دخول', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          if (isJoined && (widget.room.roomType!= 'official' ||!isAdmin)) TextButton(onPressed: _leaveRoom, child: const Text('خروج', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
        ]),
        body: AppBackground(
            child: Column(children: [
          Expanded(
              child: StreamBuilder<List<MessageModel>>(
                  stream: repo.getRoomMessagesStream(roomId: widget.room.id),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final messages = snapshot.data!;
                    return ListView.builder(padding: const EdgeInsets.fromLTRB(16, 100, 16), reverse: true, itemCount: messages.length, itemBuilder: (context, i) => _buildMessage(messages[i]));
                  })),
          if (isJoined || (isOfficial && isAdmin)) _buildInputBar()
        ])));
  }

  Widget _buildMessage(MessageModel msg) {
    if (msg.text.startsWith('[VOICE]')) {
      final url = msg.text.replaceFirst('[VOICE]', '');
      return Align(alignment: msg.isMe? Alignment.centerLeft : Alignment.centerRight, child: GlassCard(margin: const EdgeInsets.only(bottom: 8), child: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.play_arrow), onPressed: () => _audioPlayer.setUrl(url).then((_) => _audioPlayer.play())), Text('رسالة صوتية', style: TextStyle(color: msg.isMe? Colors.white : AppColors.textDark))])));
    }
    return Align(alignment: msg.isMe? Alignment.centerLeft : Alignment.centerRight, child: GlassCard(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Text(msg.text, style: TextStyle(color: msg.isMe? Colors.white : AppColors.textDark))));
  }

  Widget _buildInputBar() {
    return Padding(padding: const EdgeInsets.all(16), child: GlassCard(padding: const EdgeInsets.symmetric(horizontal: 8), child: Row(children: [IconButton(onPressed: isRecording? _stopRecording : _startRecording, icon: Icon(isRecording? Icons.stop_circle : Icons.mic, color: isRecording? Colors.red : AppColors.icon)), Expanded(child: TextField(controller: msgController, decoration: const InputDecoration(hintText: 'اكتب رسالة...', border: InputBorder.none), onSubmitted: (_) => _sendMessage())), IconButton(onPressed: _sendMessage, icon: const Icon(Icons.send_rounded, color: AppColors.button))])));
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = SupabaseRepository();
    return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('الملف الشخصي')),
        body: FutureBuilder<UserModel?>(
            future: repo.getCurrentUser(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData) return const Center(child: Text('المستخدم غير موجود'));
              final user = snapshot.data!;
              return ListView(padding: const EdgeInsets.all(16), children: [GlassCard(child: Column(children: [CircleAvatar(radius: 50, backgroundColor: AppColors.button, backgroundImage: user.avatarUrl!= null? NetworkImage(user.avatarUrl!) : null, child: user.avatarUrl == null? Text(user.name.isNotEmpty? user.name[0] : 'U', style: const TextStyle(fontSize: 40, color: Colors.white)) : null), const SizedBox(height: 16), Text(user.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), Text(user.email, style: const TextStyle(color: AppColors.textLight))])), const SizedBox(height: 16), GlassCard(onTap: () async => await Supabase.instance.client.auth.signOut(), child: const ListTile(leading: Icon(Icons.logout, color: Colors.red), title: Text('تسجيل الخروج', style: TextStyle(color: Colors.red))))]);
            }));
  }
}

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});
  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  bool isAdmin = false;
  late AnimationController _animationController;
  late Animation<double> _animation;
  @override
  void initState() {
    super.initState();
    _checkAdmin();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkAdmin() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final res = await supabase.from('profiles').select('role').eq('id', user.id).maybeSingle();
    if (mounted) setState(() => isAdmin = res?['role'] == 'admin');
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
        backgroundColor: Colors.transparent,
        child: AppBackground(
            child: ListView(padding: EdgeInsets.zero, children: [
          DrawerHeader(
              child: GlassCard(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            GestureDetector(
                onTap: () {
                  if (_animationController.isCompleted) {
                    _animationController.reverse();
                  } else {
                    _animationController.forward();
                  }
                  Scaffold.of(context).closeDrawer();
                },
                child: AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) => Column(mainAxisSize: MainAxisSize.min, children: [
                          Transform.rotate(angle: _animation.value * 0.785, child: Container(width: 30, height: 3, decoration: BoxDecoration(color: AppColors.button, borderRadius: BorderRadius.circular(2)))),
                          SizedBox(height: _animation.value * 8 + 6),
                          Transform.rotate(angle: -_animation.value * 0.785, child: Container(width: 30, height: 3, decoration: BoxDecoration(color: AppColors.button, borderRadius: BorderRadius.circular(2))))
                        ]))),
            const SizedBox(height: 12),
            const Text(AppConfig.appName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.button))
          ]))),
          if (isAdmin) ListTile(leading: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.button), title: const Text('لوحة التحكم', style: TextStyle(fontWeight: FontWeight.bold)), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanel()))),
          ListTile(leading: const Icon(Icons.add_home_work_outlined, color: AppColors.icon), title: const Text('طلب إنشاء غرفة'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateRoomRequestScreen()))),
          ListTile(leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.icon), title: const Text('سياسة الخصوصية'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()))),
          ListTile(leading: const Icon(Icons.mail_outline_rounded, color: AppColors.icon), title: const Text('تواصل معنا'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactUsScreen()))),
          const Divider(),
          Padding(padding: const EdgeInsets.all(16), child: Text('© ${AppConfig.copyrightYear} ${AppConfig.copyrightName}. All rights reserved.', style: const TextStyle(color: AppColors.textLight, fontSize: 12), textAlign: TextAlign.center))
        ])));
  }
}

class CreateRoomRequestScreen extends StatelessWidget {
  const CreateRoomRequestScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طلب إنشاء غرفة')),
      body: AppBackground(
        child: Center(
          child: GlassCard(
            margin: const EdgeInsets.all(24),
            child: const Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.construction, size: 60, color: AppColors.button),
              SizedBox(height: 16),
              Text('قريباً', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('هذه الميزة قيد التطوير', style: TextStyle(color: AppColors.textLight))
            ]),
          ),
        ),
      ),
    );
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سياسة الخصوصية')),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('سياسة الخصوصية', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Text('نحن نحترم خصوصيتك ونلتزم بحماية بياناتك الشخصية. يتم تشفير جميع الرسائل والصوتيات. لا نشارك بياناتك مع طرف ثالث.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تواصل معنا')),
      body: AppBackground(
        child: Center(
          child: GlassCard(
            margin: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.email_rounded, size: 60, color: AppColors.button),
                const SizedBox(height: 16),
                const Text('تواصل معنا', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('support@seachat.app', style: TextStyle(fontSize: 18, color: AppColors.button)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Clipboard.setData(const ClipboardData(text: 'support@seachat.app')),
                  child: const Text('نسخ البريد'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
