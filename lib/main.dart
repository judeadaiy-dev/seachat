import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
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
            // فحص الحظر الرصين
            return FutureBuilder(
              future: Supabase.instance.client
               .from('profiles')
               .select('is_banned')
               .eq('id', session.user.id)
               .single(),
              builder: (context, banSnapshot) {
                if (banSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }

                // إذا محظور، اطرده
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
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 24,
    this.onTap,
    this.margin,
  });
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
    final repo = SupabaseRepository();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('الغرف النشطة'),
        leading: Builder(builder: (context) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(context).openDrawer())),
      ),
      body: FutureBuilder<List<RoomModel>>(
        future: repo.getAllActiveRooms(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.button));
          }
          if (snapshot.hasError) return Center(child: Text('خطأ: ${snapshot.error}'));
          final rooms = snapshot.data?? [];
          if (rooms.isEmpty) return const Center(child: Text('لا توجد غرف حالياً'));
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: rooms.length,
            itemBuilder: (context, i) {
              final room = rooms[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(room: room))),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: AppColors.button.withOpacity(0.2), child: const Icon(Icons.group, color: AppColors.button)),
                    title: Text(room.roomName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${room.membersCount} عضو'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.icon),
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

class ChatScreen extends StatefulWidget {
  final RoomModel room;
  const ChatScreen({super.key, required this.room});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final repo = SupabaseRepository();
  final msgController = TextEditingController();
  @override
  void dispose() {
    msgController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (msgController.text.trim().isEmpty) return;
    await repo.sendMessage(roomId: widget.room.id, message: msgController.text);
    msgController.clear();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image!= null && mounted) {
      await repo.sendImageMessage(roomId: widget.room.id, imageFile: File(image.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, title: Text(widget.room.roomName)),
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
                      return Align(
                        alignment: msg.isMe? Alignment.centerLeft : Alignment.centerRight,
                        child: GlassCard(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: msg.text.startsWith('http')
                           ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(msg.text, width: 200, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Text('فشل تحميل الصورة')))
                              : Text(msg.text, style: TextStyle(color: msg.isMe? Colors.white : AppColors.textDark)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(onPressed: _pickImage, icon: const Icon(Icons.attach_file_rounded, color: AppColors.icon)),
                    Expanded(child: TextField(controller: msgController, decoration: const InputDecoration(hintText: 'اكتب رسالة...', border: InputBorder.none), onSubmitted: (_) => _sendMessage())),
                    IconButton(onPressed: _sendMessage, icon: const Icon(Icons.send_rounded, color: AppColors.button)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

// ===== الهمبرغر + لوحة التحكم المدمجة =====
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
    final res = await supabase.from('profiles').select('role').eq('id', user.id).single();
    if (mounted) setState(() => isAdmin = res['role'] == 'admin');
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

// ===== لوحة التحكم الكاملة =====
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حظر المستخدم وسيتم طرده'), backgroundColor: Colors.red));
  }

  Future<void> _unbanUser(String userId) async {
    await supabase.from('profiles').update({'is_banned': false}).eq('id', userId);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم رفع الحظر'), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!isAdmin) {
      return Scaffold(appBar: AppBar(title: Text('غير مصرح')), body: Center(child: Text('ما عندك صلاحية لوحة التحكم', style: TextStyle(fontSize: 18))));
    }
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('لوحة تحكم SeaChat'),
          backgroundColor: AppColors.button,
          bottom: TabBar(tabs: [Tab(text: 'طلبات الغرف'), Tab(text: 'الدعم الفني'), Tab(text: 'المستخدمين')]),
        ),
        backgroundColor: Color(0xFF1E1E2C),
        body: TabBarView(children: [_buildTicketsTab('create_room'), _buildTicketsTab('support'), _buildUsersTab()]),
      ),
    );
  }

  Widget _buildTicketsTab(String type) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase.from('tickets').stream(primaryKey: ['id']).eq('type', type).eq('status', 'open').order('created_at'),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
        final tickets = snapshot.data!;
        if (tickets.isEmpty) return Center(child: Text('لا توجد طلبات', style: TextStyle(color: Colors.white)));
        return ListView.builder(
          itemCount: tickets.length,
          itemBuilder: (context, index) {
            final ticket = tickets[index];
            return Card(
              color: Colors.grey[850],
              margin: EdgeInsets.all(8),
              child: ListTile(
                title: Text(ticket['title']?? 'بدون عنوان', style: TextStyle(color: Colors.white)),
                subtitle: Text(ticket['content'], style: TextStyle(color: Colors.grey)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: Icon(Icons.check, color: Colors.green), onPressed: () => supabase.from('tickets').update({'status': 'closed'}).eq('id', ticket['id'])),
                    IconButton(icon: Icon(Icons.close, color: Colors.red), onPressed: () => supabase.from('tickets').delete().eq('id', ticket['id'])),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUsersTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase.from('profiles').stream(primaryKey: ['id']).order('username'),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
        final users = snapshot.data!;
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final banned = user['is_banned'] == true;
            return ListTile(
              leading: CircleAvatar(child: Text(user['username']?[0]?? '?')),
              title: Text(user['username']?? 'بدون اسم', style: TextStyle(color: Colors.white)),
              subtitle: Text('الرتبة: ${user['role']} | ${banned? "محظور" : "نشط"}', style: TextStyle(color: banned? Colors.red : Colors.green)),
              trailing: banned
               ? IconButton(icon: Icon(Icons.lock_open, color: Colors.green), onPressed: () => _unbanUser(user['id']))
                : IconButton(icon: Icon(Icons.block, color: Colors.red), onPressed: () => _banUser(user['id'])),
            );
          },
        );
      },
    );
  }
}

