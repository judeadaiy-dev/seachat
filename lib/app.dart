import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'main.dart';
import 'widgets.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sea Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.button, brightness: Brightness.dark),
        scaffoldBackgroundColor: AppColors.primaryBlue,
      ),
      home: const WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () {
      if (Supabase.instance.client.auth.currentUser!= null && mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthGate()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryBlue, Color(0xFF1E1B4B), AppColors.button],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppColors.button.withOpacity(0.5), blurRadius: 30, spreadRadius: 10)],
                      ),
                      child: const Icon(Icons.waves_rounded, size: 100, color: Colors.white),
                    ),
                    const SizedBox(height: 40),
                    const Text('Sea Chat', style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
                    const SizedBox(height: 12),
                    Text('تواصل بلا حدود', style: TextStyle(fontSize: 18, color: AppColors.textLight.withOpacity(0.8))),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthGate())),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.button,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 8,
                        ),
                        child: const Text('ابدأ الآن', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    repo.updateOnlineStatus(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    repo.updateOnlineStatus(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) repo.updateOnlineStatus(true);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) repo.updateOnlineStatus(false);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(backgroundColor: AppColors.primaryBlue, body: Center(child: CircularProgressIndicator()));
        }
        final session = snapshot.data?.session;
        if (session == null) return const AuthScreen();
        return FutureBuilder<UserModel?>(
          future: repo.getCurrentUser(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(backgroundColor: AppColors.primaryBlue, body: Center(child: CircularProgressIndicator()));
            }
            final user = userSnapshot.data;
            if (user == null) return const EditProfileScreen(isFirstTime: true);
            if (user.isBanned) return const BannedScreen();
            return HomeScreen(currentUser: user);
          },
        );
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _isLogin = true;

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      if (_isLogin) {
        await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        final res = await Supabase.instance.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        if (res.user!= null) {
          await Supabase.instance.client.from('profiles').insert({
            'id': res.user!.id,
            'email': res.user!.email,
            'name': res.user!.email!.split('@')[0],
          });
        }
      }
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.primaryBlue, AppColors.card]),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_rounded, size: 70, color: AppColors.button),
                  const SizedBox(height: 16),
                  Text(_isLogin? 'تسجيل الدخول' : 'حساب جديد', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 40),
                  _buildTextField(_emailController, 'الايميل', Icons.email_outlined),
                  const SizedBox(height: 16),
                  _buildTextField(_passwordController, 'كلمة السر', Icons.lock_outline, isPassword: true),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _loading? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.button,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _loading? const CircularProgressIndicator(color: Colors.white) : Text(_isLogin? 'دخول' : 'تسجيل', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => setState(() => _isLogin =!_isLogin),
                    child: Text(_isLogin? 'ماعندك حساب؟ سجل الآن' : 'عندك حساب؟ سجل دخول', style: const TextStyle(color: AppColors.textLight)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: AppColors.textDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textLight),
        prefixIcon: Icon(icon, color: AppColors.textLight),
        filled: true,
        fillColor: AppColors.primaryBlue.withOpacity(0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final UserModel currentUser;
  const HomeScreen({super.key, required this.currentUser});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        title: const Text('Sea Chat', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.settings, color: AppColors.textDark), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: widget.currentUser.id, isMe: true)))),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.button,
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: AppColors.button,
          tabs: const [Tab(text: 'غرفتي'), Tab(text: 'المجتمع')],
        ),
      ),
      body: TabBarView(controller: _tabController, children: [MyRoomsTab(), PublicRoomsTab()]),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.button,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateRoomScreen())),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class MyRoomsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RoomModel>>(
      future: repo.getMyRooms(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final rooms = snapshot.data!;
        if (rooms.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.meeting_room_outlined, size: 80, color: AppColors.textLight.withOpacity(0.3)), const SizedBox(height: 16), const Text('لم تنشئ أي غرفة بعد', style: TextStyle(color: AppColors.textLight))]));
        return ListView.builder(padding: const EdgeInsets.only(top: 8), itemCount: rooms.length, itemBuilder: (context, i) => RoomTile(room: rooms[i]));
      },
    );
  }
}

class PublicRoomsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RoomModel>>(
      future: repo.getPublicRooms(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final rooms = snapshot.data!;
        if (rooms.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.public_off, size: 80, color: AppColors.textLight.withOpacity(0.3)), const SizedBox(height: 16), const Text('لا توجد غرف عامة', style: TextStyle(color: AppColors.textLight))]));
        return ListView.builder(padding: const EdgeInsets.only(top: 8), itemCount: rooms.length, itemBuilder: (context, i) => RoomTile(room: rooms[i]));
      },
    );
  }
}

class RoomTile extends StatelessWidget {
  final RoomModel room;
  const RoomTile({required this.room});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(radius: 28, backgroundImage: room.imageUrl!= null? CachedNetworkImageProvider(room.imageUrl!) : null, backgroundColor: AppColors.button, child: room.imageUrl == null? const Icon(Icons.group, color: Colors.white) : null),
        title: Row(children: [
          Expanded(child: Text(room.roomName, style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 16))),
          if (!room.isApproved) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(6)), child: const Text('قيد المراجعة', style: TextStyle(color: Colors.white, fontSize: 10))),
        ]),
        subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text(room.description?? 'لا يوجد وصف', style: const TextStyle(color: AppColors.textLight, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(room: room))),
      ),
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.block, size: 100, color: AppColors.error),
            const SizedBox(height: 24),
            const Text('تم حظر حسابك', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            const SizedBox(height: 8),
            const Text('تواصل مع الادارة لمعرفة السبب', style: TextStyle(color: AppColors.textLight)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => repo.signOut(),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.button, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('تسجيل خروج', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ]),
        ),
      ),
    );
  }
}
