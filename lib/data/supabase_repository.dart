import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:io';

class SupabaseRepository {
  final _client = Supabase.instance.client;

  // تسجيل جوجل - جدول: auth.users + users
  Future<bool> signInWithGoogle() async {
    try {
      await _client.auth.signInWithOAuth(OAuthProvider.google);
      return true;
    } catch (e) {
      return false;
    }
  }

  // إيميل - جدول: auth.users
  Future<bool> signInWithEmail({required String email, required String password}) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      return true;
    } catch (e) {
      return false;
    }
  }

  // جدول: users
  Future<UserModel?> getCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final data = await _client.from('users').select().eq('id', user.id).single();
    return UserModel(id: data['id'], name: data['full_name'] ?? '', username: data['username'] ?? '', email: data['email'] ?? '');
  }

  // جدول: rooms
  Future<List<RoomModel>> getAllActiveRooms() async {
    final data = await _client.from('rooms').select().eq('room_status', 'active').order('created_at');
    return data.map((e) => RoomModel(
      id: e['id'], roomName: e['room_name'], roomBio: e['room_bio'] ?? '',
      roomImage: e['room_image'] ?? '', membersCount: e['members_count'] ?? 0,
      allowMessages: e['allow_messages'] ?? true, allowMedia: e['allow_media'] ?? true, roomStatus: e['room_status'],
    )).toList();
  }

  // جدول: messages - Real-time
  Stream<List<MessageModel>> getRoomMessagesStream({required String roomId}) {
    return _client.from('messages').stream(primaryKey: ['id'])
      .eq('room_id', roomId)
      .order('created_at')
      .map((maps) => maps.map((e) => MessageModel(
        id: e['id'], text: e['message'], senderName: e['sender_id'],
        isMe: e['sender_id'] == _client.auth.currentUser?.id,
        time: DateTime.parse(e['created_at']).toLocal().toString().substring(11, 16),
      )).toList());
  }

  // جدول: messages
  Future<bool> sendMessage({required String roomId, required String message}) async {
    await _client.from('messages').insert({
      'room_id': roomId,
      'sender_id': _client.auth.currentUser!.id,
      'message': message,
      'message_type': 'text',
    });
    return true;
  }

  // جدول: messages + Storage: chat_images
  Future<bool> sendImageMessage({required String roomId, required File imageFile}) async {
    final userId = _client.auth.currentUser!.id;
    final fileName = 'rooms/$roomId/${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage.from('chat_images').upload(fileName, imageFile);
    final imageUrl = _client.storage.from('chat_images').getPublicUrl(fileName);
    await _client.from('messages').insert({
      'room_id': roomId,
      'sender_id': userId,
      'message': imageUrl,
      'message_type': 'image',
    });
    return true;
  }

  // جدول: app_settings
  Future<String> getPrivacyPolicy() async {
    final data = await _client.from('app_settings').select('privacy_policy').limit(1).single();
    return data['privacy_policy'] ?? '';
  }
  
  Future<String> getSupportEmail() async {
    final data = await _client.from('app_settings').select('support_email').limit(1).single();
    return data['support_email'] ?? 'support@seachat.app';
  }
}
