import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models.dart';

class SupabaseRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final _uuid = const Uuid();

  String? get _currentUserId => _client.auth.currentUser?.id;

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return res.user != null;
    } catch (e) {
      return false;
    }
  }

  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(OAuthProvider.google);
  }

  Future<UserModel?> getCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data != null) {
        return UserModel.fromJson({...data, 'email': user.email ?? ''});
      }
    } catch (_) {}

    // Fallback اذا مافي بيانات بجدول profiles
    final metadata = user.userMetadata ?? {};
    final email = user.email ?? '';
    
    return UserModel(
      id: user.id,
      name: metadata['full_name'] as String? ?? 
            email.split('@').first ?? 
            'مستخدم',
      email: email,
      avatarUrl: metadata['avatar_url'] as String?,
      role: 'user',
    );
  }

  Future<List<RoomModel>> getAllActiveRooms() async {
    try {
      final data = await _client
          .from('rooms')
          .select()
          .order('is_pinned', ascending: false)
          .order('created_at', ascending: false);

      return (data as List)
          .map((e) => RoomModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Stream<List<MessageModel>> getRoomMessagesStream({
    required String roomId,
  }) {
    final userId = _currentUserId ?? '';
    
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: false)
        .asyncMap((data) async {
          List<MessageModel> messages = [];
          for (var e in data) {
            final profile = await _client
                .from('profiles')
                .select('username, avatar_url')
                .eq('id', e['user_id'])
                .maybeSingle();
            messages.add(MessageModel.fromJson(
              {...e, 'profiles': profile},
              userId,
            ));
          }
          return messages;
        });
  }

  Future<void> sendMessage({
    required String roomId,
    required String message,
  }) async {
    if (message.trim().isEmpty) return;
    if (_currentUserId == null) return;

    await _client.from('messages').insert({
      'id': _uuid.v4(),
      'room_id': roomId,
      'user_id': _currentUserId!,
      'text': message.trim(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> sendImageMessage({
    required String roomId,
    required File imageFile,
  }) async {
    if (_currentUserId == null) return;
    
    try {
      final fileExt = imageFile.path.split('.').last;
      final fileName = 'chat_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'public/$fileName';

      await _client.storage
          .from('chat_images')
          .upload(filePath, imageFile);

      final imageUrl = _client.storage
          .from('chat_images')
          .getPublicUrl(filePath);

      await sendMessage(roomId: roomId, message: imageUrl);
    } catch (e) {
      return;
    }
  }

  Future<List<RoomMemberModel>> getRoomMembers(String roomId) async {
    try {
      final members = await _client
          .from('room_members')
          .select()
          .eq('room_id', roomId)
          .order('points', ascending: false);
      
      List<RoomMemberModel> result = [];
      for (var m in members) {
        final profile = await _client
            .from('profiles')
            .select('username, avatar_url')
            .eq('id', m['user_id'])
            .single();
        result.add(RoomMemberModel.fromJson(m, profile));
      }
      return result;
    } catch (e) {
      return [];
    }
  }

  Future<String> getPrivacyPolicy() async {
    try {
      final data = await _client
          .from('app_settings')
          .select('value')
          .eq('key', 'privacy_policy')
          .maybeSingle();

      return data?['value'] as String? ?? 
             'سياسة الخصوصية غير متوفرة حالياً';
    } catch (_) {
      return 'سياسة الخصوصية غير متوفرة حالياً';
    }
  }
}
