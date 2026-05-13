import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/supabase_repository.dart';
import 'auth_screens.dart';
import 'profile_settings.dart';
import 'private_chat.dart';
import 'admin_panel.dart';
import 'chat_screen.dart';
import 'create_room_screen.dart';
import 'contact_us_screen.dart';
import 'privacy_policy_screen.dart';
import 'dart:ui';
import 'models.dart';

// ========== الألوان ==========
class AppColors {
  static const Color button = Color(0xFF4B0082);
  static const Color primaryBlue = Color(0xFFD7EFFF);
  static const Color background = Color(0xFFD7EFFF);

  static const Color icon = Color(0xFFAEB8A0);
  static const Color success = Color(0xFFAEB8A0);

  static const Color cardGlass = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);

  static const Color textDark = Color(0xFF2D3748);
  static const Color text = Color(0xFF2D3748);
  static const Color textLight = Color(0xFF718096);

  static const Color error = Color(0xFFE53E3E);
  static const Color delete = Color(0xFFE53E3E);
  static const Color border = Color(0xFFCBD5E0);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://jmsmrojtlstppnpwmkkk.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imptc21yb2p0bHN0cHBucHdta2trIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4MTg2NDAsImV4cCI6MjA4ODM5NDY0MH0.j7gxr5CvrfvbJJzK_pMwVHiCE2AqpXUTThpeLEBmsos',
  );

  runApp(SeaChatApp());
}

final repo = SupabaseRepository();

class SeaChatApp extends StatelessWidget {
  SeaChatApp({super.key});

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
      home: AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator(color: AppColors.button)),
          );
        }

        final session = snapshot.data?.session;
        if (session == null) {
          return AuthScreen();
        }

        return FutureBuilder<UserModel?>(
          future: repo.getCurrentUser(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                body: Center(child: CircularProgressIndicator(color: AppColors.button)),
              );
            }

            final user = userSnapshot.data;

            // اذا ما لقى يوزر بالـ profiles
            if (user == null) {
              return AuthScreen();
            }

            // اذا محظور
            if (user.isBanned == true) {
              return BannedScreen();
            }

            // الكل يروح للهوم سكرين - ما يهمنا الادمن هسه
            return HomeScreen();
          },
        );
      },
    );
  }
}

// شاشة رئيسية بسيطة تعرض قائمة الغرف
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      appBar: AppBar(
        title: Text('Sea Chat', style: TextStyle(color: AppColors.textDark)),
        backgroundColor: AppColors.card,
        actions: [
          IconButton(
            icon: Icon(Icons.person, color: AppColors.icon),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileSettings()));
            },
          ),
          IconButton(
            icon: Icon(Icons.logout, color: AppColors.icon),
            onPressed: () => repo.supabase.auth.signOut(),
          ),
        ],
      ),
      body: FutureBuilder<List<RoomModel>>(
        future: repo.getRooms(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: AppColors.button));
          }

          final rooms = snapshot.data?? [];

          if (rooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('لا توجد غرف بعد', style: TextStyle(color: AppColors.textDark, fontSize: 18)),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => CreateRoomScreen()));
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.button),
                    child: Text('انشاء غرفة جديدة', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = rooms[index];
              return ListTile(
                title: Text(room.name?? 'غرفة', style: TextStyle(color: AppColors.textDark)),
                leading: Icon(Icons.chat_bubble, color: AppColors.icon),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPage
