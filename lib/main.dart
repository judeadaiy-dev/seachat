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
// ============= COLORS =============
class AppColors {
  static const Color primaryBlue = Color(0x90830080); // الخلفية شفافة 76% - تبقى مثل ما هي
  static const Color button = Color(0x898199FF);      // شلت الشفافية - صار اخضر صلب
  static const Color icon = Color(0x80A1D4CC);        // شلت الشفافية - صار بنفسجي فاتح صلب  
  static const Color cardGlass = Color(0x40FFFFFF);   // زجاجي شفاف - يبقى
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
    final res = await supabase.from('profiles').select('role').eq('id', user.id).maybeSingle();
    return res?['role'] == 'admin';
  }

  Stream<List<RoomModel>> getRoomsStream() {
    return supabase
       .from('rooms')
       .stream(primaryKey: ['id'])
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
      title: 'SeaChat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.primaryBlue, // خلفية موحدة
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
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

// ============= MAIN SCREEN مع الشريط السفلي الجديد =============
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final repo = SupabaseRepository();
  bool isAdmin = false;
  late AnimationController _controller;
  late Animation<double> _animation;

  final List<Widget> _screens = const [
    RoomsScreen(),
    ExploreScreen(),
    PrivateChatsScreen(),
    ProfileScreen(),
  ];

  final List<IconData> _icons = [
    Icons.home_rounded,
    Icons.favorite_border_rounded,
    Icons.chat_bubble_outline_rounded,
    Icons.person_outline_rounded,
  ];

  final List<IconData> _activeIcons = [
    Icons.home_rounded,
    Icons.favorite_rounded,
    Icons.chat_bubble_rounded,
    Icons.person_rounded,
  ];

  final List<String> _titles = ['دردشاتي', 'استكشاف', 'الخاص', 'البروفايل'];

  @override
  void initState() {
    super.initState();
    _checkAdmin();
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

  void _onTap(int index) {
    setState(() => _currentIndex = index);
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      drawer: AppDrawer(isAdmin: isAdmin),
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: Container(
        height: 80,
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 5))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(4, (index) {
                  final isActive = _currentIndex == index;
                  return GestureDetector(
                    onTap: () => _onTap(index),
                    child: Container(
                      width: 60,
                      height: 60,
                      color: Colors.transparent,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 200),
                        scale: isActive? 1.1 : 1.0,
                        child: Icon(
                          isActive? _activeIcons[index] : _icons[index],
                          color: AppColors.primaryBlue,
                          size: 28,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              bottom: 6,
              left: _currentIndex * (MediaQuery.of(context).size.width - 48) / 4 + 24 + 22,
              child: ScaleTransition(
                scale: _animation,
                child: Container(
                  width: 16,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============= DRAWER =============
class AppDrawer extends StatelessWidget {
  final bool isAdmin;
  const AppDrawer({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.primaryBlue,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.forum_rounded, size: 40, color: Colors.white),
              const SizedBox(height: 12),
              Text(AppConfig.appName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            ]),
          ),
          if (isAdmin)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white),
              title: const Text('لوحة التحكم', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanel()));
              },
            ),
          ListTile(
            leading: const Icon(Icons.add_home_work_outlined, color: Colors.white70),
            title: const Text('إنشاء غرفة', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateRoomRequestScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined, color: Colors.white70),
            title: const Text('سياسة الخصوصية', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline_rounded, color: Colors.white70),
            title: const Text('تواصل معنا', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactUsScreen()));
            },
          ),
        ],
      ),
    );
  }
}

// ============= ROOMS SCREEN =============
class RoomsScreen extends StatelessWidget {
  const RoomsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = SupabaseRepository();
    return StreamBuilder<List<RoomModel>>(
      stream: repo.getRoomsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }
        if (snapshot.hasError) return Center(child: Text('خطأ: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
        final rooms = snapshot.data?? [];
        if (rooms.isEmpty) return const Center(child: Text('لا توجد غرف حالياً', style: TextStyle(color: Colors.white)));

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: rooms.length,
          itemBuilder: (context, index) {
            final room = rooms[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                color: Colors.white.withOpacity(0.1),
                child: ListTile(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(room: room))),
                  leading: const Icon(Icons.groups_2_rounded, color: Colors.white),
                  title: Text(room.roomName, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                  subtitle: Text(room.description?? 'غرفة جماعية', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white70),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ============= شاشات مؤقتة - انقلها لملفات منفصلة بعدين =============
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('استكشاف', style: TextStyle(color: Colors.white, fontSize: 24)));
  }
}
