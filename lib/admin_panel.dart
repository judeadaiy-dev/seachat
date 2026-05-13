import 'package:flutter/material.dart';
import 'app.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});
  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String currentAdminId = Supabase.instance.client.auth.currentUser!.id;

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
        title: Text('لوحة التحكم', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.button,
          unselectedLabelColor: AppColors.textLight,
          isScrollable: true,
          tabs: [
            Tab(icon: Icon(Icons.people), text: 'المستخدمين'),
            Tab(icon: Icon(Icons.report), text: 'البلاغات'),
            Tab(icon: Icon(Icons.pending_actions), text: 'طلبات الغرف'),
            Tab(icon: Icon(Icons.meeting_room), text: 'كل الغرف'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          UsersTab(currentAdminId: currentAdminId),
          ReportsTab(currentAdminId: currentAdminId),
          RoomRequestsTab(),
          AllRoomsTab(),
        ],
      ),
    );
  }
}

// ==================== 1. تبويب المستخدمين ====================
class UsersTab extends StatefulWidget {
  final String currentAdminId;
  const UsersTab({required this.currentAdminId});
  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  List<UserModel> users = [];
  List<UserModel> filteredUsers = [];
  bool loading = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => loading = true);
    final res = await Supabase.instance.client.from('profiles').select().order('created_at', ascending: false);
    setState(() {
      users = (res as List).map((e) => UserModel.fromMap(e)).toList();
      filteredUsers = users;
      loading = false;
    });
  }

  void _filterUsers(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredUsers = users;
      } else {
        filteredUsers = users.where((u) => 
          u.name.toLowerCase().contains(query.toLowerCase()) ||
          u.email.toLowerCase().contains(query.toLowerCase()) ||
          (u.username?.toLowerCase().contains(query.toLowerCase())?? false)
        ).toList();
      }
    });
  }

  Future<void> _banUser(String userId, bool isBanned) async {
    if (userId == widget.currentAdminId) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('لا يمكنك حظر نفسك'), backgroundColor: AppColors.error));
      return;
    }
    await Supabase.instance.client.from('profiles').update({'is_banned':!isBanned}).eq('id', userId);
    _loadUsers();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isBanned? 'تم الغاء الحظر' : 'تم حظر المستخدم'), backgroundColor: AppColors.success));
  }

  Future<void> _makeAdmin(String userId, String currentRole) async {
    if (userId == widget.currentAdminId) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('انت ادمن بالفعل'), backgroundColor: AppColors.error));
      return;
    }
    final newRole = currentRole == 'admin'? 'user' : 'admin';
    await Supabase.instance.client.from('profiles').update({'role': newRole}).eq('id', userId);
    _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return Center(child: CircularProgressIndicator());
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(12),
          child: TextField(
            onChanged: _filterUsers,
            style: TextStyle(color: AppColors.textDark),
            decoration: InputDecoration(
              hintText: 'بحث بالاسم او الايميل...',
              hintStyle: TextStyle(color: AppColors.textLight),
              prefixIcon: Icon(Icons.search, color: AppColors.textLight),
              filled: true,
              fillColor: AppColors.card,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text('اجمالي المسجلين: ${filteredUsers.length}', style: TextStyle(color: AppColors.textLight, fontSize: 12)),
            ],
          ),
        ),
        SizedBox(height: 8),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadUsers,
            child: ListView.builder(
              itemCount: filteredUsers.length,
              itemBuilder: (context, i) {
                final user = filteredUsers[i];
                final isMe = user.id == widget.currentAdminId;
                return Card(
                  color: AppColors.card,
                  margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          backgroundImage: user.avatarUrl!= null? CachedNetworkImageProvider(user.avatarUrl!) : null,
                          child: user.avatarUrl == null? Icon(Icons.person) : null,
                        ),
                        if (user.isOnline) Positioned(bottom: 0, right: 0, child: Container(width: 12, height: 12, decoration: BoxDecoration(color: AppColors.online, shape: BoxShape.circle, border: Border.all(color: AppColors.card, width: 2)))),
                      ],
                    ),
                    title: Row(
                      children: [
                        Text(user.name, style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
                        if (user.role == 'admin') SizedBox(width: 6),
                        if (user.role == 'admin') Icon(Icons.verified, color: AppColors.button, size: 16),
                        if (isMe) SizedBox(width: 6),
                        if (isMe) Container(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppColors.button, borderRadius: BorderRadius.circular(4)), child: Text('انت', style: TextStyle(color: Colors.white, fontSize: 10))),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.email, style: TextStyle(color: AppColors.textLight, fontSize: 12)),
                        Text(user.isBanned? 'محظور' : user.isOnline? 'نشط الآن' : user.lastSeen!= null? 'آخر ظهور ${timeago.format(user.lastSeen!, locale: 'ar')}' : 'غير متصل', 
                          style: TextStyle(color: user.isBanned? AppColors.error : user.isOnline? AppColors.online : AppColors.textLight, fontSize: 11)),
                      ],
                    ),
                    trailing: PopupMenuButton(
                      icon: Icon(Icons.more_vert, color: AppColors.textLight),
                      color: AppColors.card,
                      itemBuilder: (context) => [
                        PopupMenuItem(child: Row(children: [Icon(Icons.person, size: 18, color: AppColors.textDark), SizedBox(width: 8), Text('عرض البروفايل', style: TextStyle(color: AppColors.textDark))]), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: user.id)))),
                        PopupMenuItem(child: Row(children: [Icon(Icons.message, size: 18, color: AppColors.textDark), SizedBox(width: 8), Text('مراسلة', style: TextStyle(color: AppColors.textDark))]), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PrivateChatScreen(otherUser: user)))),
                        if (!isMe) PopupMenuItem(child: Row(children: [Icon(user.isBanned? Icons.lock_open : Icons.block, size: 18, color: user.isBanned? AppColors.success : AppColors.error), SizedBox(width: 8), Text(user.isBanned? 'الغاء الحظر' : 'حظر المستخدم', style: TextStyle(color: user.isBanned? AppColors.success : AppColors.error))]), onTap: () => _banUser(user.id, user.isBanned)),
                        if (!isMe) PopupMenuItem(child: Row(children: [Icon(Icons.admin_panel_settings, size: 18, color: AppColors.button), SizedBox(width: 8), Text(user.role == 'admin'? 'ازالة ادمن' : 'ترقية لأدمن', style: TextStyle(color: AppColors.button))]), onTap: () => _makeAdmin(user.id, user.role)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ==================== 2. تبويب البلاغات والشكاوي ====================
class ReportsTab extends StatefulWidget {
  final String currentAdminId;
  const ReportsTab({required this.currentAdminId});
  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  Future<void> _updateReportStatus(String reportId, String status) async {
    await Supabase.instance.client.from('reports').update({'status': status}).eq('id', reportId);
  }

  Future<void> _banReportedUser(String userId) async {
    if (userId == widget.currentAdminId) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('لا يمكنك حظر نفسك'), backgroundColor: AppColors.error));
      return;
    }
    await Supabase.instance.client.from('profiles').update({'is_banned': true}).eq('id', userId);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حظر المستخدم'), backgroundColor: AppColors.success));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client.from('reports').stream(primaryKey: ['id']).order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
        final reports = snapshot.data!;
        if (reports.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle, size: 64, color: AppColors.success), SizedBox(height: 16), Text('لا توجد بلاغات', style: TextStyle(color: AppColors.textLight))]));
        
        return ListView.builder(
          itemCount: reports.length,
          itemBuilder: (context, i) {
            final report = reports[i];
            final status = report['status']?? 'pending';
            return FutureBuilder(
              future: Future.wait([
                repo.getUserById(report['reporter_id']),
                report['reported_user_id']!= null? repo.getUserById(report['reported_user_id']) : Future.value(null),
                report['message_id']!= null? Supabase.instance.client.from('messages').select('*, profiles(*)').eq('id', report['message_id']).maybeSingle() : Future.value(null),
              ]),
              builder: (context, snap) {
                if (!snap.hasData) return SizedBox();
                final reporter = snap.data![0] as UserModel?;
                final reported = snap.data![1] as UserModel?;
                final messageData = snap.data![2] as Map<String, dynamic>?;
                
                return Card(
                  color: AppColors.card,
                  margin: EdgeInsets.all(12),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: status == 'pending'? Colors.orange : status == 'resolved'? AppColors.success : AppColors.error, borderRadius: BorderRadius.circular(12)), child: Text(status == 'pending'? 'قيد المراجعة' : status == 'resolved'? 'تم الحل' : 'مرفوض', style: TextStyle(color: Colors.white, fontSize: 10))),
                            Spacer(),
                            Text(timeago.format(DateTime.parse(report['created_at']), locale: 'ar'), style: TextStyle(color: AppColors.textLight, fontSize: 11)),
                          ],
                        ),
                        SizedBox(height: 12),
                        if (reporter!= null) ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(backgroundImage: reporter.avatarUrl!= null? CachedNetworkImageProvider(reporter.avatarUrl!) : null, radius: 20),
                          title: Text('المبلغ: ${reporter.name}', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(reporter.email, style: TextStyle(color: AppColors.textLight, fontSize: 12)),
                          trailing: IconButton(icon: Icon(Icons.message, color: AppColors.button), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PrivateChatScreen(otherUser: reporter)))),
                        ),
                        if (reported!= null) ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(backgroundImage: reported.avatarUrl!= null? CachedNetworkImageProvider(reported.avatarUrl!) : null, radius: 20),
                          title: Text('المبلغ عنه: ${reported.name}', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(reported.email, style: TextStyle(color: AppColors.textLight, fontSize: 12)),
                        ),
                        if (messageData!= null) Container(
                          margin: EdgeInsets.only(top: 8),
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppColors.primaryBlue, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.error.withOpacity(0.3))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('الرسالة المبلغ عنها:', style: TextStyle(color: AppColors.textLight, fontSize: 11)),
                              SizedBox(height: 4),
                              Text(messageData['content']?? 'رسالة محذوفة', style: TextStyle(color: AppColors.textDark)),
                            ],
                          ),
                        ),
                        SizedBox(height: 12),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppColors.primaryBlue, borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('سبب البلاغ:', style: TextStyle(color: AppColors.textLight, fontSize: 11)),
                              SizedBox(height: 4),
                              Text(report['reason'], style: TextStyle(color: AppColors.textDark)),
                            ],
                          ),
                        ),
                        if (status == 'pending') SizedBox(height: 12),
                        if (status == 'pending') Row(
                          children: [
                            if (reporter!= null) Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PrivateChatScreen(otherUser: reporter))),
                                icon: Icon(Icons.reply, size: 16),
                                label: Text('رد على المبلغ'),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.button),
                              ),
                            ),
                            if (reported!= null) SizedBox(width: 8),
                            if (reported!= null) Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  _banReportedUser(reported.id);
                                  _updateReportStatus(report['id'], 'resolved');
                                },
                                icon: Icon(Icons.block, size: 16),
                                label: Text('حظر المبلغ عنه'),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                              ),
                            ),
                            SizedBox(width: 8),
                            IconButton(icon: Icon(Icons.check_circle, color: AppColors.success), onPressed: () => _updateReportStatus(report['id'], 'resolved'), tooltip: 'تم الحل'),
                            IconButton(icon: Icon(Icons.cancel, color: AppColors.textLight), onPressed: () => _updateReportStatus(report['id'], 'rejected'), tooltip: 'رفض البلاغ'),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ==================== 3. طلبات انشاء الغرف ====================
