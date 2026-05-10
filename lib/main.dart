import 'chat_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';
import 'auth_screens.dart';
import 'profile_settings.dart';
import 'private_chat.dart';
import 'admin_panel.dart';

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
  static const Color backgroundStart = Color(0xFF81B7EC);
  static const Color backgroundEnd = Color(0xFF655B77);
  static const Color button = Color(0xFF443C50);
  static const Color icon = Color(0xFF968A98);
  static const Color cardGlass = Color(0x40FFFFFF);
  static const Color textDark = Color(0xFF1A1821);
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color officialWood = Color(0xFF1A1821);
  static const Color officialGold = Color(0xFF81B7EC);
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

  Future<void> updateProfile({
    required String name,
    String? username,
    String? bio,
    String? zodiac,
  }) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('profiles').update({
      'name': name,
      'username': username,
      'bio': bio,
      'zodiac': zodiac,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  Future<String> uploadAvatar(File file) async {
  final fileName = '${supabase.auth.currentUser!.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
  
  // 1. رفع الملف إلى الباكت
  await supabase.storage.from('avatars').upload(fileName, file);

  // 2. الحصول على الرابط المباشر (هذا هو السطر الأهم)
  final String publicUrl = supabase.storage.from('avatars').getPublicUrl(fileName);
  
  // 3. تحديث رابط الصورة في جدول البروفايل
  await supabase.from('profiles').update({'avatar_url': publicUrl}).eq('id', supabase.auth.currentUser!.id);
  
  return publicUrl;
}

  Future<void> deleteAvatar() async {
  final userId = supabase.auth.currentUser!.id;
  final oldAvatar = await supabase.from('profiles').select('avatar_url').eq('id', userId).maybeSingle();

  if (oldAvatar?['avatar_url']!= null && oldAvatar!['avatar_url'].toString().isNotEmpty) {
    try {
      final oldPath = Uri.parse(oldAvatar['avatar_url']).pathSegments.last;
      // هذا السطر كان ناقص عندك - يحذف الملف من التخزين
      await supabase.storage.from('avatars').remove([oldPath]);
    } catch (e) {
      debugPrint('Error deleting old avatar: $e');
    }
  }

  // تحديث البروفايل بعد حذف الصورة
  await supabase.from('profiles').update({'avatar_url': null}).eq('id', userId);
}

  Stream<List<RoomModel>> getRoomsStream() {
    return supabase
       .from('rooms')
       .stream(primaryKey: ['id'])
       .order('is_pinned', ascending: false)
       .order('created_at')
       .map((maps) => maps.map((m) => RoomModel.fromMap(m)).toList());
  }

  Stream<List<MessageModel>> getRoomMessagesStream({required String roomId}) {
    final userId = supabase.auth.currentUser!.id;
    return supabase
       .from('messages')
       .stream(primaryKey: ['id'])
       .eq('room_id', roomId)
       .order('created_at')
       .map((maps) => maps.map((m) => MessageModel.fromMap(m, userId)).toList().reversed.toList());
  }

  Future<void> sendMessage({required String roomId, required String message}) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('messages').insert({'room_id': roomId, 'user_id': userId, 'message': message});
  }

  Future<void> joinRoom(String roomId) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('room_members').upsert({'room_id': roomId, 'user_id': userId, 'role': 'member'});
  }

  Future<void> leaveRoom(String roomId) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('room_members').delete().eq('room_id', roomId).eq('user_id', userId);
  }

  Future<void> deleteRoom(String roomId) async {
    await supabase.from('rooms').delete().eq('id', roomId);
  }

  Future<List<RoomMemberModel>> getRoomMembers(String roomId) async {
    final res = await supabase.from('room_members').select('*, profiles(*)').eq('room_id', roomId).order('points', ascending: false);
    return (res as List).map((m) => RoomMemberModel.fromMap(m)).toList();
  }

  Future<void> banUser(String userId) async {
    await supabase.from('profiles').update({'is_banned': true}).eq('id', userId);
  }

  Future<void> kickMember(String roomId, String userId) async {
    await supabase.from('room_members').delete().eq('room_id', roomId).eq('user_id', userId);
  }

  Future<bool> isUserBanned(String userId) async {
    final res = await supabase.from('profiles').select('is_banned').eq('id', userId).maybeSingle();
    return res?['is_banned'] == true;
  }

  Future<RoomModel?> getMyRoom() async {
    final userId = supabase.auth.currentUser!.id;
    final res = await supabase.from('rooms').select().eq('owner_id', userId).maybeSingle();
    return res!= null? RoomModel.fromMap(res) : null;
  }
}

