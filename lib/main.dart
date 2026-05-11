import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';
import 'supabase_repository.dart';
import 'auth_screens.dart';
import 'profile_settings.dart';
import 'private_chat.dart';
import 'admin_panel.dart';
import 'chat_screen.dart';
import 'create_room_screen.dart';
import 'contact_us_screen.dart';
import 'privacy_policy_screen.dart';
import 'dart:ui';

// ========== الألوان مدموجة هنا ==========
class AppColors {
  static const Color button = Color(0xFF00BCD4);
  static const Color primaryBlue = Color(0xFF0F172A);
  static const Color textDark = Color(0xFF1E293B);
  static const Color textLight = Color(0xFFCBD5E1);
  static const Color icon = Color(0xFF64748B);
  static const Color cardGlass = Color(0x1AFFFFFF);
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL', // بدله
    anonKey: 'YOUR_SUPABASE_ANON_KEY', // بدله
  );

  runApp(const SeaChatApp());
}

final repo = SupabaseRepository();

class SeaChatApp extends StatelessWidget {
  const SeaChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sea Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Cairo',
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.primaryBlue,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.button,
          brightness: Brightness.dark,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: AppColors.button)),
          );
        }

        final session = snapshot.data?.session;
        if (session == null) {
          return const AuthScreen();
        }

        return FutureBuilder<UserModel?>(
          future: repo.getCurrentUser(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator(color: AppColors.button)),
              );
            }

            final user = userSnapshot.data;
            
            if (user?.isBanned == true) {
              return const BannedScreen();
            }
            
            if (user?.role == 'admin') {
              return const AdminPanel();
            }
            
            return const ProfileSettings(); // مؤقتاً حتى نصلح ChatScreen
          },
        );
      },
    );
  }
}

class BannedScreen extends StatelessWidget {
  const BannedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.block, size: 80, color: AppColors.error),
            const SizedBox(height: 20),
            const Text(
              'تم حظر حسابك',
              style: TextStyle(fontSize: 24, color: AppColors.textLight, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => repo.supabase.auth.signOut(),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.button),
              child: const Text('تسجيل الخروج'),
            ),
          ],
        ),
      ),
    );
  }
}
