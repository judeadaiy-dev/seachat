import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';
import 'auth_screens.dart';
import 'profile_settings.dart';
import 'private_chat.dart';
import 'admin_panel.dart';
import 'chat_screen.dart';
import 'create_room_screen.dart';
import 'contact_us_screen.dart';
import 'privacy_policy_screen.dart';
import 'dart:ui';

// ============= CONFIG =============
class AppConfig {
  static const String appName = 'دردشاتي';
  static const String supabaseUrl = 'https://jmsmrojtlstppnpwmkkk.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imptc21yb2p0bHN0cHBucHdta2trIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4MTg2NDAsImV4cCI6MjA4ODM5NDY0MH0.j7gxr5CvrfvbJJzK_pMwVHiCE2AqpXUTThpeLEBmsos';
  static const int copyrightYear = 2026;
  static const String copyrightName = 'دردشاتي';
}

// ============= COLORS فيروزي جديد =============
class AppColors {
  static const Color primaryBlue = Color(0xFFE0F7FA);
  static const Color button = Color(0xFF00BCD4);
  static const Color icon = Color(0xFF4DD0E1);
  static const Color cardGlass = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF1A1821);
  static const Color textLight = Color(0xFFFFFFFF);
}

// ============= REPOSITORY =============
class SupabaseRepository {
  final supabase = Supabase.instance.client;

  Future<UserModel?> getCurrentUser() async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;
    final res = await supabase.from('profiles').select().eq('id', user.id).maybeSingle();
    return res!= null? UserModel.fromMap(res) : null;
  }

  Future<bool> isCurrentUserAdmin() async {
  final user = supabase.auth.currentUser;
  if (user == null) return false;
  
  // حطيت ايميلك هنا عشان تصير أدمن
  const adminEmails = ['barqaday@gmail.com']; 
  return adminEmails.contains(user.email);
  }

  Future<bool> userHasCreatedRoom() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return false;
    final res = await supabase.from('rooms').select('id').eq('owner_id', userId).limit(1);
    return res.isNotEmpty;
  }

  Stream<List<RoomModel>> getRoomsStream() {
    return supabase
       .from('rooms')
       .stream(primaryKey: ['id'])
       .order('created_at', ascending: false)
       .map((maps) => maps.map((m) => RoomModel.fromMap(m)).toList());
  }

  Stream<List<RoomModel>> getMyRoomsStream() {
    final userId = supabase.auth.currentUser!.id;
    return supabase
       .from('rooms')
       .stream(primaryKey: ['id'])
       .eq('owner_id', userId)
       .order('created_at', ascending: false)
       .map((maps) => maps.map((m) => RoomModel.fromMap(m)).toList());
  }

  Future<void> joinRoom(String roomId) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('room_members').upsert({'room_id': roomId, 'user_id': userId, 'role': 'member'});
  }

  Future<void> leaveRoom(String roomId) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('room_members').delete().eq('room_id', roomId).eq('user_id', userId);
  }
}

// ============= MAIN =============
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'دردشاتي',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Cairo',
        scaffoldBackgroundColor: AppColors.primaryBlue,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.button,
          background: AppColors.primaryBlue,
          surface: AppColors.cardGlass,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF4DD0E1),
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: AppColors.textDark),
          titleTextStyle: TextStyle(
            color: AppColors.textDark,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Colors.white,
          scrimColor: Colors.black54,
        ),
        cardTheme: CardThemeData(
          color: AppColors.cardGlass,
          elevation: 3,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.button,
          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontFamily: 'Cairo',
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final session = snapshot.data?.session;
        if (session!= null) {
          return const MainScreen();
        } else {
          return const WelcomeScreen();
        }
      },
    );
  }
}

// ============= MAIN SCREEN جديد =============
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final repo = SupabaseRepository();
  bool isAdmin = false;
  bool hasRoom = false;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
    _checkUserRoom();
    _controller = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkAdmin() async {
    final admin = await repo.isCurrentUserAdmin();
    if (mounted) setState(() => isAdmin = admin);
  }

  Future<void> _checkUserRoom() async {
    final result = await repo.userHasCreatedRoom();
    if (mounted) setState(() => hasRoom = result);
  }

  void _onTap(int index) {
    setState(() => _currentIndex = index);
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = hasRoom
       ? [const MyRoomsScreen(), const AllRoomsScreen(), const PrivateChatsScreen(), const ProfileScreen()]
        : [const AllRoomsScreen(), const PrivateChatsScreen(), const ProfileScreen()];

    final List<String> titles = hasRoom
       ? ['غرفتي', 'غرف', 'محادثة', 'حسابي']
        : ['غرف', 'محادثة', 'حسابي'];

    final List<IconData> icons = hasRoom
       ? [Icons.meeting_room_rounded, Icons.groups_rounded, Icons.chat_bubble_rounded, Icons.person_rounded]
        : [Icons.groups_rounded, Icons.chat_bubble_rounded, Icons.person_rounded];

    return Scaffold(
      extendBody: true,
      drawer: AppDrawer(isAdmin: isAdmin),
      appBar: AppBar(
        title: Text(titles[_currentIndex]),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: screens[_currentIndex],
      ),
      bottomNavigationBar: Container(
        color: Colors.transparent,
        child: SafeArea(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 5))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(screens.length, (index) {
                final isActive = _currentIndex == index;
                return GestureDetector(
                  onTap: () => _onTap(index),
                  child: Container(
                    width: 60,
                    height: 60,
                    color: Colors.transparent,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icons[index],
                          color: isActive? AppColors.button : Colors.grey.shade600,
                          size: 26,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          titles[index],
                          style: TextStyle(
                            fontSize: 10,
                            color: isActive? AppColors.button : Colors.grey.shade600,
                            fontWeight: isActive? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ============= DRAWER صلب مع لوحتي =============
تمام class AppDrawer extends StatelessWidget {
  final bool isAdmin;
  const AppDrawer({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              height: 120,
              decoration: const BoxDecoration(color: Color(0xFF4DD0E1)),
              padding: const EdgeInsets.all(16),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.chat_bubble, size: 40, color: Colors.white),
                  SizedBox(height: 8),
                  Text('دردشاتي', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            if (isAdmin) // هذا بس للأدمن
              ListTile(
                leading: const Icon(Icons.dashboard_rounded, color: AppColors.button),
                title: const Text('لوحتي', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600)),
                subtitle: const Text('إدارة الغرف والشكاوي', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanel()));
                },
              ),
            if (isAdmin) const Divider(),
            ListTile(
              leading: const Icon(Icons.add_home_work_outlined, color: AppColors.button),
              title: const Text('إنشاء غرفة', style: TextStyle(color: AppColors.textDark)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateRoomRequestScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.button),
              title: const Text('سياسة الخصوصية', style: TextStyle(color: AppColors.textDark)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline_rounded, color: AppColors.button),
              title: const Text('تواصل معنا', style: TextStyle(color: AppColors.textDark)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactUsScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }
}


// ============= ROOMS SCREEN كل الغرف =============
class AllRoomsScreen extends StatelessWidget {
  const AllRoomsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = SupabaseRepository();
    return StreamBuilder<List<RoomModel>>(
      stream: repo.getRoomsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.button));
        }
        if (snapshot.hasError) return Center(child: Text('خطأ: ${snapshot.error}', style: const TextStyle(color: AppColors.textDark)));
        final rooms = snapshot.data?? [];
        if (rooms.isEmpty) return const Center(child: Text('لا توجد غرف حالياً', style: TextStyle(color: AppColors.textDark)));

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: rooms.length,
          itemBuilder: (context, index) {
            final room = rooms[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(room: room))),
                  leading: const Icon(Icons.groups_2_rounded, color: AppColors.button),
                  title: Text(room.roomName, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
                  subtitle: Text(room.description?? 'غرفة جماعية', style: TextStyle(color: AppColors.textDark.withOpacity(0.7))),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.button),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ============= MY ROOMS غرفتي =============
class MyRoomsScreen extends StatelessWidget {
  const MyRoomsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = SupabaseRepository();
    return StreamBuilder<List<RoomModel>>(
      stream: repo.getMyRoomsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.button));
        }
        final rooms = snapshot.data?? [];
        if (rooms.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.meeting_room_outlined, size: 80, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('ما عندك غرف بعد', style: TextStyle(color: AppColors.textDark, fontSize: 18)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateRoomRequestScreen())),
                  icon: const Icon(Icons.add),
                  label: const Text('أنشئ غرفتك الأولى'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: rooms.length,
          itemBuilder: (context, index) {
            final room = rooms[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(room: room))),
                  leading: const Icon(Icons.meeting_room_rounded, color: AppColors.button),
                  title: Text(room.roomName, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
                  subtitle: Text('غرفتك', style: TextStyle(color: AppColors.button, fontWeight: FontWeight.w500)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.button),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
