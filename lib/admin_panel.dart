import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  final supabase = Supabase.instance.client;
  bool isAdmin = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _checkIfAdmin();
  }

  // هذا أهم شي: يتأكد أنت مدير لو لا
  Future<void> _checkIfAdmin() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    
    final profile = await supabase
       .from('profiles')
       .select('role')
       .eq('id', user.id)
       .single();
    
    setState(() {
      isAdmin = profile['role'] == 'admin';
      loading = false;
    });
  }

  // حظر مستخدم
  Future<void> _banUser(String userId) async {
    await supabase.from('profiles').update({'is_banned': true}).eq('id', userId);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حظر المستخدم')));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return Scaffold(body: Center(child: CircularProgressIndicator()));
    
    // إذا مو مدير، اطرده
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: Text('غير مصرح')),
        body: Center(child: Text('ما عندك صلاحية لوحة التحكم', style: TextStyle(fontSize: 18))),
      );
    }

    // إذا مدير، اعرض اللوحة
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('لوحة تحكم SeaChat'),
          backgroundColor: Color(0xFF482855),
          bottom: TabBar(tabs: [
            Tab(text: 'طلبات الغرف'),
            Tab(text: 'الدعم الفني'),
            Tab(text: 'المستخدمين'),
          ]),
        ),
        backgroundColor: Color(0xFF1E1E2C),
        body: TabBarView(
          children: [
            // 1. تبويب طلبات الغرف
            _buildTicketsTab('create_room'),
            
            // 2. تبويب الدعم الفني 
            _buildTicketsTab('support'),
            
            // 3. تبويب المستخدمين
            _buildUsersTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketsTab(String type) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase.from('tickets').stream(primaryKey: ['id'])
         .eq('type', type).eq('status', 'open').order('created_at'),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
        final tickets = snapshot.data!;
        if (tickets.isEmpty) return Center(child: Text('لا توجد طلبات', style: TextStyle(color: Colors.white)));
        
        return ListView.builder(
          itemCount: tickets.length,
          itemBuilder: (context, index) {
            final ticket = tickets[index];
            return Card(
              color: Colors.grey[850],
              margin: EdgeInsets.all(8),
              child: ListTile(
                title: Text(ticket['title']?? 'بدون عنوان', style: TextStyle(color: Colors.white)),
                subtitle: Text(ticket['content'], style: TextStyle(color: Colors.grey)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: Icon(Icons.check, color: Colors.green), onPressed: () {
                      supabase.from('tickets').update({'status': 'closed'}).eq('id', ticket['id']);
                    }),
                    IconButton(icon: Icon(Icons.close, color: Colors.red), onPressed: () {
                      supabase.from('tickets').delete().eq('id', ticket['id']);
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUsersTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase.from('profiles').stream(primaryKey: ['id']).order('username'),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
        final users = snapshot.data!;
        
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              leading: CircleAvatar(child: Text(user['username']?[0]?? '?')),
              title: Text(user['username']?? 'بدون اسم', style: TextStyle(color: Colors.white)),
              subtitle: Text('الرتبة: ${user['role']} | ${user['is_banned'] == true? "محظور" : "نشط"}', 
                style: TextStyle(color: user['is_banned'] == true? Colors.red : Colors.green)),
              trailing: user['is_banned'] == true? null : IconButton(
                icon: Icon(Icons.block, color: Colors.red),
                onPressed: () => _banUser(user['id']),
              ),
            );
          },
        );
      },
    );
  }
}
