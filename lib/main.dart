class UserModel {
  final String id;
  final String? username;
  final String? fullName;
  final String? avatarUrl;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    this.username,
    this.fullName,
    this.avatarUrl,
    this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      username: map['username'],
      fullName: map['full_name'],
      avatarUrl: map['avatar_url'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'avatar_url': avatarUrl,
    };
  }
}

class RoomModel {
  final String id;
  final String roomName;
  final String? description;
  final DateTime createdAt;
  final String? ownerId;

  RoomModel({
    required this.id,
    required this.roomName,
    this.description,
    required this.createdAt,
    this.ownerId,
  });

  factory RoomModel.fromMap(Map<String, dynamic> map) {
    return RoomModel(
      id: map['id'],
      roomName: map['name'], // التعديل المهم: room_name → name
      description: map['description'],
      createdAt: DateTime.parse(map['created_at']),
      ownerId: map['owner_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': roomName,
      'description': description,
      'owner_id': ownerId,
    };
  }
}

class PrivateMessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime createdAt;
  final bool isRead;

  PrivateMessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.createdAt,
    this.isRead = false,
  });

  factory PrivateMessageModel.fromMap(Map<String, dynamic> map) {
    return PrivateMessageModel(
      id: map['id'],
      senderId: map['sender_id'],
      receiverId: map['receiver_id'],
      content: map['content'],
      createdAt: DateTime.parse(map['created_at']),
      isRead: map['is_read'] ?? false,
    );
  }
}

class RoomMessageModel {
  final String id;
  final String roomId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final String? senderName;
  final String? senderAvatar;

  RoomMessageModel({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.senderName,
    this.senderAvatar,
  });

  factory RoomMessageModel.fromMap(Map<String, dynamic> map) {
    return RoomMessageModel(
      id: map['id'],
      roomId: map['room_id'],
      senderId: map['sender_id'],
      content: map['content'],
      createdAt: DateTime.parse(map['created_at']),
      senderName: map['profiles']?['full_name'],
      senderAvatar: map['profiles']?['avatar_url'],
    );
  }
}
