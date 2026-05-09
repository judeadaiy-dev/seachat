import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'config/app_config.dart';
import 'data/supabase_repository.dart';
import 'models.dart';

class AppColors {
  static const Color backgroundStart = Color(0xFFCAD5D4);
  static const Color backgroundEnd = Color(0xFFE8EFEE);
  static const Color button = Color(0xFF482855);
  static const Color icon = Color(0xFF898199);
  static const Color cardGlass = Color(0xB3FFFFFF);
  static const Color textDark = Color(0xFF2D2D2D);
  static const Color textLight = Color(0xFF6B6B6B);
  static const Color officialWood = Color(0xFF3D2B1F);
  static const Color officialGold = Color(0xFFD4AF37);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  runApp(const SeaChatApp());
}

class SeaChatApp extends StatelessWidget {
  const SeaChatApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Cairo',
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.button),
      ),
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final session = snapshot.hasData? snapshot.data!.session : null;
          if (session!= null) {
            return FutureBuilder(
              future: Supabase.instance.client.from('profiles').select('is_banned').eq('id', session.user.id).maybeSingle(),
              builder: (context, banSnapshot) {
                if (banSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }
                if (banSnapshot.data?['is_banned'] == true) {
                  Supabase.instance.client.auth.signOut();
                  return Scaffold(
                    body: AppBackground(
                      child: Center(
                        child: GlassCard(
                          margin: EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.block, size: 60, color: Colors.red),
                              SizedBox(height: 16),
                              Text('تم حظر حسابك', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)),
                              SizedBox(height: 8),
                              Text('تواصل مع الإدارة لرفع الحظر', style: TextStyle(color: AppColors.textLight)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.backgroundStart, AppColors.backgroundEnd],
        ),
      ),
      child: child,
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.borderRadius = 24, this.onTap, this.margin});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(borderRadius),
              child: Container(
                padding: padding,
                decoration: BoxDecoration(
                  color: AppColors.cardGlass,
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
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
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.icon),
      filled: true,
      fillColor: Colors.white.withOpacity(0.5),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    );
  }

  Future<void> _handleLogin() async {
    if (emailController.text.trim().isEmpty || passController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('املأ البريد وكلمة المرور')));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('املأ البريد وكلمة المرور')));
      return;
    }
    setState(() => isLoading = true);
    try {
      final res = await Supabase.instance.client.auth.signUp(email: emailController.text.trim(), password: passController.text);
      if (res.user!= null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء الحساب بنجاح')));
      }
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
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: GlassCard(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.waves_rounded, size: 60, color: AppColors.button),
                    const SizedBox(height: 12),
                    const Text(AppConfig.appName, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.button)),
                    const SizedBox(height: 32),
                    TextField(controller: emailController, keyboardType: TextInputType.emailAddress, decoration: _inputDecoration('البريد الإلكتروني', Icons.email_outlined)),
                    const SizedBox(height: 16),
                    TextField(controller: passController, obscureText: true, decoration: _inputDecoration('كلمة المرور', Icons.lock_outline)),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.button, minimumSize: const Size(0, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                            onPressed: isLoading? null : _handleLogin,
                            child: isLoading? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('تسجيل الدخول', style: TextStyle(fontSize: 16, color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.button), minimumSize: const Size(0, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                            onPressed: isLoading? null : _handleSignUp,
                            child: const Text('حساب جديد', style: TextStyle(fontSize: 16, color: AppColors.button)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.button), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        onPressed: () async => await repo.signInWithGoogle(),
                        icon: const Icon(Icons.g_mobiledata_rounded, color: AppColors.button, size: 28),
                        label: const Text('المتابعة عبر Google', style: TextStyle(color: AppColors.button)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
    return Scaffold(
      extendBody: true,
      drawer: const AppDrawer(),
      body: AppBackground(child: screens[currentIndex]),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          borderRadius: 20,
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: (i) => setState(() => currentIndex = i),
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: AppColors.button,
            unselectedItemColor: AppColors.icon,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'الرئيسية'),
              BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'الملف الشخصي'),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('الغرف'),
        leading: Builder(builder: (context) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(context).openDrawer())),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client.from('rooms').stream(primaryKey: ['id']).order('is_pinned', ascending: false).order('created_at'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.button));
          }
          if (snapshot.hasError) return Center(child: Text('خطأ: ${snapshot.error}'));
          final rooms = snapshot.data?.map((r) => RoomModel.fromJson(r)).toList()?? [];
          if (rooms.isEmpty) return const Center(child: Text('لا توجد غرف حالياً'));
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: rooms.length,
            itemBuilder: (context, i) {
              final room = rooms[i];
              final isOfficial = room.roomType == 'official';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: isOfficial? _buildOfficialRoomCard(context, room) : _buildUserRoomCard(context, room),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildOfficialRoomCard(BuildContext context, RoomModel room) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(room: room))),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [Color(0xFF2C1810), Color(0xFF4A3728), Color(0xFF6B4F3A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [BoxShadow(color: AppColors.officialGold.withOpacity(0.4), blurRadius: 20, offset: Offset(0, 8))],
          border: Border.all(color: AppColors.officialGold.withOpacity(0.6), width: 2),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Icon(Icons.account_balance, size: 120, color: Colors.white.withOpacity(0.03)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.officialGold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.officialGold, width: 1.5),
                    ),
                    child: Icon(Icons.verified, size: 32, color: AppColors.officialGold),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(room.roomName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(color: AppColors.officialGold, borderRadius: BorderRadius.circular(8)),
                              child: Text('رسمية', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.officialWood)),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(room.description?? 'الغرفة الرسمية - أهلاً بالجميع', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.officialGold),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserRoomCard(BuildContext context, RoomModel room) {
    return GlassCard(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(room: room))),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.button, AppColors.button.withOpacity(0.7)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.groups_2_rounded, color: Colors.white),
        ),
        title: Text(room.roomName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(room.description?? 'غرفة جماعية', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.icon),
      ),
    );
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
    currentUserId = supabase.auth.currentUser!.id;
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
    if (msgController.text.trim().isEmpty) return;
    await repo.sendMessage(roomId: widget.room.id, message: msgController.text);
    msgController.clear();
    if (!isOwner && widget.room.roomType!= 'official') {
      await supabase.rpc('increment_points', params: {'room_id': widget.room.id, 'user_id': currentUserId});
    }
  }

  Future<void> _startRecording() async {
    if (await _record.hasPermission()) {
      await _record.start(const RecordConfig(), path: '/tmp/voice.m4a');
      setState(() => isRecording = true);
    }
  }

  Future<void> _stopRecording() async {
    final path = await _record.stop();
    setState(() => isRecording = false);
    if (path!= null) {
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await supabase.storage.from('voices').upload(fileName, File(path));
      final url = supabase.storage.from('voices').getPublicUrl(fileName);
      await repo.sendMessage(roomId: widget.room.id, message: '[VOICE]$url');
    }
  }

  Future<void> _joinRoom() async {
    await supabase.from('room_members').insert({
      'room_id': widget.room.id,
      'user_id': currentUserId!,
      'role': 'member'
    });
    setState(() => isJoined = true);
  }

  Future<void> _leaveRoom() async {
    await supabase.from('room_members').delete().eq('room_id', widget.room.id).eq('user_id', currentUserId!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isOfficial = widget.room.roomType == 'official';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(widget.room.roomName),
        actions: [
          if (!isOfficial && isOwner)
            PopupMenuButton(
              icon: Icon(Icons.more_vert),
              itemBuilder: (context) => [
                PopupMenuItem(child: Text('عرض الأعضاء'), onTap: () => _showMembers()),
                PopupMenuItem(child: Text('نسخ رابط الدعوة'), onTap: () => _copyInviteLink()),
                PopupMenuItem(child: Text('حذف الغرفة', style: TextStyle(color: Colors.red)), onTap: () => _deleteRoom()),
              ],
            ),
          if (!isJoined)
            TextButton(
              onPressed: _joinRoom,
              child: Text('دخول', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          if (isJoined && (widget.room.roomType!= 'official' ||!isAdmin))
            TextButton(
              onPressed: _leaveRoom,
              child: Text('خروج', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: AppBackground(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<MessageModel>>(
                stream: repo.getRoomMessagesStream(roomId: widget.room.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final messages = snapshot.data!;
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
                    reverse: true,
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final msg = messages[i];
                      return _buildMessage(msg);
                    },
                  );
                },
              ),
            ),
            if (isJoined || isOfficial && isAdmin) _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(MessageModel msg) {
    if (msg.text.startsWith('[VOICE]')) {
      final url = msg.text.replaceFirst('[VOICE]', '');
      return Align(
        alignment: msg.isMe? Alignment.centerLeft : Alignment.centerRight,
        child: GlassCard(
          margin: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(icon: Icon(Icons.play_arrow), onPressed: () => _audioPlayer.setUrl(url).then((_) => _audioPlayer.play())),
              Text('رسالة صوتية', style: TextStyle(color: msg.isMe? Colors.white : AppColors.textDark)),
            ],
          ),
        ),
      );
    }
    return Align(
      alignment: msg.isMe? Alignment.centerLeft : Alignment.centerRight,
      child: GlassCard(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text(msg.text, style: TextStyle(color: msg.isMe? Colors.white : AppColors.textDark)),
      ),
    );
  }

  Widget _buildInputBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            IconButton(
              onPressed: isRecording? _stopRecording : _startRecording,
              icon: Icon(isRecording? Icons.stop_circle : Icons.mic, color: isRecording? Colors.red : AppColors.icon),
            ),
            Expanded(child: TextField(controller: msgController, decoration: const InputDecoration(hintText: 'اكتب رسالة...', border: InputBorder.none), onSubmitted: (_) => _sendMessage())),
            IconButton(onPressed: _sendMessage, icon: const Icon(Icons.send_rounded, color: AppColors.button)),
          ],
        ),
      ),
    );
  }

  void _showMembers() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundEnd,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.icon, borderRadius: BorderRadius.circular(2))),
            SizedBox(height: 16),
            Text('أعضاء الغرفة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: supabase.from('room_members').stream(primaryKey: ['id']).eq('room_id', widget.room.id).order('points', ascending: false),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, i) {
                      final member = snapshot.data![i];
                      return FutureBuilder(
                        future: supabase.from('profiles').select('username, avatar_url').eq('id', member['user_id']).single(),
                        builder: (context, userSnap) {
                          if (!userSnap.hasData) return SizedBox();
                          final user = userSnap.data!;
                          final rank = i < 3? ['🥇','🥈','🥉'][i] : '${i+1}';
                          return ListTile(
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  backgroundImage: user['avatar_url']!= null? NetworkImage(user['avatar_url']) : null,
                                  child: user['avatar_url'] == null? Text(user['username'][0]) : null,
                                ),
                                if (i < 3) Positioned(right: -2, bottom: -2, child: Text(rank, style: TextStyle(fontSize: 16))),
                              ],
                            ),
                            title: Text(user['username']),
                            subtitle: Text('نقاط: ${member['points']} | ${member['role'] == 'owner'? 'المشرف' : 'عضو'}'),
                            trailing: isOwner && member['role']!= 'owner'
                       ? PopupMenuButton(
                                itemBuilder: (context) => [
                                  PopupMenuItem(child: Text('حظر'), onTap: () => _banMember(member['user_id'])),
                                  PopupMenuItem(child: Text('إزالة'), onTap: () => _kickMember(member['user_id'])),
                                ],
                              )
                              : null,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _banMember(String userId) async {
    await supabase.from('room_members').delete().eq('room_id', widget.room.id).eq('user_id', userId);
    await supabase.from('profiles').update({'is_banned': true}).eq('id', userId);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حظر العضو من التطبيق')));
  }

  Future<void> _kickMember(String userId) async {
    await supabase.from('room_members').delete().eq('room_id', widget.room.id).eq('user_id', userId);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إزالة العضو')));
  }

  Future<void> _deleteRoom() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('حذف الغرفة'),
        content: Text('هل أنت متأكد؟ سيتم حذف جميع الرسائل'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await supabase.from('rooms').delete().eq('id', widget.room.id);
      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
      }
    }
  }

  void _copyInviteLink() {
    final link = 'https://seachat.app/room/${widget.room.id}';
    Clipboard.setData(ClipboardData(text: link));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم نسخ رابط الدعوة')));
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
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GlassCard(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.button,
                      backgroundImage: user.avatarUrl!= null? NetworkImage(user.avatarUrl!) : null,
                      child: user.avatarUrl == null? Text(user.name.isNotEmpty? user.name[0] : 'U', style: const TextStyle(fontSize: 40, color: Colors.white)) : null,
                    ),
                    const SizedBox(height: 16),
                    Text(user.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(user.email, style: const TextStyle(color: AppColors.textLight)),
                  ],
                ),
              const SizedBox(height: 16),
              GlassCard(
                onTap: () async => await Supabase.instance.client.auth.signOut(),
                child: const ListTile(leading: Icon(Icons.logout, color: Colors.red), title: Text('تسجيل الخروج', style: TextStyle(color: Colors.red))),
              ),
            ],
          );
        },
      ),
    );
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
    _animationController = AnimationController(vsync: this, duration: Duration(milliseconds: 300));
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
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              child: GlassCard(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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
                        builder: (context, child) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Transform.rotate(
                                angle: _animation.value * 0.785,
                                child: Container(width: 30, height: 3, decoration: BoxDecoration(color: AppColors.button, borderRadius: BorderRadius.circular(2))),
                              ),
                              SizedBox(height: _animation.value * 8 + 6),
                              Transform.rotate(
                                angle: -_animation.value * 0.785,
                                child: Container(width: 30, height: 3, decoration: BoxDecoration(color: AppColors.button, borderRadius: BorderRadius.circular(2))),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(AppConfig.appName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.button)),
                  ],
                ),
              ),
            ),
            if (isAdmin)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.button),
                title: const Text('لوحة التحكم', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminPanel())),
              ),
            ListTile(
              leading: const Icon(Icons.add_home_work_outlined, color: AppColors.icon),
              title: const Text('طلب إنشاء غرفة'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateRoomRequestScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.icon),
              title: const Text('سياسة الخصوصية'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline_rounded, color: AppColors.icon),
              title: const Text('تواصل معنا'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactUsScreen())),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('© ${AppConfig.copyrightYear} ${AppConfig.copyrightName}. All rights reserved.', style: const TextStyle(color: AppColors.textLight, fontSize: 12), textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});
  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  final supabase = Supabase.instance.client;
  bool isAdmin = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _checkIfAdmin();
  }

  Future<void> _checkIfAdmin() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final profile = await supabase.from('profiles').select('role').eq('id', user.id).single();
    setState(() {
      isAdmin = profile['role'] == 'admin';
      loading = false;
    });
  }

  Future<void> _banUser(String userId) async {
    await supabase.from('profiles').update({'is_banned': true}).eq('id', userId);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar
