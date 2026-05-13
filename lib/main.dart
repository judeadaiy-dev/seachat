import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'dart:async';
import 'dart:io';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://jmsmrojtlstppnpwmkkk.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imptc21yb2p0bHN0cHBucHdta2trIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4MTg2NDAsImV4cCI6MjA4ODM5NDY0MH0.j7gxr5CvrfvbJJzK_pMwVHiCE2AqpXUTThpeLEBmsos',
    authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
    realtimeClientOptions: const RealtimeClientOptions(eventsPerSecond: 10),
  );

  runApp(const MyApp());
}

class AppColors {
  static const Color button = Color(0xFF4B0082);
  static const Color primaryBlue = Color(0xFF0F172A);
  static const Color card = Color(0xFF1E293B);
  static const Color textDark = Color(0xFFF1F5F9);
  static const Color textLight = Color(0xFF94A3B8);
  static const Color error = Color(0xFFE53E3E);
  static const Color success = Color(0xFF10B981);
  static const Color online = Color(0xFF22C55E);
}

@immutable
class UserModel {
  final String id, email, name;
  final String? username, avatarUrl, bio;
  final String role;
  final bool isBanned, isOnline;
  final DateTime? lastSeen;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.username,
    this.avatarUrl,
    this.bio,
    this.role = 'user',
    this.isBanned = false,
    this.isOnline = false,
    this.lastSeen,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id']?.toString()?? '',
      email: map['email']?.toString()?? '',
      name: map['name']?.toString()?? 'مستخدم',
      username: map['username']?.toString(),
      avatarUrl: map['avatar_url']?.toString(),
      bio: map['bio']?.toString(),
      role: map['role']?.toString()?? 'user',
      isBanned: map['is_banned'] == true,
      isOnline: map['is_online'] == true,
      lastSeen: map['last_seen']!= null? DateTime.tryParse(map['last_seen']) : null,
    );
  }
}

@immutable
class RoomModel {
  final String id, roomName, ownerId;
  final String? description, imageUrl;
  final bool isPrivate, isApproved;
  final DateTime createdAt;

  const RoomModel({
    required this.id,
    required this.roomName,
    required this.ownerId,
    this.description,
    this.imageUrl,
    this.isPrivate = false,
    this.isApproved = true,
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
      isApproved: map['is_approved'] == true,
      createdAt: DateTime.tryParse(map['created_at']?.toString()?? '')?? DateTime.now(),
    );
  }
}

@immutable
class MessageModel {
  final String id, userId, text;
  final String? roomId, receiverId, mediaUrl;
  final DateTime createdAt;
  final UserModel? user;
  final bool isMe, isDeleted;
  final String messageType;

  const MessageModel({
    required this.id,
    required this.userId,
    required this.text,
    this.roomId,
    this.receiverId,
    this.mediaUrl,
    required this.createdAt,
    this.user,
    required this.isMe,
    this.isDeleted = false,
    this.messageType = 'text',
  });

  factory MessageModel.fromMap(Map<String, dynamic> map, String currentUserId) {
    final profiles = map['profiles'] as Map<String, dynamic>?;
    return MessageModel(
      id: map['id']?.toString()?? '',
      userId: map['user_id']?.toString()?? '',
      roomId: map['room_id']?.toString(),
      receiverId: map['receiver_id']?.toString(),
      mediaUrl: map['media_url']?.toString(),
      text: map['is_deleted'] == true? 'تم حذف هذه الرسالة' : map['content']?.toString()?? '',
      createdAt: DateTime.tryParse(map['created_at']?.toString()?? '')?? DateTime.now(),
      user: profiles!= null? UserModel.fromMap(profiles) : null,
      isMe: map['user_id']?.toString() == currentUserId,
      isDeleted: map['is_deleted'] == true,
      messageType: map['message_type']?.toString()?? 'text',
    );
  }
}

class SupabaseRepository {
  final supabase = Supabase.instance.client;
  final _audioRecorder = AudioRecorder();

  Future<void> updateOnlineStatus(bool isOnline) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      await supabase.from('profiles').update({
        'is_online': isOnline,
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      debugPrint('updateOnlineStatus error: $e');
    }
  }

