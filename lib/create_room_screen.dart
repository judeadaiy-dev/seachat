import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart'; // ← هذا السطر مهم جداً عشان AppColors

class CreateRoomRequestScreen extends StatefulWidget {
  const CreateRoomRequestScreen({super.key});

  @override
  State<CreateRoomRequestScreen> createState() => _CreateRoomRequestScreenState();
}

class _CreateRoomRequestScreenState extends State<CreateRoomRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final supabase = Supabase.instance.client;
  bool _loading = false;

  Future<void> _createRoom() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final desc = _descController.text.trim();

    setState(() => _loading = true);
    try {
      final existing = await supabase
          .from('rooms')
          .select()
          .eq('creator_id', supabase.auth.currentUser!.id)
          .eq('name', name)
          .eq('status', 'pending')
          .maybeSingle();

      if (existing != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لديك طلب معلق بنفس الاسم مسبقاً'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      await supabase.from('rooms').insert({
        'name': name,
        'description': desc.isEmpty ? null : desc,
        'creator_id': supabase.auth.currentUser!.id,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال الطلب بنجاح، بانتظار موافقة المشرف'), backgroundColor: Colors.green),
        );
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الإرسال: ${e.message}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ غير متوقع، حاول مرة أخرى'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue, // ← هسه يشوفه
      appBar: AppBar(
        title: const Text('طلب إنشاء غرفة جديدة'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.add_home_work_outlined, size: 60, color: Colors.white),
            const SizedBox(height: 16),
            const Text(
              'أنشئ غرفتك الخاصة',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'اسم الغرفة *',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'الرجاء إدخال اسم الغرفة';
                if (value.trim().length < 3) return 'اسم الغرفة يجب أن يكون 3 أحرف على الأقل';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: 'وصف الغرفة',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                counterStyle: const TextStyle(color: Colors.white54),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _loading ? null : _createRoom,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.button,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.button.withOpacity(0.5),
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Text('إرسال الطلب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
