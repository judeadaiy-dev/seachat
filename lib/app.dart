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
  final String id;
  final String email;
  final String name;
  final String? username;
  final String? avatarUrl;
  final String? bio;
  final String? zodiac;
  final String role;
  final bool isBanned;
  final DateTime? updatedAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.username,
    this.avatarUrl,
    this.bio,
    this.zodiac,
    this.role = 'user',
    this.isBanned = false,
    this.updatedAt,
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
  final String id;
  final String roomName;
  final String? description;
  final String? imageUrl;
  final String ownerId;
  final bool isPrivate;
  final String roomType;
  final bool isPinned;
  final DateTime createdAt;

  const RoomModel({
    required this.id,
    required this.roomName,
    this.description,
    this.imageUrl,
    required this.ownerId,
    this.isPrivate = false,
    this.roomType = 'user',
    this.isPinned = false,
    required this.createdAt,
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
  final String id;
  final String roomId;
  final String userId;
  final String text;
  final DateTime createdAt;
  final String? userName;
  final String? userAvatar;
  final bool isMe;

  const MessageModel({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.text,
    required this.createdAt,
    this.userName,
    this.userAvatar,
    required this.isMe,
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
  final String userId;
  final String roomId;
  final String role;
  final int points;
  final UserModel? user;

  const RoomMemberModel({
    required this.userId,
    required this.roomId,
    required this.role,
    this.points = 0,
    this.user,
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

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

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
    return supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
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
// باقي الشاشات هنا: AuthScreen, HomeScreen, ChatScreen, CreateRoomScreen...
// بس خليهم كلهم بهذا الملف
