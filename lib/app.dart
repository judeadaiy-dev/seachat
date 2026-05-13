import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';
import 'dart:async';


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
    if (state == AppLifecycleState.paused) repo.updateOnlineStatus(false);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(backgroundColor: AppColors.primaryBlue, body: Center(child: CircularProgressIndicator()));
        }
        final session = snapshot.data?.session;
        if (session == null) return AuthScreen();
        return FutureBuilder<UserModel?>(
          future: repo.getCurrentUser(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(backgroundColor: AppColors.primaryBlue, body: Center(child: CircularProgressIndicator()));
            }
            final user = userSnapshot.data;
            if (user == null) return EditProfileScreen(isFirstTime: true);
            if (user.isBanned) return BannedScreen();
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

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _signUp() async {
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم التسجيل. تحقق من ايميلك'), backgroundColor: AppColors.success));
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat_bubble, size: 80, color: AppColors.button),
              SizedBox(height: 8),
              Text('Sea Chat', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              SizedBox(height: 48),
              TextField(
                controller: _emailController,
                style: TextStyle(color: AppColors.textDark),
                decoration: InputDecoration(
                  labelText: 'الايميل', labelStyle: TextStyle(color: AppColors.textLight),
                  filled: true, fillColor: AppColors.card,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: TextStyle(color: AppColors.textDark),
                decoration: InputDecoration(
                  labelText: 'كلمة السر', labelStyle: TextStyle(color: AppColors.textLight),
                  filled: true, fillColor: AppColors.card,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading? null : _signIn,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.button, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _loading? CircularProgressIndicator(color: Colors.white) : Text('تسجيل دخول', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
              TextButton(onPressed: _loading? null : _signUp, child: Text('حساب جديد', style: TextStyle(color: AppColors.button))),
            ],
          ),
        ),
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
        title: Text('Sea Chat', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.person, color: AppColors.textDark),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: widget.currentUser.id, isMe: true))),
          ),
          IconButton(icon: Icon(Icons.logout, color: AppColors.textDark), onPressed: () => repo.signOut()),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.button,
          unselectedLabelColor: AppColors.textLight,
          tabs: [Tab(text: 'غرفتي'), Tab(text: 'المجتمع')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [MyRoomsTab(), PublicRoomsTab()],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.button,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateRoomScreen())),
        child: Icon(Icons.add, color: Colors.white),
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
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
        final rooms = snapshot.data!;
        if (rooms.isEmpty) return Center(child: Text('لم تنشئ اي غرفة بعد', style: TextStyle(color: AppColors.textLight)));
        return ListView.builder(
          itemCount: rooms.length,
          itemBuilder: (context, i) => RoomTile(room: rooms[i]),
        );
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
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
        final rooms = snapshot.data!;
        if (rooms.isEmpty) return Center(child: Text('لا توجد غرف عامة', style: TextStyle(color: AppColors.textLight)));
        return ListView.builder(
          itemCount: rooms.length,
          itemBuilder: (context, i) => RoomTile(room: rooms[i]),
        );
      },
    );
  }
}

