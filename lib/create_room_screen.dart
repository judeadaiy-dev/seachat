import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'widgets.dart';
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
    // 1. إخفاء الكيبورد
    FocusScope.of(context).unfocus();
    
    // 2. تحقق من الفورم
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final desc = _descController.text.trim();

    setState(() => _loading = true);
    try {
      // 3. تحقق منطقي: هل عنده طلب معلق بنفس الاسم؟
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
            const SnackBar(
              content: Text('لديك طلب معلق بنفس الاسم مسبقاً'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 4. إرسال الطلب
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
          const SnackBar(
            content: Text('تم إرسال الطلب بنجاح، بانتظار موافقة المشرف'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } on PostgrestException catch (e) {
      // 5. معالجة أخطاء Supabase بشكل واضح
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الإرسال: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ غير متوقع، حاول مرة أخرى'),
            backgroundColor: Colors.red,
          ),
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
      backgroundColor: AppColors.primaryBlue,
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
            const SizedBox(height: 8),
            Text(
              'سيتم مراجعة طلبك من قبل المشرف',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'اسم الغرفة *',
                hintText: 'مثال: غرفة محبي التقنية',
                labelStyle: const TextStyle(color: Colors.white70),
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.meeting_room, color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white, width: 1.5),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'الرجاء إدخال اسم الغرفة';
                }
                if (value.trim().length < 3) {
                  return 'اسم الغرفة يجب أن يكون 3 أحرف على الأقل';
                }
                if (value.trim().length > 50) {
                  return 'اسم الغرفة طويل جداً';
                }
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
                hintText: 'اكتب وصف مختصر للغرفة...',
                labelStyle: const TextStyle(color: Colors.white70),
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.description, color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white, width: 1.5),
                ),
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
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : const Text('إرسال الطلب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
