// admin.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'main.dart';
import 'widgets.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});
  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String currentAdminId = Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        title: const Text('لوحة التحكم', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.button,
          unselectedLabelColor: AppColors.textLight,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'المستخدمين'),
            Tab(icon: Icon(Icons.report), text: 'البلاغات'),
            Tab(icon: Icon(Icons.pending_actions), text: 'طلبات الغرف'),
            Tab(icon: Icon(Icons.meeting_room), text: 'كل الغرف'),
          ],
        ),
      ),
      body: TabBarView(controller: _tabController, children: [
        UsersTab(currentAdminId: currentAdminId),
        ReportsTab(currentAdminId: currentAdminId),
        RoomRequestsTab(),
        AllRoomsTab(),
      ]),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

// ============ 1. تبويب المستخدمين - خفيف ============
class UsersTab extends StatefulWidget {
  final String currentAdminId;
  const UsersTab({required this.currentAdminId});
  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  List<UserModel> users = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => loading = true);
    final res = await Supabase.instance.client.from('profiles').select().order('created_at', ascending: false).limit(50);
    setState(() {
      users = (res as List).map((e) => UserModel.fromMap(e)).toList();
      loading = false;
    });
  }

  Future<void> _toggleBan(String userId, bool isBanned) async {
    if (userId == widget.currentAdminId) return;
    await Supabase.instance.client.from('profiles').update({'is_banned':!isBanned}).eq('id', userId);
    _loadUsers();
  }

  Future<void> _toggleAdmin(String userId, String role) async {
    if (userId == widget.currentAdminId) return;
    await Supabase.instance.client.from('profiles').update({'role': role == 'admin'? 'user' : 'admin'}).eq('id', userId);
    _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, i) {
          final u = users[i];
          final isMe = u.id == widget.currentAdminId;
          return ListTile(
            leading: CircleAvatar(backgroundImage: u.avatarUrl!= null? CachedNetworkImageProvider(u.avatarUrl!) : null, child: u.avatarUrl == null? const Icon(Icons.person) : null),
            title: Row(children: [
              Text(u.name, style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
              if (u.role == 'admin') const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified, color: AppColors.button, size: 16)),
              if (isMe) Container(margin: const EdgeInsets.only(left: 4), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppColors.button, borderRadius: BorderRadius.circular(4)), child: const Text('انت', style: TextStyle(color: Colors.white, fontSize: 10))),
            ]),
            subtitle: Text(u.isBanned? 'محظور' : u.isOnline? 'نشط' : 'غير متصل', style: TextStyle(color: u.isBanned? AppColors.error : u.isOnline? AppColors.online : AppColors.textLight, fontSize: 11)),
            trailing: isMe? null : PopupMenuButton(
              icon: const Icon(Icons.more_vert, color: AppColors.textLight),
              color: AppColors.card,
              itemBuilder: (context) => [
                PopupMenuItem(child: const Text('مراسلة', style: TextStyle(color: AppColors.textDark)), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PrivateChatScreen(otherUser: u)))),
                PopupMenuItem(child: Text(u.isBanned? 'الغاء الحظر' : 'حظر', style: TextStyle(color: u.isBanned? AppColors.success : AppColors.error)), onTap: () => _toggleBan(u.id, u.isBanned)),
                PopupMenuItem(child: Text(u.role == 'admin'? 'ازالة ادمن' : 'ترقية لأدمن', style: const TextStyle(color: AppColors.button)), onTap: () => _toggleAdmin(u.id, u.role)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============ 2. تبويب البلاغات - خفيف ============
class ReportsTab extends StatefulWidget {
  final String currentAdminId;
  const ReportsTab({required this.currentAdminId});
  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  Future<void> _updateStatus(String id, String status) async {
    await Supabase.instance.client.from('reports').update({'status': status}).eq('id', id);
  }

  Future<void> _banUser(String userId) async {
    if (userId == widget.currentAdminId) return;
    await Supabase.instance.client.from('profiles').update({'is_banned': true}).eq('id', userId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client.from('reports').stream(primaryKey: ['id']).eq('status', 'pending').order('created_at').limit(20),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final reports = snapshot.data!;
        if (reports.isEmpty) return const Center(child: Text('لا توجد بلاغات', style: TextStyle(color: AppColors.textLight)));

        return ListView.builder(
          itemCount: reports.length,
          itemBuilder: (context, i) {
            final r = reports[i];
            return Card(
              color: AppColors.card,
              margin: const EdgeInsets.all(8),
              child: ListTile(
                title: Text(r['reason'], style: const TextStyle(color: AppColors.textDark, fontSize: 14)),
                subtitle: Text(timeago.format(DateTime.parse(r['created_at']), locale: 'ar'), style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.check, color: AppColors.success), onPressed: () => _updateStatus(r['id'], 'resolved')),
                  IconButton(icon: const Icon(Icons.block, color: AppColors.error), onPressed: () {
                    if (r['reported_user_id']!= null) _banUser(r['reported_user_id']);
                    _updateStatus(r['id'], 'resolved');
                  }),
                  IconButton(icon: const Icon(Icons.close, color: AppColors.textLight), onPressed: () => _updateStatus(r['id'], 'rejected')),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}

// ============ 3. طلبات الغرف - خفيف ============
class RoomRequestsTab extends StatelessWidget {
  const RoomRequestsTab({super.key});

  Future<void> _approve(String id) async {
    await Supabase.instance.client.from('rooms').update({'is_approved': true}).eq('id', id);
  }

  Future<void> _reject(String id) async {
    await Supabase.instance.client.from('rooms').delete().eq('id', id);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client.from('rooms').stream(primaryKey: ['id']).eq('is_approved', false).order('created_at'),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final rooms = snapshot.data!;
        if (rooms.isEmpty) return const Center(child: Text('لا توجد طلبات', style: TextStyle(color: AppColors.textLight)));

        return ListView.builder(
          itemCount: rooms.length,
          itemBuilder: (context, i) {
            final room = RoomModel.fromMap(rooms[i]);
            return Card(
              color: AppColors.card,
              margin: const EdgeInsets.all(8),
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: AppColors.button, child: Icon(Icons.group, color: Colors.white)),
                title: Text(room.roomName, style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
                subtitle: Text(room.description?? 'بدون وصف', style: const TextStyle(color: AppColors.textLight, fontSize: 12), maxLines: 1),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.check_circle, color: AppColors.success), onPressed: () => _approve(room.id)),
                  IconButton(icon: const Icon(Icons.cancel, color: AppColors.error), onPressed: () => _reject(room.id)),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}

// ============ 4. كل الغرف - خفيف ============
class AllRoomsTab extends StatelessWidget {
  const AllRoomsTab({super.key});

  Future<void> _deleteRoom(BuildContext context, String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('حذف الغرفة', style: TextStyle(color: AppColors.textDark)),
        content: Text('حذف "$name" نهائياً؟', style: const TextStyle(color: AppColors.textLight)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('الغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm == true) {
      await Supabase.instance.client.from('messages').delete().eq('room_id', id);
      await Supabase.instance.client.from('rooms').delete().eq('id', id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client.from('rooms').stream(primaryKey: ['id']).order('created_at', ascending: false).limit(50),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final rooms = snapshot.data!.map((e) => RoomModel.fromMap(e)).toList();

        return ListView.builder(
          itemCount: rooms.length,
          itemBuilder: (context, i) {
            final room = rooms[i];
            return ListTile(
              leading: const CircleAvatar(backgroundColor: AppColors.button, child: Icon(Icons.group, color: Colors.white)),
              title: Row(children: [
                Text(room.roomName, style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
                if (room.isPinned) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.push_pin, color: Colors.orange, size: 14)),
                if (!room.isApproved) Container(margin: const EdgeInsets.only(left: 4), padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)), child: const Text('معلق', style: TextStyle(color: Colors.white, fontSize: 9))),
              ]),
              subtitle: Text(room.roomType == 'official'? 'رسمية' : 'عامة', style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
              trailing: IconButton(icon: const Icon(Icons.delete, color: AppColors.error, size: 20), onPressed: () => _deleteRoom(context, room.id, room.roomName)),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(room: room))),
            );
          },
        );
      },
    );
  }
}