class RoomTile extends StatelessWidget {
  final RoomModel room;
  const RoomTile({required this.room});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.card,
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(backgroundImage: room.imageUrl!= null? CachedNetworkImageProvider(room.imageUrl!) : null, backgroundColor: AppColors.button),
        title: Text(room.roomName, style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
        subtitle: Text(room.description?? '', style: TextStyle(color: AppColors.textLight), maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Icon(Icons.arrow_forward_ios, color: AppColors.textLight, size: 16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(room: room))),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final RoomModel room;
  const ChatScreen({super.key, required this.room});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgController = TextEditingController();
  Timer? _typingTimer;

  void _onTyping() {
    repo.updateTypingStatus(roomId: widget.room.id, isTyping: true);
    _typingTimer?.cancel();
    _typingTimer = Timer(Duration(seconds: 2), () {
      repo.updateTypingStatus(roomId: widget.room.id, isTyping: false);
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();
    repo.updateTypingStatus(roomId: widget.room.id, isTyping: false);
    try {
      await repo.sendMessage(roomId: widget.room.id, message: text);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الارسال')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.room.roomName, style: TextStyle(color: AppColors.textDark)),
            StreamBuilder<bool>(
              stream: repo.getTypingStream(roomId: widget.room.id),
              builder: (context, snapshot) {
                if (snapshot.data == true) return Text('يكتب الآن...', style: TextStyle(color: AppColors.success, fontSize: 12));
                return SizedBox();
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: repo.getRoomMessagesStream(roomId: widget.room.id),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                final msgs = snapshot.data!;
                return ListView.builder(
                  reverse: true,
                  itemCount: msgs.length,
                  itemBuilder: (context, i) => MessageBubble(msg: msgs[i]),
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.all(12),
            color: AppColors.card,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    onChanged: (_) => _onTyping(),
                    style: TextStyle(color: AppColors.textDark),
                    decoration: InputDecoration(
                      hintText: 'اكتب رسالتك...', hintStyle: TextStyle(color: AppColors.textLight),
                      filled: true, fillColor: AppColors.primaryBlue,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                CircleAvatar(backgroundColor: AppColors.button, child: IconButton(icon: Icon(Icons.send, color: Colors.white), onPressed: _sendMessage)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final MessageModel msg;
  const MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => msg.isMe? _showDeleteDialog(context) : _showReportDialog(context),
      child: Align(
        alignment: msg.isMe? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: EdgeInsets.all(12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: msg.isMe? AppColors.button : AppColors.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!msg.isMe) GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: msg.userId))),
                child: Text(msg.user?.name?? 'مجهول', style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              Text(msg.text, style: TextStyle(color: msg.isDeleted? AppColors.textLight : AppColors.textDark, fontStyle: msg.isDeleted? FontStyle.italic : null)),
              SizedBox(height: 4),
              Text(timeago.format(msg.createdAt, locale: 'ar'), style: TextStyle(color: AppColors.textLight, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.card,
      title: Text('حذف الرسالة', style: TextStyle(color: AppColors.textDark)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('الغاء')),
        TextButton(onPressed: () { repo.deleteMessage(msg.id); Navigator.pop(context); }, child: Text('حذف', style: TextStyle(color: AppColors.error))),
      ],
    ));
  }

  void _showReportDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.card,
      title: Text('ابلاغ عن رسالة', style: TextStyle(color: AppColors.textDark)),
      content: Text('هل تريد الابلاغ عن هذه الرسالة؟', style: TextStyle(color: AppColors.textLight)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('الغاء')),
        TextButton(onPressed: () { repo.reportUser(messageId: msg.id, reason: 'محتوى مسيء'); Navigator.pop(context); }, child: Text('ابلاغ', style: TextStyle(color: AppColors.error))),
      ],
    ));
  }
}

class ProfileScreen extends StatelessWidget {
  final String userId;
  final bool isMe;
  const ProfileScreen({required this.userId, this.isMe = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        title: Text('البروفايل', style: TextStyle(color: AppColors.textDark)),
        actions: [if (isMe) IconButton(icon: Icon(Icons.edit, color: AppColors.textDark), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfileScreen())))],
      ),
      body: FutureBuilder<UserModel?>(
        future: repo.getUserById(userId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          final user = snapshot.data!;
          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: AppColors.button,
                      backgroundImage: user.avatarUrl!= null? CachedNetworkImageProvider(user.avatarUrl!) : null,
                      child: user.avatarUrl == null? Icon(Icons.person, size: 60, color: Colors.white) : null,
                    ),
                    if (user.isOnline) Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(color: AppColors.online, shape: BoxShape.circle, border: Border.all(color: AppColors.primaryBlue, width: 3)),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(user.name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                if (user.username!= null) Text('@${user.username}', style: TextStyle(color: AppColors.textLight)),
                SizedBox(height: 8),
                if (!user.isOnline && user.lastSeen!= null) Text('آخر ظهور ${timeago.format(user.lastSeen!, locale: 'ar')}', style: TextStyle(color: AppColors.textLight, fontSize: 12)),
                if (user.isOnline) Text('نشط الآن', style: TextStyle(color: AppColors.online, fontSize: 12, fontWeight: FontWeight.bold)),
                SizedBox(height: 24),
                if (user.bio!= null) Container(
                  width: double.infinity, padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)),
                  child: Text(user.bio!, style: TextStyle(color: AppColors.textDark)),
                ),
                SizedBox(height: 16),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    if (user.age!= null) _buildChip(Icons.cake, '${user.age} سنة'),
                    if (user.gender!= null) _buildChip(Icons.wc, user.gender == 'male'? 'ذكر' : 'أنثى'),
                    if (user.zodiac!= null) _buildChip(Icons.star, user.zodiac!),
                  ],
                ),
                SizedBox(height: 24),
                if (!isMe) SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PrivateChatScreen(otherUser: user))),
                    icon: Icon(Icons.message),
                    label: Text('مراسلة'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.button, padding: EdgeInsets.all(16)),
                  ),
                ),
                if (!isMe) SizedBox(height: 8),
                if (!isMe) SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showReportUserDialog(context, user.id),
                    icon: Icon(Icons.report, color: AppColors.error),
                    label: Text('ابلاغ عن المستخدم', style: TextStyle(color: AppColors.error)),
                    style: OutlinedButton.styleFrom(padding: EdgeInsets.all(16), side: BorderSide(color: AppColors.error)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: AppColors.button),
        SizedBox(width: 4),
        Text(label, style: TextStyle(color: AppColors.textDark)),
      ]),
    );
  }

  void _showReportUserDialog(BuildContext context, String userId) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.card,
      title: Text('ابلاغ عن مستخدم', style: TextStyle(color: AppColors.textDark)),
      content: Text('هل تريد الابلاغ عن هذا المستخدم؟', style: TextStyle(color: AppColors.textLight)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('الغاء')),
        TextButton(onPressed: () { repo.reportUser(reportedUserId: userId, reason: 'سلوك مسيء'); Navigator.pop(context); }, child: Text('ابلاغ', style: TextStyle(color: AppColors.error))),
      ],
    ));
  }
}