class RoomRequestsTab extends StatelessWidget {
  Future<void> _approveRoom(BuildContext context, String roomId) async {
    await Supabase.instance.client.from('rooms').update({'is_approved': true}).eq('id', roomId);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم قبول الغرفة'), backgroundColor: AppColors.success));
  }

  Future<void> _rejectRoom(BuildContext context, String roomId) async {
    await Supabase.instance.client.from('rooms').delete().eq('id', roomId);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم رفض الغرفة'), backgroundColor: AppColors.error));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client.from('rooms').stream(primaryKey: ['id']).eq('is_approved', false).order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
        final rooms = snapshot.data!;
        if (rooms.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inbox, size: 64, color: AppColors.textLight), SizedBox(height: 16), Text('لا توجد طلبات غرف', style: TextStyle(color: AppColors.textLight))]));
        
        return ListView.builder(
          itemCount: rooms.length,
          itemBuilder: (context, i) {
            final room = RoomModel.fromMap(rooms[i]);
            return FutureBuilder<UserModel?>(
              future: repo.getUserById(room.ownerId),
              builder: (context, snap) {
                final owner = snap.data;
                return Card(
                  color: AppColors.card,
                  margin: EdgeInsets.all(12),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(backgroundImage: room.imageUrl!= null? CachedNetworkImageProvider(room.imageUrl!) : null, backgroundColor: AppColors.button, radius: 30),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(room.roomName, style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 18)),
                                  Text('طلب من: ${owner?.name?? 'مجهول'}', style: TextStyle(color: AppColors.textLight, fontSize: 12)),
                                  Text(timeago.format(room.createdAt, locale: 'ar'), style: TextStyle(color: AppColors.textLight, fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (room.description!= null) SizedBox(height: 12),
                        if (room.description!= null) Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppColors.primaryBlue, borderRadius: BorderRadius.circular(8)),
                          child: Text(room.description!, style: TextStyle(color: AppColors.textDark)),
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _approveRoom(context, room.id),
                                icon: Icon(Icons.check_circle),
                                label: Text('قبول'),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _rejectRoom(context, room.id),
                                icon: Icon(Icons.cancel),
                                label: Text('رفض'),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ==================== 4. كل الغرف + حذف ====================
class AllRoomsTab extends StatefulWidget {
  @override
  State<AllRoomsTab> createState() => _AllRoomsTabState();
}

class _AllRoomsTabState extends State<AllRoomsTab> {
  Future<void> _deleteRoom(BuildContext context, RoomModel room) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('حذف الغرفة', style: TextStyle(color: AppColors.textDark)),
        content: Text('هل انت متأكد من حذف "${room.roomName}"؟ سيتم حذف كل الرسائل نهائياً.', style: TextStyle(color: AppColors.textLight)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('الغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('حذف', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    
    if (confirm == true) {
      await Supabase.instance.client.from('messages').delete().eq('room_id', room.id);
      await Supabase.instance.client.from('rooms').delete().eq('id', room.id);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حذف الغرفة'), backgroundColor: AppColors.success));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client.from('rooms').stream(primaryKey: ['id']).order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
        final rooms = snapshot.data!.map((e) => RoomModel.fromMap(e)).toList();
        
        return ListView.builder(
          itemCount: rooms.length,
          itemBuilder: (context, i) {
            final room = rooms[i];
            return Card(
              color: AppColors.card,
              margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: CircleAvatar(backgroundImage: room.imageUrl!= null? CachedNetworkImageProvider(room.imageUrl!) : null, backgroundColor: AppColors.button),
                title: Row(
                  children: [
                    Text(room.roomName, style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
                    SizedBox(width: 6),
                    if (room.roomType == 'official') Icon(Icons.verified, color: AppColors.button, size: 16),
                    if (room.isPinned) Icon(Icons.push_pin, color: Colors.orange, size: 16),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(room.roomType == 'official'? 'غرفة رسمية' : 'غرفة مستخدم', style: TextStyle(color: AppColors.textLight, fontSize: 12)),
                    Text(room.isApproved? 'معتمدة' : 'بانتظار الموافقة', style: TextStyle(color: room.isApproved? AppColors.success : Colors.orange, fontSize: 11)),
                  ],
                ),
                trailing: PopupMenuButton(
                  icon: Icon(Icons.more_vert, color: AppColors.textLight),
                  color: AppColors.card,
                  itemBuilder: (context) => [
                    PopupMenuItem(child: Row(children: [Icon(Icons.visibility, size: 18, color: AppColors.textDark), SizedBox(width: 8), Text('دخول الغرفة', style: TextStyle(color: AppColors.textDark))]), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(room: room)))),
                    PopupMenuItem(child: Row(children: [Icon(Icons.delete, size: 18, color: AppColors.error), SizedBox(width: 8), Text('حذف الغرفة', style: TextStyle(color: AppColors.error))]), onTap: () => _deleteRoom(context, room)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
