import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart'; // لاستخدام AppColors, AppBackground, GlassCard

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
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) Navigator.pop(context);
        return;
      }
      final profile = await supabase.from('profiles').select('role').eq('id', user.id).single();
      if (mounted) {
        setState(() {
          isAdmin = profile['role'] == 'admin';
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  // دالة موحدة لتحديث بيانات المستخدمين مع معالجة الأخطاء
  Future<void> _updateUserStatus(String userId, Map<String, dynamic> updates, String message) async {
    try {
      await supabase.from('profiles').update(updates).eq('id', userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ أثناء تنفيذ العملية'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    // واجهة بسيطة في حال حاول غير المشرف الدخول (رغم حمايتنا لها في المين)
    if (!isAdmin) return const Scaffold(body: Center(child: Text('غير مصرح لك بدخول هذه المنطقة')));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('إدارة المستخدمين', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: AppBackground(
        child: SafeArea(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            // استماع حي لجميع التغييرات في جدول البروفايلات
            stream: supabase.from('profiles').stream(primaryKey: ['id']).order('created_at'),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('خطأ: ${snapshot.error}'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white));

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
                        backgroundColor: AppColors.button.withOpacity(0.2),
                        backgroundImage: (user['avatar_url'] != null && user['avatar_url'].toString().isNotEmpty)
                            ? NetworkImage(user['avatar_url'])
                            : null,
                        child: (user['avatar_url'] == null) 
                            ? Text(user['name']?[0] ?? 'U', style: const TextStyle(color: AppColors.button)) 
                            : null,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              user['name'] ?? 'مستخدم مجهول',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.button),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isUserAdmin)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.amber.shade700, borderRadius: BorderRadius.circular(8)),
                              child: const Text('مشرف', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          if (isBanned)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(Icons.block, color: Colors.red, size: 16),
                            ),
                        ],
                      ),
                      subtitle: Text(user['email'] ?? '', style: TextStyle(fontSize: 12, color: AppColors.textDark.withOpacity(0.6))),
                      trailing: isCurrentUser
                          ? const Text('أنت', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold))
                          : PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: AppColors.button),
                              onSelected: (value) {
                                switch (value) {
                                  case 'ban': _updateUserStatus(user['id'], {'is_banned': true}, 'تم حظر المستخدم'); break;
                                  case 'unban': _updateUserStatus(user['id'], {'is_banned': false}, 'تم رفع الحظر'); break;
                                  case 'make_admin': _updateUserStatus(user['id'], {'role': 'admin'}, 'تمت الترقية لمشرف'); break;
                                  case 'remove_admin': _updateUserStatus(user['id'], {'role': 'user'}, 'تمت إزالة صلاحيات المشرف'); break;
                                }
                              },
                              itemBuilder: (context) => [
                                if (!isBanned) 
                                  const PopupMenuItem(value: 'ban', child: Row(children: [Icon(Icons.block, color: Colors.red), SizedBox(width: 8), Text('حظر المستخدم')])),
                                if (isBanned) 
                                  const PopupMenuItem(value: 'unban', child: Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 8), Text('رفع الحظر')])),
                                const PopupMenuDivider(),
                                if (!isUserAdmin) 
                                  const PopupMenuItem(value: 'make_admin', child: Row(children: [Icon(Icons.admin_panel_settings, color: Colors.blue), SizedBox(width: 8), Text('ترقية لمشرف')])),
                                if (isUserAdmin) 
                                  const PopupMenuItem(value: 'remove_admin', child: Row(children: [Icon(Icons.person_remove, color: Colors.orange), SizedBox(width: 8), Text('إزالة الإشراف')])),
                              ],
                            ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
