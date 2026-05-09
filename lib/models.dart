import 'package:supabase_flutter/supabase_flutter.dart';

class UserModel {
  final String id;
  final String name;
  final String username;
  final String email;
  final String? avatarUrl;

  const UserModel({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    this.avatarUrl,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String??? '',
      name: map['name'] as String??? '',
      username: map['username'] as String??? '',
      email: map['email'] as String??? '',
      avatarUrl: map['avatar_url'] as String?,
    );
  }

  // مفيد لو بتسوي يوزر من Supabase Auth مباشرة
  factory UserModel.fromSupabaseUser(User user) {
    return UserModel(
      id: user.id,
      name: user.userMetadata?['name'] as String??? 'مستخدم',
      username: user.userMetadata?['username'] as String??? user.email!.split('@')[0],
      email: user.email?? '',
      avatarUrl: user.userMetadata?['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'email': email,
      'avatar_url': avatarUrl,
    };
  }
}

class RoomModel {
  final String id;
  final String roomName;
  final String roomBio;
  final String roomImage;
  final String roomStatus;
  final int membersCount;
  final bool allowMessages;
  final bool allowMedia;

  const RoomModel({
    required this.id,
    required this.roomName,
    required this.roomBio,
    required this.roomImage,
    required this.membersCount,
    required this.allowMessages,
    required this.allowMedia,
    required this.roomStatus,
  });

  factory RoomModel.fromMap(Map<String, dynamic> map) {
    return RoomModel(
      id: map['id'] as String??? '',
      roomName: map['room_name'] as String??? 'غرفة بدون اسم',
      roomBio: map['room_bio'] as String??? '',
      roomImage: map['room_image'] as String??? '',
      membersCount: (map['members_count'] as num?)?.toInt()?? 0,
      allowMessages: map['allow_messages'] as bool??? true,
      allowMedia: map['allow_media'] as bool??? true,
      roomStatus: map['room_status'] as String??? 'active',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'room_name': roomName,
      'room_bio': roomBio,
      'room_image': roomImage,
      'members_count': membersCount,
      'allow_messages': allowMessages,
      'allow_media': allowMedia,
      'room_status': roomStatus,
    };
  }
}

class MessageModel {
  final String id;
  final String text;
  final String senderId;
  final String senderName;
  final String roomId;
  final DateTime createdAt;
  final bool isMe;

  const MessageModel({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderName,
    required this.roomId,
    required this.createdAt,
    required this.isMe,
  });

  // Getter عشان يتوافق مع main.dart اللي يستخدم msg.time
  String get time =>
      '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

  factory MessageModel.fromMap(
    Map<String, dynamic> map, {
    required String currentUserId,
  }) {
    final senderId = map['sender_id'] as String??? '';
    final createdAt =
        DateTime.tryParse(map['created_at'] as String??? '')?? DateTime.now();

    return MessageModel(
      id: map['id'] as String??? '',
      text: map['text'] as String??? '',
      senderId: senderId,
      senderName: map['sender_name'] as String??? 'مجهول',
      roomId: map['room_id'] as String??? '',
      createdAt: createdAt,
      isMe: senderId == currentUserId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'sender_id': senderId,
      'sender_name': senderName,
      'room_id': roomId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
