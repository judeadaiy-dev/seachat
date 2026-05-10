import 'widgets.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart'; // لاستخدام AppColors

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

  // قبول طلب إنشاء غرفة
  Future<void> _approveRoom(String roomId, String userId) async {
    try {
      // 1. غير حالة الغرفة لـ approved
      await supabase.from('rooms').update({'status': 'approved'}).eq('id', roomId);
      
      // 2. ضيف صاحب الطلب كـ owner للغرفة
      await supabase.from('room_members').insert({
        'room_id': roomId,
        'user_id': userId,
        'role': 'owner',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت الموافقة على الغرفة'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // رفض طلب إنشاء غرفة
  Future<void> _rejectRoom(String roomId) async {
    try {
      await supabase.from('rooms').delete().eq('id', roomId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفض الطلب'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!isAdmin) return const Scaffold(body: Center(child: Text('غير مصرح لك بدخول هذه المنطقة')));

    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      appBar: AppBar(
        title: const Text('طلبات إنشاء الغرف'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        // جيب بس الغرف اللي حالتها pending
        stream: supabase
            .from('rooms')
            .stream(primaryKey: ['id'])
            .eq('status', 'pending')
            .order('created_at'),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('خطأ: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white));

          final requests = snapshot.data!;
          
          if (requests.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 80, color: Colors.white54),
                  SizedBox(height: 16),
                  Text('لا توجد طلبات جديدة', style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, i) {
              final room = requests[i];
              return Card(
                color: Colors.white.withOpacity(0.1),
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.meeting_room, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              room['name'] ?? 'بدون اسم',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        room['description'] ?? 'لا يوجد وصف',
                        style: TextStyle(color: Colors.white.withOpacity(0.8)),
                      ),
                      const SizedBox(height: 4),
                      FutureBuilder(
                        future: supabase.from('profiles').select('name').eq('id', room['creator_id']).single(),
                        builder: (context, userSnap) {
                          return Text(
                            'بواسطة: ${userSnap.data?['name'] ?? 'مستخدم'}',
                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _approveRoom(room['id'], room['creator_id']),
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('قبول'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _rejectRoom(room['id']),
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('رفض'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
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
      ),
    );
  }
}
