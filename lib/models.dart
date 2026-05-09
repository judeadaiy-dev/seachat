class UserModel {
  final String id;
  final String name;
  final String? avatarUrl;
  final String email;
  final String role;
  final bool isBanned;

  const UserModel({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.email,
    this.role = 'user',
    this.isBanned = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? json['username'] ?? 'User',
      avatarUrl: json['avatar_url'],
      email: json['email'] ?? '',
      role: json['role'] ?? 'user',
      isBanned: json['is_banned'] ?? false,
    );
  }
}

class RoomModel {
  final String id;
  final String roomName;
  final String? description;
  final String? imageUrl;
  final String creatorId;
  final bool isPrivate;
  final String roomType;
  final bool isPinned;

  const RoomModel({
    required this.id,
    required this.roomName,
    this.description,
    this.imageUrl,
    required this.creatorId,
    this.isPrivate = false,
    this.roomType = 'user',
    this.isPinned = false,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      id: json['id'] ?? '',
      roomName: json['room_name'] ?? json['name'] ?? '',
      description: json['description'],
      imageUrl: json['image_url'],
      creatorId: json['creator_id'] ?? '',
      isPrivate: json['is_private'] ?? false,
      roomType: json['room_type'] ?? 'user',
      isPinned: json['is_pinned'] ?? false,
    );
  }
}

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
    this.isMe = false,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json, String currentUserId) {
    return MessageModel(
      id: json['id'] ?? '',
      roomId: json['room_id'] ?? '',
      userId: json['user_id'] ?? '',
      text: json['content'] ?? json['text'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      userName: json['profiles']?['name'] ?? json['profiles']?['username'],
      userAvatar: json['profiles']?['avatar_url'],
      isMe: json['user_id'] == currentUserId,
    );
  }
}

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

  factory RoomMemberModel.fromJson(Map<String, dynamic> json, Map<String, dynamic>? profile) {
    return RoomMemberModel(
      userId: json['user_id'] ?? '',
      roomId: json['room_id'] ?? '',
      role: json['role'] ?? 'member',
      points: json['points'] ?? 0,
      user: profile != null ? UserModel.fromJson(profile) : null,
    );
  }
}
