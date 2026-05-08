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
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data != null) {
        return UserModel.fromMap(data);
      }
    } catch (_) {
      // تجاهل الخطأ وكمل للـ fallback
    }

    // Fallback اذا مافي بيانات بجدول users
    final metadata = user.userMetadata ?? {};
    final email = user.email ?? '';
    
    return UserModel(
      id: user.id,
      name: metadata['full_name'] as String? ?? 
            email.split('@').first ?? 
            'مستخدم',
      username: email.split('@').first.isNotEmpty 
            ? email.split('@').first 
            : 'user_${user.id.substring(0, 6)}',
      email: email,
      avatarUrl: metadata['avatar_url'] as String?,
    );
  }

  Future<List<RoomModel>> getAllActiveRooms() async {
    try {
      final data = await _client
          .from('rooms')
          .select()
          .eq('room_status', 'active')
          .order('created_at', ascending: false);

      return (data as List)
          .map((e) => RoomModel.fromMap(e as Map<String, dynamic>))
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
        .map((data) => data
            .map((e) => MessageModel.fromMap(
                  e as Map<String, dynamic>,
                  currentUserId: userId,
                ))
            .toList());
  }

  Future<void> sendMessage({
    required String roomId,
    required String message,
  }) async {
    if (message.trim().isEmpty) return;
    
    final user = await getCurrentUser();
    if (user == null) return;

    await _client.from('messages').insert({
      'id': _uuid.v4(),
      'room_id': roomId,
      'sender_id': user.id,
      'sender_name': user.name.isNotEmpty ? user.name : 'مستخدم',
      'text': message.trim(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> sendImageMessage({
    required String roomId,
    required File imageFile,
  }) async {
    final user = await getCurrentUser();
    if (user == null) return;
    
    try {
      final fileExt = imageFile.path.split('.').last;
      final fileName = '${_uuid.v4()}.$fileExt';
      final filePath = 'public/$fileName';

      await _client.storage
          .from('chat_images')
          .upload(filePath, imageFile);

      final imageUrl = _client.storage
          .from('chat_images')
          .getPublicUrl(filePath);

      await _client.from('messages').insert({
        'id': _uuid.v4(),
        'room_id': roomId,
        'sender_id': user.id,
        'sender_name': user.name.isNotEmpty ? user.name : 'مستخدم',
        'text': imageUrl,
        'image_url': imageUrl,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // لو فشل رفع الصورة ما يكرش التطبيق
      return;
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
