import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:io';
import 'widgets.dart';
import 'admin.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );
  timeago.setLocaleMessages('ar', timeago.ArMessages());
  runApp(const MyApp());
}

class AppColors {
  static const Color primaryBlue = Color(0xFF0A1929);
  static const Color card = Color(0xFF132F4C);
  static const Color button = Color(0xFF007FFF);
  static const Color textDark = Color(0xFFE3F2FD);
  static const Color textLight = Color(0xFF90CAF9);
  static const Color success = Color(0xFF00C853);
  static const Color error = Color(0xFFFF5252);
  static const Color online = Color(0xFF00E676);
  static const Color warning = Color(0xFFFFB74D);
}

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
        fontFamily: 'Cairo',
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.card,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(color: AppColors.textDark, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        cardTheme: CardThemeData(
          color: AppColors.card,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.button,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      home: const WelcomeScreen(),
    );
  }
}

class UserModel {
  final String id;
  final String email;
  final String name;
  final String? username;
  final String? avatarUrl;
  final String? bio;
  final String role;
  final bool isOnline;
  final bool isBanned;
  final DateTime? lastSeen;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.username,
    this.avatarUrl,
    this.bio,
    required this.role,
    required this.isOnline,
    required this.isBanned,
    this.lastSeen,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      email: map['email'],
      name: map['name'],
      username: map['username'],
      avatarUrl: map['avatar_url'],
      bio: map['bio'],
      role: map['role']?? 'user',
      isOnline: map['is_online']?? false,
      isBanned: map['is_banned']?? false,
      lastSeen: map['last_seen']!= null? DateTime.parse(map['last_seen']) : null,
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

class RoomModel {
  final String id;
  final String roomName;
  final String? description;
  final String? imageUrl;
  final String ownerId;
  final String roomType;
  final bool isApproved;
  final bool isPinned;
  final DateTime createdAt;

  RoomModel({
    required this.id,
    required this.roomName,
    this.description,
    this.imageUrl,
    required this.ownerId,
    required this.roomType,
    required this.isApproved,
    required this.isPinned,
    required this.createdAt,
  });

  factory RoomModel.fromMap(Map<String, dynamic> map) {
    return RoomModel(
      id: map['id'],
      roomName: map['room_name'],
      description: map['description'],
      imageUrl: map['image_url'],
      ownerId: map['owner_id'],
      roomType: map['room_type']?? 'public',
      isApproved: map['is_approved']?? false,
      isPinned: map['is_pinned']?? false,
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

class MessageModel {
  final String id;
  final String senderId;
  final String? roomId;
  final String? receiverId;
  final String text;
  final String messageType;
  final String? mediaUrl;
  final bool isDeleted;
  final bool isSeen;
  final DateTime createdAt;
  final UserModel? user;
  bool get isMe => senderId == Supabase.instance.client.auth.currentUser?.id;

  MessageModel({
    required this.id,
    required this.senderId,
    this.roomId,
    this.receiverId,
    required this.text,
    required this.messageType,
    this.mediaUrl,
    required this.isDeleted,
    required this.isSeen,
    required this.createdAt,
    this.user,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'],
      senderId: map['sender_id'],
      roomId: map['room_id'],
      receiverId: map['receiver_id'],
      text: map['content']?? '',
      messageType: map['message_type']?? 'text',
      mediaUrl: map['media_url'],
      isDeleted: map['is_deleted']?? false,
      isSeen: map['is_seen']?? false,
      createdAt: DateTime.parse(map['created_at']),
      user: map['profiles']!= null? UserModel.fromMap(map['profiles']) : null,
    );
  }
}

class ChatRepository {
  final _supabase = Supabase.instance.client;
  final _record = AudioRecorder();
  String? _recordingPath;

  Future<UserModel?> getCurrentUser() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;
    final res = await _supabase.from('profiles').select().eq('id', userId).maybeSingle();
    return res!= null? UserModel.fromMap(res) : null;
  }

  Future<UserModel?> getUserById(String userId) async {
    final res = await _supabase.from('profiles').select().eq('id', userId).maybeSingle();
    return res!= null? UserModel.fromMap(res) : null;
  }

  Future<void> updateProfile({required String name, String? username, String? bio}) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase.from('profiles').update({'name': name, 'username': username, 'bio': bio}).eq('id', userId);
  }

  Future<String> uploadAvatar(String path) async {
    final userId = _supabase.auth.currentUser!.id;
    final bytes = await File(path).readAsBytes();
    final fileName = 'avatar_$userId.jpg';
    await _supabase.storage.from('avatars').uploadBinary(fileName, bytes, fileOptions: const FileOptions(upsert: true));
    final url = _supabase.storage.from('avatars').getPublicUrl(fileName);
    await _supabase.from('profiles').update({'avatar_url': url}).eq('id', userId);
    return url;
  }

  Future<void> deleteAvatar() async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase.from('profiles').update({'avatar_url': null}).eq('id', userId);
  }

