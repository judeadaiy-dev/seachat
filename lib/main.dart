import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart'; // الموديلات مالتك
import 'auth_screens.dart';
import 'profile_settings.dart';
import 'private_chat.dart';
import 'admin_panel.dart';
import 'chat_screen.dart';
import 'create_room_screen.dart';
import 'contact_us_screen.dart';
import 'privacy_policy_screen.dart';
import 'dart:ui';

// 1. دالة main - التطبيق يبدي من هنا
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://xxxxxxxxxxxx.supabase.co', // بدله بالرابط مالتك
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...', // بدله بالكي مالتك
  );

  runApp(const MyApp());
}

// اختصار للوصول لـ supabase
final supabase = Supabase.instance.client;

// 2. الويدجت الرئيسي
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sea Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Cairo',
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      // 3. اول شاشة: يفحص اذا مسجل دخول لو لا
      home: const AuthGate(),
    );
  }
}

// 4. هذا يقرر يوديك للتسجيل لو للشات
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        final session = snapshot.data?.session;
        if (session != null) {
          return const ChatScreen(); // اذا مسجل دخول
        } else {
          return const AuthScreen(); // اذا مو مسجل
        }
      },
    );
  }
}