// ===== طلب إنشاء غرفة =====
class CreateRoomRequestScreen extends StatefulWidget {
  const CreateRoomRequestScreen({super.key});
  @override
  State<CreateRoomRequestScreen> createState() => _CreateRoomRequestScreenState();
}

class _CreateRoomRequestScreenState extends State<CreateRoomRequestScreen> {
  final nameController = TextEditingController();
  final descController = TextEditingController();
  final supabase = Supabase.instance.client;
  bool loading = false;

  Future<void> _sendRequest() async {
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('اكتب اسم الغرفة')));
      return;
    }
    setState(() => loading = true);
    try {
      await supabase.from('tickets').insert({
        'user_id': supabase.auth.currentUser!.id,
        'type': 'create_room',
        'title': nameController.text.trim(),
        'content': 'فعل لي غرفة أرجوك\nالاسم: ${nameController.text}\nالوصف: ${descController.text}',
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إرسال الطلب للمدير')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('طلب إنشاء غرفة')),
      body: AppBackground(
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            GlassCard(
              child: Column(
                children: [
                  TextField(controller: nameController, decoration: InputDecoration(hintText: 'اسم الغرفة المطلوبة', border: InputBorder.none)),
                  Divider(),
                  TextField(controller: descController, maxLines: 3, decoration: InputDecoration(hintText: 'وصف الغرفة والهدف منها', border: InputBorder.none)),
                  SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.button, minimumSize: Size(double.infinity, 50)),
                    onPressed: loading? null : _sendRequest,
                    child: loading? CircularProgressIndicator(color: Colors.white) : Text('إرسال الطلب للمدير', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== تواصل معنا =====
class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});
  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  final msgController = TextEditingController();
  final supabase = Supabase.instance.client;
  bool loading = false;

  Future<void> _sendMessage() async {
    if (msgController.text.trim().isEmpty) return;
    setState(() => loading = true);
    try {
      await supabase.from('tickets').insert({
        'user_id': supabase.auth.currentUser!.id,
        'type': 'support',
        'title': 'رسالة من المستخدم',
        'content': msgController.text.trim(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إرسال رسالتك للمدير')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('تواصل معنا')),
      body: AppBackground(
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('اكتب مشكلتك أو اقتراحك', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  TextField(
                    controller: msgController,
                    maxLines: 6,
                    decoration: InputDecoration(hintText: 'اشرح مشكلتك بالتفصيل...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.button, minimumSize: Size(double.infinity, 50)),
                    onPressed: loading? null : _sendMessage,
                    child: loading? CircularProgressIndicator(color: Colors.white) : Text('إرسال', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== سياسة خصوصية =====
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
              child: Text(
                '''مرحباً بك في SeaChat.

1. نحترم خصوصيتك ولا نشارك بياناتك مع أي طرف ثالث.
2. الرسائل مشفرة ومحفوظة بشكل آمن في خوادم Supabase.
3. عند حذف حسابك، نحذف جميع بياناتك نهائياً خلال 30 يوم.
4. لا نستخدم بياناتك للإعلانات أو التتبع.
5. المدير فقط يرى طلبات الدعم لحل مشاكلك.

باستخدامك للتطبيق فأنت توافق على هذه السياسة.''',
                style: const TextStyle(color: AppColors.textLight, height: 1.8, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  NotificationModel({required this.id, required this.userId, required this.title, required this.body, required this.createdAt, this.isRead = false});
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?? '',
      userId: json['user_id']?? '',
      title: json['title']?? '',
      body: json['body']?? '',
      createdAt: DateTime.tryParse(json['created_at']?? '')?? DateTime.now(),
      isRead: json['is_read']?? false,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'body': body,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
    };
  }
}
