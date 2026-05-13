import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

// ==================== App Colors ====================
class AppColors {
  static const Color button = Color(0xFF4B0082);
  static const Color primaryBlue = Color(0xFFD7EFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF2D3748);
  static const Color textLight = Color(0xFF718096);
  static const Color error = Color(0xFFE53E3E);
  static const Color icon = Color(0xFFAEB8A0);
}

// ==================== Models ====================
@immutable
class UserModel {
  final String id, email, name;
  final String? username, avatarUrl, bio, zodiac;
  final String role;
  final bool isBanned;
  final DateTime? updatedAt;

  const UserModel({
    required this.id, required this.email, required this.name,
    this.username, this.avatarUrl, this.bio, this.zodiac,
    this.role = 'user', this.isBanned = false, this.updatedAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id']?.toString()?? '',
      email: map['email']?.toString()?? '',
      name: map['name']?.toString()?? map['username']?.toString()?? 'مستخدم',
      username: map['username']?.toString(),
      avatarUrl: map['avatar_url']?.toString(),
      bio: map['bio']?.toString(),
      zodiac: map['zodiac']?.toString(),
      role: map['role']?.toString()?? 'user',
      isBanned: map['is_banned'] == true,
      updatedAt: map['updated_at']!= null? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }
}

@immutable
class RoomModel {
  final String id, roomName, ownerId;
  final String? description, imageUrl;
  final bool isPrivate, isPinned;
  final String roomType;
  final DateTime createdAt;

  const RoomModel({
    required this.id, required this.roomName, required this.ownerId,
    this.description, this.imageUrl, this.isPrivate = false,
    this.roomType = 'user', this.isPinned = false, required this.createdAt,
  });

  factory RoomModel.fromMap(Map<String, dynamic> map) {
    return RoomModel(
      id: map['id']?.toString()?? '',
      roomName: map['room_name']?.toString()?? 'غرفة',
      description: map['description']?.toString(),
      imageUrl: map['image_url']?.toString(),
      ownerId: map['owner_id']?.toString()?? '',
      isPrivate: map['is_private'] == true,
      roomType: map['room_type']?.toString()?? 'user',
      isPinned: map['is_pinned'] == true,
      createdAt: DateTime.tryParse(map['created_at']?.toString()?? '')?? DateTime.now(),
    );
  }
}

@immutable
class MessageModel {
  final String id, roomId, userId, text;
  final DateTime createdAt;
  final String? userName, userAvatar;
  final bool isMe;

  const MessageModel({
    required this.id, required this.roomId, required this.userId,
    required this.text, required this.createdAt,
    this.userName, this.userAvatar, required this.isMe,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map, String currentUserId) {
    return MessageModel(
      id: map['id']?.toString()?? '',
      roomId: map['room_id']?.toString()?? '',
      userId: map['user_id']?.toString()?? '',
      text: map['content']?.toString()?? map['message']?.toString()?? '',
      createdAt: DateTime.tryParse(map['created_at']?.toString()?? '')?? DateTime.now(),
      userName: 'مجهول',
      userAvatar: null,
      isMe: map['user_id']?.toString() == currentUserId,
    );
  }
}

@immutable
class RoomMemberModel {
  final String userId, roomId, role;
  final int points;
  final UserModel? user;

  const RoomMemberModel({
    required this.userId, required this.roomId, required this.role,
    this.points = 0, this.user,
  });

  factory RoomMemberModel.fromMap(Map<String, dynamic> map) {
    final profiles = map['profiles'] as Map<String, dynamic>?;
    return RoomMemberModel(
      userId: map['user_id']?.toString()?? '',
      roomId: map['room_id']?.toString()?? '',
      role: map['role']?.toString()?? 'member',
      points: map['points'] is int? map['points'] : int.tryParse(map['points']?.toString()?? '0')?? 0,
      user: profiles!= null? UserModel.fromMap(profiles) : null,
    );
  }
}

// ==================== Repository ====================
class SupabaseRepository {
  final supabase = Supabase.instance.client;

  Future<UserModel?> getCurrentUser() async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;
    try {
      final data = await supabase.from('profiles').select().eq('id', user.id).maybeSingle();
      if (data == null) return null;
      return UserModel.fromMap(data);
    } catch (e) {
      return null;
    }
  }

  Future<void> signOut() async => await supabase.auth.signOut();