  Future<void> signOut() async {
    await updateOnlineStatus(false);
    await _supabase.auth.signOut();
  }

  Future<void> updateOnlineStatus(bool isOnline) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    await _supabase.from('profiles').update({
      'is_online': isOnline,
      'last_seen': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  Future<List<RoomModel>> getMyRooms() async {
    final userId = _supabase.auth.currentUser!.id;
    final res = await _supabase.from('rooms').select().eq('owner_id', userId).order('created_at');
    return (res as List).map((e) => RoomModel.fromMap(e)).toList();
  }

  Future<List<RoomModel>> getPublicRooms() async {
    final res = await _supabase.from('rooms').select().eq('is_approved', true).eq('room_type', 'public').order('is_pinned', ascending: false);
    return (res as List).map((e) => RoomModel.fromMap(e)).toList();
  }

  Future<void> createRoom({required String roomName, String? description}) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase.from('rooms').insert({
      'room_name': roomName,
      'description': description,
      'owner_id': userId,
      'room_type': 'public',
      'is_approved': false,
    });
  }

  Stream<List<MessageModel>> getRoomMessagesStream({required String roomId}) {
    return _supabase
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('room_id', roomId)
      .order('created_at', ascending: false)
      .limit(100)
      .map((data) => data.map((e) => MessageModel.fromMap(e)).toList());
  }

  Stream<List<MessageModel>> getPrivateMessagesStream({required String otherUserId}) {
    final myId = _supabase.auth.currentUser!.id;
    return _supabase
      .from('messages')
      .stream(primaryKey: ['id'])
      .or('and(sender_id.eq.$myId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$myId)')
      .order('created_at', ascending: false)
      .limit(100)
      .map((data) => data.map((e) => MessageModel.fromMap(e)).toList());
  }

  Future<void> sendMessage({String? roomId, String? receiverId, String? text, String? mediaUrl, required String messageType}) async {
    final senderId = _supabase.auth.currentUser!.id;
    await _supabase.from('messages').insert({
      'sender_id': senderId,
      'room_id': roomId,
      'receiver_id': receiverId,
      'content': text,
      'media_url': mediaUrl,
      'message_type': messageType,
    });
  }

  Future<String> uploadChatMedia(String path, String type) async {
    final bytes = await File(path).readAsBytes();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${type == 'image'? 'jpg' : 'm4a'}';
    await _supabase.storage.from('chat_media').uploadBinary(fileName, bytes);
    return _supabase.storage.from('chat_media').getPublicUrl(fileName);
  }

  Future<void> deleteMessage(String messageId) async {
    await _supabase.from('messages').update({'is_deleted': true, 'content': 'تم حذف هذه الرسالة'}).eq('id', messageId);
  }

  Future<void> markMessageAsSeen(String messageId) async {
    await _supabase.from('messages').update({'is_seen': true}).eq('id', messageId);
  }

  Stream<bool> getTypingStream({String? roomId, String? otherUserId}) {
    final myId = _supabase.auth.currentUser!.id;
    if (roomId!= null) {
      return _supabase.from('typing_status').stream(primaryKey: ['id']).eq('room_id', roomId).map((data) => data.any((e) => e['user_id']!= myId && e['is_typing'] == true));
    } else {
      return _supabase.from('typing_status').stream(primaryKey: ['id']).eq('sender_id', otherUserId!).eq('receiver_id', myId).map((data) => data.any((e) => e['is_typing'] == true));
    }
  }

  Future<void> updateTypingStatus({String? roomId, String? receiverId, required bool isTyping}) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase.from('typing_status').upsert({
      'user_id': userId,
      'room_id': roomId,
      'sender_id': receiverId!= null? userId : null,
      'receiver_id': receiverId,
      'is_typing': isTyping,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> startRecording() async {
    if (await _record.hasPermission()) {
      final dir = await getTemporaryDirectory();
      _recordingPath = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _record.start(const RecordConfig(), path: _recordingPath!);
    }
  }

  Future<String?> stopRecording() async {
    await _record.stop();
    return _recordingPath;
  }
}

final repo = ChatRepository();
