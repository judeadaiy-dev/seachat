import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';
import 'main.dart';
import 'widgets.dart';
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView( // لضمان عدم حدوث Overflow
              padding: const EdgeInsets.all(24),
              child: GlassCard(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [AppColors.button, AppColors.button.withOpacity(0.7)]),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.forum_rounded, size: 60, color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'دردشاتي',
                      style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.button),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'تواصل مع أصدقائك بسهولة وأمان',
                      style: TextStyle(fontSize: 14, color: AppColors.textLight.withOpacity(0.8)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.button,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                        child: const Text('تسجيل الدخول', style: TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.button, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpScreen())),
                        child: const Text('إنشاء حساب جديد', style: TextStyle(fontSize: 17, color: AppColors.button, fontWeight: FontWeight.w600)),
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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passController = TextEditingController();
  bool isLoading = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String hint, IconData icon, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.icon.withOpacity(0.7)),
      prefixIcon: Icon(icon, color: AppColors.icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withOpacity(0.5),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    );
  }

  Future<void> _handleLogin() async {
    final email = emailController.text.trim();
    final password = passController.text;

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('يرجى ملء البريد الإلكتروني وكلمة المرور');
      return;
    }

    setState(() => isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (e) {
      _showSnackBar('فشل تسجيل الدخول: ${e.message}');
    } catch (e) {
      _showSnackBar('حدث خطأ غير متوقع');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: GlassCard(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('مرحباً بعودتك', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.button)),
                  const SizedBox(height: 8),
                  Text('سجل دخولك للمتابعة', style: TextStyle(fontSize: 14, color: AppColors.textLight.withOpacity(0.8))),
                  const SizedBox(height: 32),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDecoration('البريد الإلكتروني', Icons.email_outlined),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passController,
                    obscureText: obscurePassword,
                    decoration: _inputDecoration(
                      'كلمة المرور',
                      Icons.lock_outline,
                      suffixIcon: IconButton(
                        icon: Icon(obscurePassword? Icons.visibility_off : Icons.visibility, color: AppColors.icon),
                        onPressed: () => setState(() => obscurePassword = !obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.button,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: isLoading? null : _handleLogin,
                      child: isLoading
                         ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('تسجيل الدخول', style: TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passController = TextEditingController();
  final confirmPassController = TextEditingController();
  bool isLoading = false;
  bool obscurePassword = true;

  Future<void> _handleSignUp() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnackBar('يرجى ملء جميع الحقول');
      return;
    }

    if (password != confirmPassController.text) {
      _showSnackBar('كلمة المرور غير متطابقة');
      return;
    }

    setState(() => isLoading = true);
    try {
      // تمرير الاسم في الـ data لضمان وصوله لجدول البروفايل عبر الـ Trigger في قاعدة البيانات
      await Supabase.instance.client.auth.signUp(
        email: email, 
        password: password, 
        data: {'name': name}
      );
      if (mounted) {
        _showSnackBar('تم إنشاء الحساب بنجاح');
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on AuthException catch (e) {
      _showSnackBar(e.message);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: GlassCard(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('إنشاء حساب', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.button)),
                  const SizedBox(height: 32),
                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDecoration('الاسم الكامل', Icons.person_outline),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDecoration('البريد الإلكتروني', Icons.email_outlined),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passController,
                    obscureText: obscurePassword,
                    decoration: _inputDecoration('كلمة المرور', Icons.lock_outline),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmPassController,
                    obscureText: obscurePassword,
                    decoration: _inputDecoration('تأكيد كلمة المرور', Icons.lock_outline),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.button, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      onPressed: isLoading ? null : _handleSignUp,
                      child: isLoading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text('إنشاء الحساب', style: TextStyle(color: Colors.white, fontSize: 17)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
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
}
