import 'package:supabase_flutter/supabase_flutter.dart';
import '../models.dart';

class SupabaseRepository {
  final supabase = Supabase.instance.client;

  // ==================== Auth ====================
  Future<UserModel?> getCurrentUser() async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;
    try {
      final data = await supabase.from('profiles').select().eq('id', user.id).maybeSingle();
      if (data == null) return null;
      return UserModel.fromMap(data);
    } catch (e) {
      print('getCurrentUser error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  // ==================== Rooms ====================
  Future<List<RoomModel>> getRooms() async {
    try {
      final res = await supabase
          .from('rooms')
          .select()
          .order('is_pinned', ascending: false)
          .order('created_at', ascending: false);
      return (res as List).map((e) => RoomModel.fromMap(e)).toList();
    } catch (e) {
      print('getRooms error: $e');
      return [];
    }
  }

  Stream<List<RoomModel>> getRoomsStream() {
    return supabase
        .from('rooms')
        .stream(primaryKey: ['id'])
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: true)
        .map((list) => list.map((e) => RoomModel.fromMap(e)).toList());
  }

  Future<void> createRoom({
    required String roomName,
    String? description,
    String? imageUrl,
    bool isPrivate = false,
  }) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('rooms').insert({
      'room_name': roomName,
      'description': description,
      'image_url': imageUrl,
      'owner_id': userId,
      'is_private': isPrivate,
      'room_type': 'user',
      'is_pinned': false,
    });
  }

  Future<void> deleteRoom(String roomId) async {
    await supabase.from('messages').delete().eq('room_id', roomId);
    await supabase.from('room_members').delete().eq('room_id', roomId);
    await supabase.from('rooms').delete().eq('id', roomId);
  }

  // ==================== Messages ====================
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
      'content': message, // اذا عمودك اسمه message بدله هنا
      'topic': 'general',
      'extension': 'txt',
    });
  }

  // ==================== Profile ====================
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

  // ==================== Admin ====================
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
}