  Future<UserModel?> getCurrentUser() async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;
    final data = await supabase.from('profiles').select().eq('id', user.id).maybeSingle();
    return data!= null? UserModel.fromMap(data) : null;
  }

  Future<UserModel?> getUserById(String userId) async {
    final data = await supabase.from('profiles').select().eq('id', userId).maybeSingle();
    return data!= null? UserModel.fromMap(data) : null;
  }

  Future<void> updateProfile({required String name, String? username, String? bio}) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('profiles').update({
      'name': name,
      'username': username,
      'bio': bio,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  Future<String?> uploadAvatar(String path) async {
    final userId = supabase.auth.currentUser!.id;
    final fileExt = path.split('.').last;
    final fileName = '$userId-${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final fileBytes = await XFile(path).readAsBytes();
    await supabase.storage.from('avatars').uploadBinary(fileName, fileBytes, fileOptions: const FileOptions(upsert: true));
    final url = supabase.storage.from('avatars').getPublicUrl(fileName);
    await supabase.from('profiles').update({'avatar_url': url}).eq('id', userId);
    return url;
  }

  Future<void> deleteAvatar() async {
    final user = await getCurrentUser();
    if (user?.avatarUrl!= null) {
      final fileName = user!.avatarUrl!.split('/').last;
      await supabase.storage.from('avatars').remove([fileName]);
    }
    await supabase.from('profiles').update({'avatar_url': null}).eq('id', supabase.auth.currentUser!.id);
  }

  Future<String> uploadChatMedia(String path, String type) async {
    final userId = supabase.auth.currentUser!.id;
    final fileExt = path.split('.').last;
    final fileName = '$type/$userId-${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final fileBytes = await File(path).readAsBytes();
    await supabase.storage.from('chat-media').uploadBinary(fileName, fileBytes);
    return supabase.storage.from('chat-media').getPublicUrl(fileName);
  }

  Future<void> startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      final tempDir = Directory.systemTemp.path;
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100),
        path: '$tempDir/audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
    } else {
      throw Exception('صلاحية المايك غير ممنوحة');
    }
  }

  Future<String?> stopRecording() async {
    final path = await _audioRecorder.stop();
    return path;
  }

  Future<bool> isRecording() async {
    return await _audioRecorder.isRecording();
  }

  Future<void> cancelRecording() async {
    if (await _audioRecorder.isRecording()) {
      final path = await _audioRecorder.stop();
      if (path!= null && await File(path).exists()) {
        await File(path).delete();
      }
    }
  }

  Future<List<RoomModel>> getMyRooms() async {
    final userId = supabase.auth.currentUser!.id;
    final res = await supabase.from('rooms').select().eq('owner_id', userId).order('created_at', ascending: false);
    return (res as List).map((e) => RoomModel.fromMap(e)).toList();
  }

  Future<List<RoomModel>> getPublicRooms() async {
    final res = await supabase.from('rooms').select().eq('is_private', false).eq('is_approved', true).order('created_at', ascending: false);
    return (res as List).map((e) => RoomModel.fromMap(e)).toList();
  }

  Future<void> createRoom({required String roomName, String? description}) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('rooms').insert({
      'room_name': roomName,
      'description': description,
      'owner_id': userId,
      'is_approved': false,
    });
  }

  Stream<List<MessageModel>> getRoomMessagesStream({required String roomId}) {
    final currentUserId = supabase.auth.currentUser!.id;
    return supabase
       .from('messages')
       .stream(primaryKey: ['id'])
       .eq('room_id', roomId)
       .order('created_at', ascending: true)
       .map((list) => list.map((e) => MessageModel.fromMap(e, currentUserId)).toList());
  }

  Stream<List<MessageModel>> getPrivateMessagesStream({required String otherUserId}) {
    final currentUserId = supabase.auth.currentUser!.id;
    return supabase
       .from('messages')
       .stream(primaryKey: ['id'])
       .order('created_at', ascending: true)
       .map((list) {
          final filtered = list.where((e) {
            final uid = e['user_id']?.toString();
            final rid = e['receiver_id']?.toString();
            return (uid == currentUserId && rid == otherUserId) ||
                   (uid == otherUserId && rid == currentUserId);
          }).toList();
          return filtered.map((e) => MessageModel.fromMap(e, currentUserId)).toList();
        });
  }

  Future<void> sendMessage({
    String? roomId,
    String? receiverId,
    String? text,
    String? mediaUrl,
    required String messageType,
  }) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('messages').insert({
      'room_id': roomId,
      'receiver_id': receiverId,
      'user_id': userId,
      'content': text?? '',
      'media_url': mediaUrl,
      'message_type': messageType,
    });
  }

  Future<void> deleteMessage(String messageId) async {
    await supabase.from('messages').update({
      'is_deleted': true,
      'content': '',
      'media_url': null,
    }).eq('id', messageId);
  }

  Future<void> updateTypingStatus({
    String? roomId,
    String? receiverId,
    required bool isTyping,
  }) async {
    try {
      final userId = supabase.auth.currentUser!.id;
      await supabase.from('typing_status').upsert({
        'room_id': roomId,
        'user_id': userId,
        'receiver_id': receiverId,
        'is_typing': isTyping,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,room_id,receiver_id');
    } catch (e) {
      debugPrint('updateTypingStatus error: $e');
    }
  }

  Stream<bool> getTypingStream({String? roomId, String? otherUserId}) {
    final currentUserId = supabase.auth.currentUser!.id;

    if (roomId!= null) {
      return supabase
         .from('typing_status')
         .stream(primaryKey: ['id'])
         .eq('room_id', roomId)
         .map((list) => list.any((e) =>
              e['is_typing'] == true &&
              e['user_id']!= currentUserId));
    } else {
      return supabase
         .from('typing_status')
         .stream(primaryKey: ['id'])
         .eq('receiver_id', currentUserId)
         .eq('user_id', otherUserId!)
         .map((list) => list.any((e) => e['is_typing'] == true));
    }
  }

  Future<void> signOut() async {
    await updateOnlineStatus(false);
    await supabase.auth.signOut();
  }
}

final repo = SupabaseRepository();
