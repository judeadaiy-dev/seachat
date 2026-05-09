import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart'; // عشان AppColors و AppBackground و GlassCard

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

  Future<void> _checkIfAdmin() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() => loading = false);
      return;
    }
    final profile = await supabase.from('profiles').select('role').eq('id', user.id).single();
    setState(() {
      isAdmin = profile['role'] == 'admin';
      loading = false;
    });
  }

  Future<void> _banUser(String userId) async {
    await supabase.from('profiles').update({'is_banned': true}).eq('id', userId);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حظر المستخدم')));
  }

  Future<void> _unbanUser(String userId) async {
    await supabase.from('profiles').update({'is_banned': false}).eq('id', userId);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفع الحظر')));
  }

  Future<void> _makeAdmin(String userId) async {
    await supabase.from('profiles').update({'role': 'admin'}).eq('id', userId);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم ترقية المستخدم لمشرف')));
  }

  Future<void> _removeAdmin(String userId) async {
    await supabase.from('profiles').update({'role': 'user'}).eq('id', userId);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إزالة صلاحيات المشرف')));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!isAdmin) return const Scaffold(body: Center(child: Text('غير مصرح')));
    return Scaffold(
        appBar: AppBar(title: const Text('لوحة التحكم')),
        body: AppBackground(
            child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: supabase.from('profiles').stream(primaryKey: ['id']).order('created_at'),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final users = snapshot.data!;
                  return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: users.length,
                      itemBuilder: (context, i) {
                        final user = users[i];
                        final isBanned = user['is_banned'] == true;
                        final isUserAdmin = user['role'] == 'admin';
                        final isCurrentUser = user['id'] == supabase.auth.currentUser?.id;
                        return GlassCard(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: user['avatar_url']!= null? NetworkImage(user['avatar_url']) : null,
                                  child: user['avatar_url'] == null? Text(user['name']?[0]?? 'U') : null,
                                ),
                                title: Row(
                                  children: [
                                    Text(user['name']?? 'مستخدم'),
                                    const SizedBox(width: 8),
                                    if (isUserAdmin) Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: AppColors.button, borderRadius: BorderRadius.circular(8)),
                                      child: const Text('مشرف', style: TextStyle(fontSize: 11, color: Colors.white)),
                                    ),
                                  ],
                                ),
                                subtitle: Text(user['email']?? ''),
                                trailing: isCurrentUser
                                 ? const Text('أنت', style: TextStyle(color: AppColors.icon))
                                  : PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'ban') _banUser(user['id']);
                                      if (value == 'unban') _unbanUser(user['id']);
                                      if (value == 'make_admin') _makeAdmin(user['id']);
                                      if (value == 'remove_admin') _removeAdmin(user['id']);
                                    },
                                    itemBuilder: (context) => [
                                      if (!isBanned) const PopupMenuItem(value: 'ban', child: Text('حظر')),
                                      if (isBanned) const PopupMenuItem(value: 'unban', child: Text('رفع الحظر', style: TextStyle(color: Colors.green))),
                                      if (!isUserAdmin) const PopupMenuItem(value: 'make_admin', child: Text('ترقية لمشرف')),
                                      if (isUserAdmin) const PopupMenuItem(value: 'remove_admin', child: Text('إزالة الإشراف', style: TextStyle(color: Colors.orange))),
                                    ],
                                  )));
                      });
                })));
  }
}
