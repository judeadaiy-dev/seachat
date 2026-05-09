import 'dart:io';
import 'dart:ui';
import 'package:image_picker/image_picker.dart';
import 'data/supabase_repository.dart';
import 'models.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/app_config.dart';

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
  // 1. لازم أول سطر
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. تهيئة Supabase قبل تشغيل التطبيق
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  
  // 3. شغل التطبيق
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sea Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const LoginPage(), // غيّرها لصفحة البداية مالتك
    );
  }
}

// صفحة مؤقتة للتجربة
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sea Chat')),
      body: const Center(child: Text('تم الاتصال بـ Supabase')),
    );
  }
}
  runApp(MyApp());
}
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
      home: Supabase.instance.client.auth.currentUser == null
        ? const LoginScreen()
          : const MainScreen(),
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
                  border: Border.all(
                    color: Colors.white.withOpacity(0.4),
                    width: 1.5,
                  ),
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
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (emailController.text.trim().isEmpty ||
        passController.text.trim().isEmpty) return;

    setState(() => isLoading = true);

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: emailController.text.trim(),
        password: passController.text,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ غير متوقع: $e')),
        );
      }
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
                    const Icon(Icons.waves_rounded,
                        size: 60, color: AppColors.button),
                    const SizedBox(height: 12),
                    const Text(
                      AppConfig.appName,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.button,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecoration(
                          'البريد الإلكتروني', Icons.email_outlined),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passController,
                      obscureText: true,
                      decoration:
                          _inputDecoration('كلمة المرور', Icons.lock_outline),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.button,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: isLoading? null : _handleLogin,
                        child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'تسجيل الدخول',
                                style: TextStyle(fontSize: 18, color: Colors.white),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.button),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () async => await repo.signInWithGoogle(),
                        icon: const Icon(Icons.g_mobiledata_rounded,
                            color: AppColors.button, size: 28),
                        label: const Text(
                          'المتابعة عبر Google',
                          style: TextStyle(color: AppColors.button),
                        ),
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
              BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded), label: 'الرئيسية'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person_rounded), label: 'الملف الشخصي'),
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
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      body: FutureBuilder<List<RoomModel>>(
        future: repo.getAllActiveRooms(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.button));
          }
          if (snapshot.hasError) {
            return Center(child: Text('خطأ: ${snapshot.error}'));
          }
          final rooms = snapshot.data?? [];
          if (rooms.isEmpty) {
            return const Center(child: Text('لا توجد غرف حالياً'));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: rooms.length,
            itemBuilder: (context, i) {
              final room = rooms[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(room: room),
                    ),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.button.withOpacity(0.2),
                      child: const Icon(Icons.group, color: AppColors.button),
                    ),
                    title: Text(
                      room.roomName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('${room.membersCount} عضو'),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        size: 16, color: AppColors.icon),
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
    await repo.sendMessage(
      roomId: widget.room.id,
      message: msgController.text,
    );
    msgController.clear();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image!= null && mounted) {
      await repo.sendImageMessage(
        roomId: widget.room.id,
        imageFile: File(image.path),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(widget.room.roomName),
      ),
      body: AppBackground(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<MessageModel>>(
                stream: repo.getRoomMessagesStream(roomId: widget.room.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final messages = snapshot.data!;
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
                    reverse: true,
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final msg = messages[i];
                      return Align(
                        alignment: msg.isMe
                          ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: GlassCard(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: msg.text.startsWith('http')
                            ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    msg.text,
                                    width: 200,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Text('فشل تحميل الصورة'),
                                  ),
                                )
                              : Text(
                                  msg.text,
                                  style: TextStyle(
                                    color: msg.isMe
                                      ? Colors.white
                                        : AppColors.textDark,
                                  ),
                                ),
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
                    IconButton(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.attach_file_rounded,
                          color: AppColors.icon),
                    ),
                    Expanded(
                      child: TextField(
                        controller: msgController,
                        decoration: const InputDecoration(
                          hintText: 'اكتب رسالة...',
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    IconButton(
                      onPressed: _sendMessage,
                      icon: const Icon(Icons.send_rounded,
                          color: AppColors.button),
                    ),
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('الملف الشخصي'),
      ),
      body: FutureBuilder<UserModel?>(
        future: repo.getCurrentUser(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('المستخدم غير موجود'));
          }
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
                      backgroundImage: user.avatarUrl!= null
                        ? NetworkImage(user.avatarUrl!)
                          : null,
                      child: user.avatarUrl == null
                        ? Text(
                              user.name.isNotEmpty? user.name[0] : 'U',
                              style: const TextStyle(
                                  fontSize: 40, color: Colors.white),
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user.name,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      user.email,
                      style: const TextStyle(color: AppColors.textLight),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                onTap: () async {
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false,
                    );
                  }
                },
                child: const ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text('تسجيل الخروج',
                      style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

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
                    const Icon(Icons.waves_rounded,
                        size: 40, color: AppColors.button),
                    const SizedBox(height: 8),
                    const Text(
                      AppConfig.appName,
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined,
                  color: AppColors.icon),
              title: const Text('سياسة الخصوصية'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline_rounded,
                  color: AppColors.icon),
              title: const Text('تواصل معنا'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ContactUsScreen()),
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '© ${AppConfig.copyrightYear} ${AppConfig.copyrightName}. All rights reserved.',
                style:
                    const TextStyle(color: AppColors.textLight, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
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
        child: FutureBuilder<String>(
          future: SupabaseRepository().getPrivacyPolicy(),
          builder: (context, snapshot) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GlassCard(
                  child: Text(
                    snapshot.data?? 'جاري التحميل...',
                    style: const TextStyle(
                        color: AppColors.textLight, height: 1.6),
                  ),
                ),
              ],
            );
          },
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
      body: const AppBackground(
        child: Center(
          child: GlassCard(
            margin: EdgeInsets.all(24),
            child: Text(
              'للتواصل: support@seachat.app',
              style: TextStyle(fontSize: 18),
            ),
          ),
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

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?? '',
      userId: json['user_id']?? '',
      title: json['title']?? '',
      body: json['body']?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?? '')??
          DateTime.now(),
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