  Future<List<RoomModel>> getRooms() async {
    try {
      final res = await supabase.from('rooms').select().order('is_pinned', ascending: false).order('created_at', ascending: false);
      return (res as List).map((e) => RoomModel.fromMap(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> createRoom({required String roomName, String? description}) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('rooms').insert({
      'room_name': roomName,
      'description': description,
      'owner_id': userId,
      'room_type': 'user',
      'is_private': false,
      'is_pinned': false,
    });
  }

  Stream<List<MessageModel>> getRoomMessagesStream({required String roomId}) {
    final currentUserId = supabase.auth.currentUser!.id;
    return supabase.from('messages').stream(primaryKey: ['id']).eq('room_id', roomId)
       .order('created_at', ascending: false)
       .map((list) => list.map((e) => MessageModel.fromMap(e, currentUserId)).toList());
  }

  Future<void> sendMessage({required String roomId, required String message}) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('messages').insert({
      'room_id': roomId,
      'user_id': userId,
      'content': message,
      'topic': 'general',
      'extension': 'txt',
    });
  }
}

final repo = SupabaseRepository();

// ==================== Screens ====================
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
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
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
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(controller: _emailController, decoration: InputDecoration(labelText: 'الايميل', filled: true, fillColor: Colors.white)),
            SizedBox(height: 16),
            TextField(controller: _passwordController, decoration: InputDecoration(labelText: 'كلمة السر', filled: true, fillColor: Colors.white), obscureText: true),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: _loading? null : _signIn,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.button, minimumSize: Size(double.infinity, 50)),
              child: Text('تسجيل دخول', style: TextStyle(color: Colors.white)),
            ),
            TextButton(onPressed: _loading? null : _signUp, child: Text('حساب جديد')),
          ],
        ),
      ),
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
        if (snapshot.connectionState == ConnectionState.waiting) return Scaffold(body: Center(child: CircularProgressIndicator()));
        final session = snapshot.data?.session;
        if (session == null) return AuthScreen();
        return FutureBuilder<UserModel?>(
          future: repo.getCurrentUser(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) return Scaffold(body: Center(child: CircularProgressIndicator()));
            final user = userSnapshot.data;
            if (user == null) return AuthScreen();
            if (user.isBanned) return BannedScreen();
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
        actions: [IconButton(icon: Icon(Icons.logout), onPressed: () => repo.signOut())],
      ),
      body: FutureBuilder<List<RoomModel>>(
        future: repo.getRooms(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
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

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});
  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _loading = false;

  Future<void> _createRoom() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await repo.createRoom(
        roomName: _nameController.text.trim(),
        description: _descController.text.trim().isEmpty? null : _descController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم انشاء الغرفة'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الانشاء: $e'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      appBar: AppBar(title: Text('انشاء غرفة جديدة'), backgroundColor: Colors.transparent),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'اسم الغرفة', filled: true, fillColor: Colors.white),
              validator: (v) => v!.isEmpty? 'ادخل اسم الغرفة' : null,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _descController,
              decoration: InputDecoration(labelText: 'الوصف', filled: true, fillColor: Colors.white),
              maxLines: 3,
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: _loading? null : _createRoom,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.button, minimumSize: Size(double.infinity, 50)),
              child: _loading? CircularProgressIndicator(color: Colors.white) : Text('انشاء', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
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
  final _scrollController = ScrollController();

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();
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
      appBar: AppBar(title: Text(widget.room.roomName), backgroundColor: Colors.brown.withOpacity(0.6)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: repo.getRoomMessagesStream(roomId: widget.room.id),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                final msgs = snapshot.data!;
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final msg = msgs[i];
                    return Align(
                      alignment: msg.isMe? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: EdgeInsets.all(8),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: msg.isMe? AppColors.button.withOpacity(0.9) : Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!msg.isMe) Text(msg.userName?? 'مجهول', style: TextStyle(color: Colors.amberAccent, fontSize: 11)),
                            Text(msg.text, style: TextStyle(color: Colors.white)),
                            Text(timeago.format(msg.createdAt, locale: 'ar'), style: TextStyle(color: Colors.white60, fontSize: 9)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: InputDecoration(hintText: 'اكتب رسالتك...', filled: true, fillColor: Colors.white24),
                  ),
                ),
                IconButton(icon: Icon(Icons.send, color: AppColors.button), onPressed: _sendMessage),
              ],
            ),
          ),
        ],
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block, size: 80, color: AppColors.error),
            SizedBox(height: 20),
            Text('تم حظر حسابك', style: TextStyle(fontSize: 24, color: AppColors.textLight)),
            SizedBox(height: 20),
            ElevatedButton(onPressed: () => repo.signOut(), child: Text('تسجيل الخروج')),
          ],
        ),
      ),
    );
  }
}
