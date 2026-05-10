import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'models.dart';
import 'private_chat.dart'; // مستورد بشكل صحيح
import 'main.dart'; 

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final repo = SupabaseRepository();
  UserModel? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = await repo.getCurrentUser();
      if (mounted) setState(() => _user = user);
    } catch (e) {
      if (mounted) _showSnackBar('فشل تحميل البيانات: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openSettings() async {
    if (_user == null) return;
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProfileSettingsScreen(user: _user!)),
    );
    if (updated == true) _loadUser();
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('خروج', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) await SupabaseRepository().supabase.auth.signOut();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('الملف الشخصي'), centerTitle: true),
      body: _isLoading
         ? const Center(child: CircularProgressIndicator())
          : _user == null
             ? const Center(child: Text('المستخدم غير موجود'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: [
                    GlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(colors: [AppColors.button, AppColors.button.withOpacity(0.6)]),
                              ),
                            ),
                            CircleAvatar(
                              radius: 56,
                              backgroundColor: Colors.white,
                              child: CircleAvatar(
                                radius: 54,
                                backgroundColor: AppColors.button.withOpacity(0.2),
                                backgroundImage: _user!.avatarUrl != null ? NetworkImage(_user!.avatarUrl!) : null,
                                child: _user!.avatarUrl == null
                                   ? Text(
                                        _user!.name.isNotEmpty ? _user!.name[0].toUpperCase() : 'U',
                                        style: const TextStyle(fontSize: 42, color: Colors.white, fontWeight: FontWeight.bold),
                                      )
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(_user!.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                        if (_user!.username != null)...[
                          const SizedBox(height: 4),
                          Text('@${_user!.username}', style: TextStyle(fontSize: 15, color: AppColors.icon, fontWeight: FontWeight.w500)),
                        ],
                        if (_user!.zodiac != null)...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.button.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_awesome, size: 16, color: AppColors.button),
                                const SizedBox(width: 6),
                                Text(_user!.zodiac!, style: const TextStyle(color: AppColors.button, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                        if (_user!.bio != null && _user!.bio!.isNotEmpty)...[
                          const SizedBox(height: 16),
                          Text(
                            _user!.bio!,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: AppColors.textDark.withOpacity(0.7), height: 1.5),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(_user!.email, style: TextStyle(fontSize: 13, color: AppColors.icon)),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    // هنا تضع زر المراسلة إذا لم يكن هذا بروفايلك
                    if (_user!.id != repo.supabase.auth.currentUser?.id)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GlassCard(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => PrivateChatScreen(receiver: _user!)),
                            );
                          },
                          child: const ListTile(
                            leading: Icon(Icons.chat_bubble_outline, color: AppColors.button),
                            title: Text('بدء محادثة خاصة', style: TextStyle(fontWeight: FontWeight.w600)),
                            trailing: Icon(Icons.send_rounded, size: 16, color: AppColors.button),
                          ),
                        ),
                      ),
                    
                    GlassCard(
                      onTap: _openSettings,
                      child: const ListTile(
                        leading: Icon(Icons.edit_rounded, color: AppColors.button),
                        title: Text('تعديل الملف الشخصي', style: TextStyle(fontWeight: FontWeight.w600)),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.icon),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GlassCard(
                      onTap: _signOut,
                      child: const ListTile(
                        leading: Icon(Icons.logout_rounded, color: Colors.red),
                        title: Text('تسجيل الخروج', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
    );
  }
}

// كود شاشة الإعدادات يبقى كما هو بالأسفل...
// (بقية الكود الخاص بـ ProfileSettingsScreen يوضع هنا بدون زر المراسلة داخله)
