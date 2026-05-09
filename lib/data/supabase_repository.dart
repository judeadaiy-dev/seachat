import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models.dart';

class SupabaseRepository {
  final supabase = Supabase.instance.client;

  Future<UserModel?> getCurrentUser() async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;
    final data = await supabase.from('profiles').select().eq('id', user.id).maybeSingle();
    if (data == null) return null;
    return UserModel.fromJson({...data, 'email': user.email?? ''});
  }

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email']);
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;
      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;
      if (accessToken == null || idToken == null) return;
      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } catch (e) {
      rethrow;
    }
  }

  Stream<List<RoomModel>> getRoomsStream() {
    return supabase
       .from('rooms')
       .stream(primaryKey: ['id'])
       .order('is_pinned', ascending: false)
       .order('created_at')
       .map((list) => list.map((e) => RoomModel.fromJson(e)).toList());
  }

  Stream<List<MessageModel>> getRoomMessagesStream({required String roomId}) {
    final currentUserId = supabase.auth.currentUser!.id;
    return supabase
       .from('messages')
       .stream(primaryKey: ['id'])
       .eq('room_id', roomId)
       .order('created_at')
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
    await supabase.from('room_members').insert({
      'room_id': roomId,
      'user_id': userId,
      'role': 'member',
      'points': 0,
    });
  }

  Future<void> leaveRoom(String roomId) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('room_members').delete().eq('room_id', roomId).eq('user_id', userId);
  }

  Future<void> banUser(String userId) async {
    await supabase.from('profiles').update({'is_banned': true}).eq('id', userId);
  }

  Future<void> kickMember(String roomId, String userId) async {
    await supabase.from('room_members').delete().eq('room_id', roomId).eq('user_id', userId);
  }

  Future<void> deleteRoom(String roomId) async {
    await supabase.from('rooms').delete().eq('id', roomId);
  }

  Future<bool> isAdmin() async {
    final user = supabase.auth.currentUser;
    if (user == null) return false;
    final profile = await supabase.from('profiles').select('role').eq('id', user.id).maybeSingle();
    return profile?['role'] == 'admin';
  }

  Future<bool> isRoomOwner(String roomId) async {
    final userId = supabase.auth.currentUser!.id;
    final member = await supabase
       .from('room_members')
       .select('role')
       .eq('room_id', roomId)
       .eq('user_id', userId)
       .maybeSingle();
    return member?['role'] == 'owner';
  }
}
