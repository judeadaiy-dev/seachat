import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'widgets.dart';
class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  final _msgController = TextEditingController();
  final supabase = Supabase.instance.client;
  bool _loading = false;

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    setState(() => _loading = true);
    try {
      await supabase.from('contact_messages').insert({
        'user_id': supabase.auth.currentUser?.id,
        'message': text,
      });
      
      _msgController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال رسالتك بنجاح')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الإرسال: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('تواصل معنا'), backgroundColor: Colors.black54),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                controller: _msgController,
                style: const TextStyle(color: Colors.white),
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'اكتب مشكلتك أو اقتراحك...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _sendMessage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.button,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _loading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text('إرسال'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
