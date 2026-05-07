import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

// ===== إعدادات Supabase =====
class SupabaseConfig {
  static const String url = 'https://jmsmrojtlstppnpwmkkk.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'; // حطه في .env أفضل
}

// ===== تهيئة Supabase - استدعيها في main() =====
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
}

// ===== الجسر الرئيسي: كل دالة = زر بالواجهة = جدول =====
class SupabaseRepository {
  final _client = Supabase.instance.client;

  // ===== جدول: users =====
  
  // LoginScreen - زر تسجيل الدخول
  Future<UserModel?> loginUser({required String email, required String password}) async {
    final res = await _client.auth.signInWithPassword(email: email, password: password);
    if (res.user == null) return null;
    return await getCurrentUser(userId: res.user!.id);
  }
  
  // ProfileScreen - تعديل البيانات
  Future<bool> updateUser({required String userId, required String name, required String email}) async {
    await _client.from('users').update({'full_name': name, 'email': email}).eq('id', userId);
    return true;
  }
  
  // ProfileScreen - جلب بياناتي
  Future<UserModel?> getCurrentUser({required String userId}) async {
    final data = await _client.from('users').select().eq('id', userId).single();
    return UserModel(id: data['id'], name: data['full_name'], username: data['username'], email: data['email']);
  }

  // ===== جدول: rooms =====
  
  // HomeScreen - عرض الغرف
  Future<List<RoomModel>> getAllActiveRooms() async {
    final data = await _client.from('rooms').select().eq('room_status', 'active');
    return data.map((e) => RoomModel(
      id: e['id'], roomName: e['room_name'], roomBio: e['room_bio'],
      roomImage: e['room_image'] ?? '', membersCount: e['members_count'],
      allowMessages: e['allow_messages'], allowMedia: e['allow_media'], roomStatus: e['room_status'],
    )).toList();
  }

  // ===== جدول: messages =====
  
  // ChatScreen - تحميل الرسائل
  Stream<List<MessageModel>> getRoomMessagesStream({required String roomId}) {
    return _client.from('messages').stream(primaryKey: ['id'])
      .eq('room_id', roomId)
      .order('created_at')
      .map((maps) => maps.map((e) => MessageModel(
        id: e['id'], text: e['message'], senderName: e['sender_id'],
        isMe: e['sender_id'] == _client.auth.currentUser?.id,
        time: e['created_at'],
      )).toList());
  }
  
  // ChatScreen - زر إرسال نص
  Future<bool> sendMessage({required String roomId, required String message}) async {
    await _client.from('messages').insert({
      'room_id': roomId,
      'sender_id': _client.auth.currentUser!.id,
      'message': message,
      'message_type': 'text',
    });
    return true;
  }

  // ChatScreen - زر إرسال صورة
  // جدول: messages + Storage Bucket: chat_images
  Future<bool> sendImageMessage({required String roomId, required File imageFile}) async {
    final userId = _client.auth.currentUser!.id;
    final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    
    // 1. ارفع الصورة لـ Storage
    await _client.storage.from('chat_images').upload(fileName, imageFile);
    final imageUrl = _client.storage.from('chat_images').getPublicUrl(fileName);
    
    // 2. احفظ الرابط في جدول messages
    await _client.from('messages').insert({
      'room_id': roomId,
      'sender_id': userId,
      'message': imageUrl,
      'message_type': 'image',
    });
    return true;
  }

  // ===== جدول: room_members =====
  
  // ChatScreen - دخول الغرفة
  Future<bool> joinRoom({required String roomId}) async {
    await _client.from('room_members').insert({
      'room_id': roomId,
      'user_id': _client.auth.currentUser!.id,
    });
    return true;
  }

  // ===== جدول: support_messages =====
  
  // ContactUsScreen - زر إرسال
  Future<bool> sendSupportMessage({required String subject, required String message}) async {
    await _client.from('support_messages').insert({
      'user_id': _client.auth.currentUser!.id,
      'subject': subject,
      'message': message,
    });
    return true;
  }

  // ===== جدول: app_settings =====
  
  // PrivacyPolicyScreen
  Future<String> getPrivacyPolicy() async {
    final data = await _client.from('app_settings').select('privacy_policy').limit(1).single();
    return data['privacy_policy'];
  }
}
