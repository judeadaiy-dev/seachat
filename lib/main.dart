import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/supabase_repository.dart';
import 'auth_screens.dart';
import 'profile_settings.dart';
import 'chat_screen.dart';
import 'create_room_screen.dart';
import 'models.dart'; // مهم

class AppColors {
  static const Color button = Color(0xFF4B0082);
  static const Color primaryBlue = Color(0xFFD7EFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF2D3748);
  static const Color textLight = Color(0xFF718096);
  static const Color error = Color(0xFFE53E3E);
  static const Color icon = Color(0xFFAEB8A0);
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
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.primaryBlue,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.button),
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
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final session = snapshot.data?.session;
        if (session == null) return AuthScreen();
        return FutureBuilder<UserModel?>(
          future: repo.getCurrentUser(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final user = userSnapshot.data;
            if (user == null) return AuthScreen();
            if (user.isBanned) return BannedScreen();
            if (user.name.isEmpty) return ProfileSettings();
            return HomeScreen();
          },
        );
      },
    );
  }
}

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
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileSettings())),
          ),
          IconButton(
            icon: Icon(Icons.logout, color: AppColors.icon),
            onPressed: () => repo.signOut(),
          ),
        ],
      ),
      body: FutureBuilder<List<RoomModel>>(
        future: repo.getRooms(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
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
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateRoomScreen())),
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
                title: Text(room.roomName, style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
                subtitle: Text(room.description?? '', style: TextStyle(color: AppColors.textLight)),
                leading: Icon(Icons.chat_bubble, color: AppColors.icon),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(room: room))),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.button,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateRoomScreen())),
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class BannedScreen extends StatelessWidget {
  BannedScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block, size: 80, color: AppColors.error),
            SizedBox(height: 20),
            Text('تم حظر حسابك', style: TextStyle(fontSize: 24, color: AppColors.textLight, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => repo.signOut(),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.button),
              child: Text('تسجيل الخروج', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
