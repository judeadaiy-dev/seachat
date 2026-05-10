import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';

class SupabaseRepository {
  final supabase = Supabase.instance.client;

  // ==================== Auth (الهوية) ====================
  Future<UserModel?> getCurrentUser() async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;
    try {
      final data = await supabase.from('profiles').select().eq('id', user.id).maybeSingle();
      if (data == null) return null;
      return UserModel.fromMap(data);
    } catch (e) {
      return null;
    }
  }

  // تسجيل الدخول بجوجل (تم تعطيله مؤقتاً لتسريع التطوير)
  Future<void> signInWithGoogle() async {
    // هذه الرسالة ستظهر للمستخدم عند محاولة الضغط على الزر
    throw Exception('ميزة تسجيل جوجل ستتوفر في التحديثات القادمة');
    
    /* ملاحظة للمستقبل: عند العودة لتفعيل جوجل، سنحتاج لملف google-services.json 
    وضبط SHA-1 في Google Cloud Console لضمان عملها مع GitHub Actions.
    */
  }

  // ==================== Rooms (الغرف) ====================
  Stream<List<RoomModel>> getRoomsStream() {
    return supabase
        .from('rooms')
        .stream(primaryKey: ['id'])
        .order('is_pinned', ascending: false) 
        .order('created_at', ascending: true)
        .map((list) => list.map((e) => RoomModel.fromMap(e)).toList());
  }

  Future<void> deleteRoom(String roomId) async {
    await supabase.from('messages').delete().eq('room_id', roomId);
    await supabase.from('room_members').delete().eq('room_id', roomId);
    await supabase.from('rooms').delete().eq('id', roomId);
  }

  // ==================== Messages (الرسائل) ====================
  Stream<List<MessageModel>> getRoomMessagesStream({required String roomId}) {
    final currentUserId = supabase.auth.currentUser!.id;
    return supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: false)
        .map((list) => list.map((e) => MessageModel.fromMap(e, currentUserId)).toList());
  }

  Future<void> sendMessage({required String roomId, required String message}) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('messages').insert({
      'room_id': roomId,
      'user_id': userId,
      'message': message, 
    });
  }

  // ==================== Admin & Permissions (الإدارة) ====================
  Future<bool> isCurrentUserAdmin() async {
    final user = supabase.auth.currentUser;
    if (user == null) return false;
    final res = await supabase.from('profiles').select('role').eq('id', user.id).maybeSingle();
    return res?['role'] == 'admin';
  }

  Future<void> banUser(String userId) async {
    await supabase.from('profiles').update({'is_banned': true}).eq('id', userId);
    await supabase.from('room_members').delete().eq('user_id', userId);
  }

  // ==================== Profile (الملف الشخصي) ====================
  Future<void> updateProfile({
    required String name,
    String? username,
    String? bio,
    String? zodiac,
  }) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('profiles').update({
      'name': name,
      'username': username,
      'bio': bio,
      'zodiac': zodiac,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  Future<List<RoomMemberModel>> getRoomMembers(String roomId) async {
    final res = await supabase
        .from('room_members')
        .select('*, profiles(*)') 
        .eq('room_id', roomId)
        .order('points', ascending: false);
    return (res as List).map((m) => RoomMemberModel.fromMap(m)).toList();
  }
}