// ============= MAIN =============
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey);
  runApp(const SeaChatApp());
}

class SeaChatApp extends StatelessWidget {
  const SeaChatApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Cairo', useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: AppColors.button)),
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
          return FutureBuilder<Map<String, dynamic>?>(
            future: Supabase.instance.client.from('profiles').select('is_banned').eq('id', session.user.id).maybeSingle(),
            builder: (context, banSnapshot) {
              if (banSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              final isBanned = banSnapshot.data?['is_banned'] == true;
              if (isBanned) {
                Supabase.instance.client.auth.signOut();
                return Scaffold(
                  body: AppBackground(
                    child: Center(
                      child: GlassCard(
                        margin: const EdgeInsets.all(24),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.block, size: 60, color: Colors.red),
                          const SizedBox(height: 16),
                          const Text('تم حظر حسابك', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)),
                          const SizedBox(height: 8),
                          const Text('تواصل مع الإدارة لرفع الحظر', style: TextStyle(color: AppColors.textLight)),
                        ]),
                      ),
                    ),
                  ),
                );
              }
              return const MainScreen();
            },
          );
        } else {
          return const WelcomeScreen();
        }
      },
    );
  }
}

// ============= WIDGETS =============
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.backgroundStart, AppColors.backgroundEnd])),
      child: child,
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;
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
                decoration: BoxDecoration(color: AppColors.cardGlass, borderRadius: BorderRadius.circular(borderRadius), border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5)),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============= MAIN SCREEN =============
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int currentIndex = 0;
  final repo = SupabaseRepository();
  bool isAdmin = false;

  final List<Widget> screens = const [
    ProfileScreen(),
    RoomsScreen(),
    PrivateChatsScreen(),
    MyRoomScreen(),
  ];

  final List<String> titles = ['حسابي', 'الغرف', 'الخاص', 'غرفتي'];

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final admin = await repo.isCurrentUserAdmin();
    if (mounted) setState(() => isAdmin = admin);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      drawer: AppDrawer(isAdmin: isAdmin),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(titles[currentIndex], style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
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
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'حسابي'),
              BottomNavigationBarItem(icon: Icon(Icons.forum_rounded), label: 'الغرف'),
              BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_rounded), label: 'الخاص'),
              BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings_rounded), label: 'غرفتي'),
            ],
          ),
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
      backgroundColor: Colors.transparent,
      child: AppBackground(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              child: GlassCard(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.button, AppColors.button.withOpacity(0.7)]),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.forum_rounded, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(AppConfig.appName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.button)),
                ]),
              ),
            ),
            if (isAdmin)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.button),
                title: const Text('لوحة التحكم', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanel()));
                },
              ),
            ListTile(
              leading: const Icon(Icons.add_home_work_outlined, color: AppColors.icon),
              title: const Text('طلب إنشاء غرفة'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateRoomRequestScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.icon),
              title: const Text('سياسة الخصوصية'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline_rounded, color: AppColors.icon),
              title: const Text('تواصل معنا'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactUsScreen()));
              },
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '© ${AppConfig.copyrightYear} ${AppConfig.copyrightName}. جميع الحقوق محفوظة',
                style: TextStyle(color: AppColors.textLight.withOpacity(0.7), fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<List<RoomModel>>(
        stream: repo.getRoomsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.button));
          }
          if (snapshot.hasError) return Center(child: Text('خطأ: ${snapshot.error}'));
          final rooms = snapshot.data?? [];
          if (rooms.isEmpty) return const Center(child: Text('لا توجد غرف حالياً'));
          
          // فصل الغرفة الرسمية المثبتة
          final pinnedRooms = rooms.where((r) => r.roomType == 'official').toList();
          final normalRooms = rooms.where((r) => r.roomType!= 'official').toList();
          
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
             ...pinnedRooms.map((room) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: buildOfficialRoomCard(context, room),
              )),
             ...normalRooms.map((room) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: buildUserRoomCard(context, room),
              )),
            ],
          );
        },
      ),
    );
  }

  Widget buildOfficialRoomCard(BuildContext context, RoomModel room) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(room: room))),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(colors: [Color(0xFF2C1810), Color(0xFF4A3728), Color(0xFF6B4F3A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [BoxShadow(color: AppColors.officialGold.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
          border: Border.all(color: AppColors.officialGold.withOpacity(0.6), width: 2),
        ),
        child: Stack(children: [
          Positioned(right: -30, top: -30, child: Icon(Icons.account_balance, size: 120, color: Colors.white.withOpacity(0.03))),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.officialGold.withOpacity(0.15), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.officialGold, width: 1.5)),
                child: const Icon(Icons.verified_rounded, size: 32, color: AppColors.officialGold),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(room.roomName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.officialGold, borderRadius: BorderRadius.circular(8)),
                      child: const Text('رسمية', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.officialWood)),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(room.description?? 'الغرفة الرسمية - أهلاً بالجميع', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                ]),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.officialGold),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget buildUserRoomCard(BuildContext context, RoomModel room) {
    return FutureBuilder<bool>(
      future: SupabaseRepository().isUserBanned(Supabase.instance.client.auth.currentUser!.id),
      builder: (context, banSnapshot) {
        final isBanned = banSnapshot.data == true;
        return GlassCard(
          onTap: isBanned
             ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حظر حسابك من دخول الغرف')))
              : () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(room: room))),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.button, AppColors.button.withOpacity(0.7)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.groups_2_rounded, color: Colors.white),
            ),
            title: Text(room.roomName, style: TextStyle(fontWeight: FontWeight.w600, color: isBanned? Colors.grey : null)),
            subtitle: Text(
              isBanned? 'محظور' : (room.description?? 'غرفة جماعية'),
              style: TextStyle(fontSize: 12, color: isBanned? Colors.red : AppColors.textLight),
            ),
            trailing: Icon(Icons.arrow_forward_ios, size: 16, color: isBanned? Colors.grey : AppColors.icon),
          ),
        );
      },
    );
  }
}

