import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

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
      id: map['id']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      name: map['name']?.toString() ?? map['username']?.toString() ?? 'مستخدم',
      username: map['username']?.toString(),
      avatarUrl: map['avatar_url']?.toString(),
      bio: map['bio']?.toString(),
      zodiac: map['zodiac']?.toString(),
      role: map['role']?.toString() ?? 'user',
      isBanned: map['is_banned'] == true,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'username': username,
      'avatar_url': avatarUrl,
      'bio': bio,
      'zodiac': zodiac,
      'role': role,
      'is_banned': isBanned,
      'updated_at': updatedAt?.toIso8601String(),
    };
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
      id: map['id']?.toString() ?? '',
      roomName: map['room_name']?.toString() ?? map['name']?.toString() ?? 'غرفة',
      description: map['description']?.toString(),
      imageUrl: map['image_url']?.toString(),
      ownerId: map['owner_id']?.toString() ?? map['creator_id']?.toString() ?? '',
      isPrivate: map['is_private'] == true,
      roomType: map['room_type']?.toString() ?? 'user',
      isPinned: map['is_pinned'] == true,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
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
    final profiles = map['profiles'] as Map<String, dynamic>?;
    return MessageModel(
      id: map['id']?.toString() ?? '',
      roomId: map['room_id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      text: map['message']?.toString() ?? map['content']?.toString() ?? '',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      userName: profiles?['name']?.toString() ?? profiles?['username']?.toString() ?? 'مجهول',
      userAvatar: profiles?['avatar_url']?.toString(),
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
      userId: map['user_id']?.toString() ?? '',
      roomId: map['room_id']?.toString() ?? '',
      role: map['role']?.toString() ?? 'member',
      points: map['points'] is int ? map['points'] : int.tryParse(map['points']?.toString() ?? '0') ?? 0,
      user: profiles != null ? UserModel.fromMap(profiles) : null,
    );
  }
}
// ضيفها في نهاية lib/models.dart

@immutable
class PrivateChatsScreen extends StatelessWidget {
  const PrivateChatsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('المحادثات الخاصة - قريباً')),
    );
  }
}

@immutable  
class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key}); // لازم const عشان تحل خطأ main.dart:405
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تواصل معنا')),
      body: const Center(child: Text('صفحة التواصل')),
    );
  }
}
