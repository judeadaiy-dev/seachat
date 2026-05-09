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
      // هذا هو الحل: StreamBuilder يتابع حالة تسجيل الدخول
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          // 1. أثناء التحميل
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // 2. اذا فيه جلسة = مسجل دخول
          final session = snapshot.hasData? snapshot.data!.session : null;

          if (session!= null) {
            return const MainScreen();
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
      // بس سجل دخول. لا تسوي Navigator. الـ StreamBuilder هو اللي ينقلك
      await Supabase.instance.client.auth.signInWithPassword(
        email: emailController.text.trim(),
        password: passController.text,
      );

      // لو وصل هنا معناته نجح، والـ StreamBuilder راح يوديك MainScreen تلقائي

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

// باقي الكلاسات نفسها بدون تغيير
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
            return Center(child: Text('خطأ: ${snapshot