class PrivateChatScreen extends StatefulWidget {
  final UserModel otherUser;
  const PrivateChatScreen({required this.otherUser});
  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final _msgController = TextEditingController();
  Timer? _typingTimer;

  void _onTyping() {
    repo.updateTypingStatus(receiverId: widget.otherUser.id, isTyping: true);
    _typingTimer?.cancel();
    _typingTimer = Timer(Duration(seconds: 2), () {
      repo.updateTypingStatus(receiverId: widget.otherUser.id, isTyping: false);
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();
    repo.updateTypingStatus(receiverId: widget.otherUser.id, isTyping: false);
    await repo.sendMessage(receiverId: widget.otherUser.id, message: text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(backgroundImage: widget.otherUser.avatarUrl!= null? CachedNetworkImageProvider(widget.otherUser.avatarUrl!) : null),
                if (widget.otherUser.isOnline) Positioned(
                  bottom: 0, right: 0,
                  child: Container(width: 12, height: 12, decoration: BoxDecoration(color: AppColors.online, shape: BoxShape.circle, border: Border.all(color: AppColors.card, width: 2))),
                ),
              ],
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.otherUser.name, style: TextStyle(color: AppColors.textDark, fontSize: 16)),
                StreamBuilder<bool>(
                  stream: repo.getTypingStream(otherUserId: widget.otherUser.id),
                  builder: (context, snapshot) {
                    if (snapshot.data == true) return Text('يكتب...', style: TextStyle(color: AppColors.success, fontSize: 12));
                    if (widget.otherUser.isOnline) return Text('نشط الآن', style: TextStyle(color: AppColors.online, fontSize: 12));
                    if (widget.otherUser.lastSeen!= null) return Text(timeago.format(widget.otherUser.lastSeen!, locale: 'ar'), style: TextStyle(color: AppColors.textLight, fontSize: 12));
                    return SizedBox();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: repo.getPrivateMessagesStream(otherUserId: widget.otherUser.id),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                final msgs = snapshot.data!;
                return ListView.builder(
                  reverse: true,
                  itemCount: msgs.length,
                  itemBuilder: (context, i) => MessageBubble(msg: msgs[i]),
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.all(12),
            color: AppColors.card,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    onChanged: (_) => _onTyping(),
                    style: TextStyle(color: AppColors.textDark),
                    decoration: InputDecoration(
                      hintText: 'اكتب رسالة...', hintStyle: TextStyle(color: AppColors.textLight),
                      filled: true, fillColor: AppColors.primaryBlue,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                CircleAvatar(backgroundColor: AppColors.button, child: IconButton(icon: Icon(Icons.send, color: Colors.white), onPressed: _sendMessage)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  final bool isFirstTime;
  const EditProfileScreen({this.isFirstTime = false});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  String? _gender, _zodiac;
  DateTime? _birthDate;
  String? _avatarUrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await repo.getCurrentUser();
    if (user!= null) {
      _nameController.text = user.name;
      _usernameController.text = user.username?? '';
      _bioController.text = user.bio?? '';
      _gender = user.gender;
      _zodiac = user.zodiac;
      _birthDate = user.birthDate;
      _avatarUrl = user.avatarUrl;
      setState(() {});
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image!= null) {
      setState(() => _loading = true);
      final url = await repo.uploadAvatar(image.path);
      setState(() { _avatarUrl = url; _loading = false; });
    }
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    await repo.updateProfile(
      name: _nameController.text.trim(),
      username: _usernameController.text.trim(),
      bio: _bioController.text.trim(),
      gender: _gender,
      birthDate: _birthDate,
      zodiac: _zodiac,
    );
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حفظ البروفايل'), backgroundColor: AppColors.success));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        title: Text(widget.isFirstTime? 'اكمل بروفايلك' : 'تعديل البروفايل', style: TextStyle(color: AppColors.textDark)),
        actions: [if (!widget.isFirstTime) TextButton(onPressed: _save, child: Text('حفظ', style: TextStyle(color: AppColors.button)))],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: AppColors.button,
                    backgroundImage: _avatarUrl!= null? CachedNetworkImageProvider(_avatarUrl!) : null,
                    child: _avatarUrl == null? Icon(Icons.person, size: 60, color: Colors.white) : null,
                  ),
                  CircleAvatar(backgroundColor: AppColors.button, radius: 18, child: Icon(Icons.camera_alt, size: 18, color: Colors.white)),
                ],
              ),
            ),
            SizedBox(height: 24),
            TextField(controller: _nameController, style: TextStyle(color: AppColors.textDark), decoration: _inputDec('الاسم')),
            SizedBox(height: 16),
            TextField(controller: _usernameController, style: TextStyle(color: AppColors.textDark), decoration: _inputDec('اسم المستخدم')),
            SizedBox(height: 16),
            TextField(controller: _bioController, maxLines: 3, style: TextStyle(color: AppColors.textDark), decoration: _inputDec('النبذة')),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _gender,
              decoration: _inputDec('الجنس'),
              dropdownColor: AppColors.card,
              style: TextStyle(color: AppColors.textDark),
              items: ['male', 'female'].map((e) => DropdownMenuItem(value: e, child: Text(e == 'male'? 'ذكر' : 'أنثى'))).toList(),
              onChanged: (v) => setState(() => _gender = v),
            ),
            SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final date = await showDatePicker(context: context, initialDate: _birthDate?? DateTime(2000), firstDate: DateTime(1950), lastDate: DateTime.now());
                if (date!= null) setState(() => _birthDate = date);
              },
              child: InputDecorator(
                decoration: _inputDec('تاريخ الميلاد'),
                child: Text(_birthDate!= null? DateFormat('yyyy-MM-dd').format(_birthDate!) : 'اختر التاريخ', style: TextStyle(color: AppColors.textDark)),
              ),
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _zodiac,
              decoration: _inputDec('البرج'),
              dropdownColor: AppColors.card,
              style: TextStyle(color: AppColors.textDark),
              items: ['الحمل','الثور','الجوزاء','السرطان','الأسد','العذراء','الميزان','العقرب','القوس','الجدي','الدلو','الحوت'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _zodiac = v),
            ),
            SizedBox(height: 32),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: _loading? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.button),
                child: _loading? CircularProgressIndicator(color: Colors.white) : Text('حفظ', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDec(String label) {
    return InputDecoration(
      labelText: label, labelStyle: TextStyle(color: AppColors.textLight),
      filled: true, fillColor: AppColors.card,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }
}

class CreateRoomScreen extends StatefulWidget {
  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _loading = false;

  Future<void> _create() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await repo.createRoom(roomName: _nameController.text.trim(), description: _descController.text.trim());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الانشاء')));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      appBar: AppBar(backgroundColor: AppColors.card, title: Text('انشاء غرفة', style: TextStyle(color: AppColors.textDark))),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _nameController, style: TextStyle(color: AppColors.textDark), decoration: InputDecoration(labelText: 'اسم الغرفة', filled: true, fillColor: AppColors.card, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            SizedBox(height: 16),
            TextField(controller: _descController, maxLines: 3, style: TextStyle(color: AppColors.textDark), decoration: InputDecoration(labelText: 'الوصف', filled: true, fillColor: AppColors.card, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            SizedBox(height: 24),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _loading? null : _create, style: ElevatedButton.styleFrom(backgroundColor: AppColors.button), child: Text('انشاء', style: TextStyle(color: Colors.white)))),
          ],
        ),
      ),
    );
  }
}

class BannedScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.block, size: 80, color: AppColors.error),
        SizedBox(height: 16),
        Text('تم حظر حسابك', style: TextStyle(fontSize: 24, color: AppColors.textDark, fontWeight: FontWeight.bold)),
        SizedBox(height: 24),
        ElevatedButton(onPressed: () => repo.signOut(), style: ElevatedButton.styleFrom(backgroundColor: AppColors.button), child: Text('تسجيل خروج', style: TextStyle(color: Colors.white))),
      ])),
    );
  }
}
