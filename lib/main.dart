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
  static const Color textDark = Color(0xFF2D2D);
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
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.button), shape: RoundedRectangleBorder(b
