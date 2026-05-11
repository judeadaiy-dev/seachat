import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart'; // الموديلات الجديدة مالتك
import 'auth_screens.dart';
import 'profile_settings.dart';
import 'private_chat.dart';
import 'admin_panel.dart';
import 'chat_screen.dart';
import 'create_room_screen.dart';
import 'contact_us_screen.dart';
import 'privacy_policy_screen.dart';
import 'dart:ui';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://jmsmrojtlstppnpwmkkk.supabase.co', // بدله
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imptc21yb2p0bHN0cHBucHdta2trIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4MTg2NDAsImV4cCI6MjA4ODM5NDY0MH0.j7gxr5CvrfvbJJzK_pMwVHiCE2AqpXUTThpeLEBmsos', // بدله
  );

  runApp(const SeaChatApp());
}

final supabase = Supabase.instance.client;

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00BCD4),
          brightness: Brightness.dark,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    
    // استمع لتغيير حالة تسجيل الدخول
    supabase.auth.onAuthStateChange.listen((data) {
      _getCurrentUser();
    });
  }

  Future<void> _getCurrentUser() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        final response = await supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .single();
        
        setState(() {
          _currentUser = UserModel.fromMap(response);
        });
      } catch (e) {
        setState(() {
          _currentUser = null;
        });
      }
    } else {
      setState(() {
        _currentUser = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // اذا مسجل دخول وجبنا بياناته
    if (_currentUser != null) {
      // اذا محظور
      if (_currentUser!.isBanned) {
        return const BannedScreen();
      }
      // اذا ادمن
      if (_currentUser!.role == 'admin') {
        return const AdminPanel();
      }
      // مستخدم عادي
      return const ChatScreen();
    }
    
    // اذا ما مسجل دخول
    return const AuthScreen();
  }
}

// شاشة الحظر البسيطة
class BannedScreen extends StatelessWidget {
  const BannedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'تم حظر حسابك',
          style: TextStyle(fontSize: 24, color: Colors.red),
        ),
      ),
    );
  }
}
