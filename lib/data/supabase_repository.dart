import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
      return UserModel.fromJson({...data, 'email': user.email ?? ''});
    } catch (e) {
      return null;
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email']);
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) throw Exception('تم إلغاء تسجيل الدخول');
      
      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;
      if (accessToken == null || idToken == null) {
        throw Exception('فشل الحصول على التوكن');
      }
      
      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } catch (e) {
      rethrow;
    }
  }

  // ==================== Rooms ====================
  Stream<List<RoomModel>> getRoomsStream() {
    return supabase
        .from('rooms')
        .stream(primaryKey: ['id'])
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false)
        .map((list) => list.map((e) => RoomModel.fromJson(e)).toList());
  }

  Future<void> deleteRoom(String roomId) async {
    // حذف الرسائل اولاً بسبب Foreign Key
    await supabase.from('messages').delete().eq('room_id', roomId);
    await supabase.from('room_members').delete().eq('room_id', roomId);
    await supabase.from('rooms').delete().eq('id', roomId);
  }

  // ==================== Room Members ====================
  Future<List<RoomMemberModel>> getRoomMembers(String roomId) async {
    final members = await supabase
        .from('room_members')
        .select('*, profiles(*)')
        .eq('room_id', roomId)
        .order('points', ascending: false);
    
    return members.map((m) {
      final profile = m['profiles'] as Map<String, dynamic>?;
      return RoomMemberModel.fromJson(m, profile);
    }).toList();
  }

  Future<void> joinRoom(String roomId) async {
    final userId = supabase.auth.currentUser!.id;
    // تحقق اذا موجود مسبقاً
    final exists = await supabase
        .from('room_members')
        .select()
        .eq('room_id', roomId)
        .eq('user_id', userId)
        .maybeSingle();
    
    if (exists == null) {
      await supabase.from('room_members').insert({
        'room_id': roomId,
        'user_id': userId,
        'role': 'member',
        'points': 0,
      });
    }
  }

  Future<void> leaveRoom(String roomId) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('room_members').delete().eq('room_id', roomId).eq('user_id', userId);
  }

  Future<void> kickMember(String roomId, String userId) async {
    await supabase.from('room_members').delete().eq('room_id', roomId).eq('user_id', userId);
  }

  // ==================== Messages ====================
  Stream<List<MessageModel>> getRoomMessagesStream({required String roomId}) {
    final currentUserId = supabase.auth.currentUser!.id;
    return supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: false)
        .map((list) => list.map((e) => MessageModel.fromJson(e, currentUserId)).toList());
  }

  Future<void> sendMessage({required String roomId, required String message}) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('messages').insert({
      'room_id': roomId,
      'user_id': userId,
      'content': message,
    });
  }

  // ==================== Points System ====================
  Future<void> incrementPoints({required String roomId, required String userId}) async {
    // لازم تكون معرف دالة RPC في Supabase
    await supabase.rpc('increment_points', params: {
      'room_id_param': roomId,
      'user_id_param': userId,
    });
  }

  // ==================== Admin ====================
  Future<bool> isAdmin() async {
    final user = supabase.auth.currentUser;
    if (user == null) return false;
    try {
      final profile = await supabase.from('profiles').select('role').eq('id', user.id).maybeSingle();
      return profile?['role'] == 'admin';
    } catch (e) {
      return false;
    }
  }

  Future<bool> isRoomOwner(String roomId) async {
    final userId = supabase.auth.currentUser!.id;
    try {
      final member = await supabase
          .from('room_members')
          .select('role')
          .eq('room_id', roomId)
          .eq('user_id', userId)
          .maybeSingle();
      return member?['role'] == 'owner';
    } catch (e) {
      return false;
    }
  }

  Future<void> banUser(String userId) async {
    await supabase.from('profiles').update({'is_banned': true}).eq('id', userId);
    // اطرد من كل الغرف
    await supabase.from('room_members').delete().eq('user_id', userId);
  }

  Future<void> unbanUser(String userId) async {
    await supabase.from('profiles').update({'is_banned': false}).eq('id', userId);
  }

  Future<void> makeAdmin(String userId) async {
    await supabase.from('profiles').update({'role': 'admin'}).eq('id', userId);
  }

  Future<void> removeAdmin(String userId) async {
    await supabase.from('profiles').update({'role': 'user'}).eq('id', userId);
  }

  // ==================== Profile ====================
  Future<void> updateProfile({String? name, String? avatarUrl}) async {
    final userId = supabase.auth.currentUser!.id;
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (updates.isNotEmpty) {
      await supabase.from('profiles').update(updates).eq('id', userId);
    }
  }
}
