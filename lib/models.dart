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
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      username: map['username'] as String? ?? '',
      email: map['email'] as String? ?? '',
      avatarUrl: map['avatar_url'] as String?,
    );
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
      id: map['id'] as String? ?? '',
      roomName: map['room_name'] as String? ?? '',
      roomBio: map['room_bio'] as String? ?? '',
      roomImage: map['room_image'] as String? ?? '',
      membersCount: (map['members_count'] as num?)?.toInt() ?? 0,
      allowMessages: map['allow_messages'] as bool? ?? true,
      allowMedia: map['allow_media'] as bool? ?? true,
      roomStatus: map['room_status'] as String? ?? 'active',
    );
  }
}

class MessageModel {
  final String id;
  final String text;
  final String senderName;
  final String time;
  final bool isMe;

  const MessageModel({
    required this.id,
    required this.text,
    required this.senderName,
    required this.isMe,
    required this.time,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map, {required String currentUserId}) {
    final senderId = map['sender_id'] as String? ?? '';
    final createdAt = DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now();
    return MessageModel(
      id: map['id'] as String? ?? '',
      text: map['text'] as String? ?? '',
      senderName: map['sender_name'] as String? ?? 'مجهول',
      isMe: senderId == currentUserId,
      time: '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
    );
  }
}