// ============= MY ROOM SCREEN =============
class MyRoomScreen extends StatefulWidget {
  const MyRoomScreen({super.key});
  @override
  State<MyRoomScreen> createState() => _MyRoomScreenState();
}

class _MyRoomScreenState extends State<MyRoomScreen> {
  final repo = SupabaseRepository();
  RoomModel? myRoom;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMyRoom();
  }

  Future<void> _loadMyRoom() async {
    setState(() => isLoading = true);
    final room = await repo.getMyRoom();
    if (mounted) setState(() {
      myRoom = room;
      isLoading = false;
    });
  }

  Future<void> _createRoom() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('إنشاء غرفة جديدة'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم الغرفة', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: descController, decoration: const InputDecoration(labelText: 'الوصف', border: OutlineInputBorder()), maxLines: 2),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              await Supabase.instance.client.from('rooms').insert({
                'room_name': nameController.text.trim(),
                'description': descController.text.trim(),
                'owner_id': Supabase.instance.client.auth.currentUser!.id,
                'room_type': 'user',
              });
              Navigator.pop(context, true);
            },
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
    if (result == true) _loadMyRoom();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (myRoom == null) {
      return Center(
        child: GlassCard(
          margin: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.add_home_work_outlined, size: 60, color: AppColors.button),
            const SizedBox(height: 16),
            const Text('لا تملك غرفة بعد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('أنشئ غرفتك الخاصة الآن', style: TextStyle(color: AppColors.textLight)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _createRoom,
              icon: const Icon(Icons.add),
              label: const Text('إنشاء غرفة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.button,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ]),
        ),
      );
    }
    return ChatScreen(room: myRoom!);
  }
}

// ============= STATIC SCREENS =============
class CreateRoomRequestScreen extends StatelessWidget {
  const CreateRoomRequestScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طلب إنشاء غرفة')),
      body: AppBackground(
        child: Center(
          child: GlassCard(
            margin: const EdgeInsets.all(24),
            child: const Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.construction, size: 60, color: AppColors.button),
              SizedBox(height: 16),
              Text('قريباً', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('هذه الميزة قيد التطوير', style: TextStyle(color: AppColors.textLight))
            ]),
          ),
        ),
      ),
    );
  }
}

// ... نهاية الكود السابق الخاص بك ..
// الجزء الأخير من الملف بعد التصحيح
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('سياسة الخصوصية'), backgroundColor: Colors.transparent),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
          children: const [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('سياسة الخصوصية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  Text('نحن في تطبيق "دردشاتي" نلتزم بحماية بياناتك الشخصية. لا يتم مشاركة بياناتك مع أي طرف ثالث، وتستخدم الصور المرفوعة فقط لأغراض العرض داخل التطبيق.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
