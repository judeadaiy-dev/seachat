import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/supabase_repository.dart';
import 'models.dart';
import 'private_chat.dart';
import 'main.dart';
import 'widgets.dart';

// ===== شاشة الملف الشخصي =====
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
        title: Text('تسجيل الخروج'),
        content: Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('خروج', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) await repo.supabase.auth.signOut();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: Text('الملف الشخصي'), centerTitle: true),
      body: _isLoading
        ? Center(child: CircularProgressIndicator())
          : _user == null
            ? Center(child: Text('المستخدم غير موجود'))
              : ListView(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: [
                    GlassCard(
                      padding: EdgeInsets.all(24),
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
                                backgroundImage: _user!.avatarUrl!= null? NetworkImage(_user!.avatarUrl!) : null,
                                child: _user!.avatarUrl == null
                                  ? Text(
                                        _user!.name.isNotEmpty? _user!.name[0].toUpperCase() : 'U',
                                        style: TextStyle(fontSize: 42, color: Colors.white, fontWeight: FontWeight.bold),
                                      )
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        Text(_user!.name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                        if (_user!.username!= null)...[
                          SizedBox(height: 4),
                          Text('@${_user!.username}', style: TextStyle(fontSize: 15, color: AppColors.icon, fontWeight: FontWeight.w500)),
                        ],
                        if (_user!.zodiac!= null)...[
                          SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.button.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome, size: 16, color: AppColors.button),
                                SizedBox(width: 6),
                                Text(_user!.zodiac!, style: TextStyle(color: AppColors.button, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                        if (_user!.bio!= null && _user!.bio!.isNotEmpty)...[
                          SizedBox(height: 16),
                          Text(
                            _user!.bio!,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: AppColors.textDark.withOpacity(0.7), height: 1.5),
                          ),
                        ],
                        SizedBox(height: 12),
                        Text(_user!.email, style: TextStyle(fontSize: 13, color: AppColors.icon)),
                      ]),
                    ),
                    SizedBox(height: 16),
                    if (_user!.id!= repo.supabase.auth.currentUser?.id)
                      Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: GlassCard(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => PrivateChatScreen(receiver: _user!)),
                            );
                          },
                          child: ListTile(
                            leading: Icon(Icons.chat_bubble_outline, color: AppColors.button),
                            title: Text('بدء محادثة خاصة', style: TextStyle(fontWeight: FontWeight.w600)),
                            trailing: Icon(Icons.send_rounded, size: 16, color: AppColors.button),
                          ),
                        ),
                      ),
                    GlassCard(
                      onTap: _openSettings,
                      child: ListTile(
                        leading: Icon(Icons.edit_rounded, color: AppColors.button),
                        title: Text('تعديل الملف الشخصي', style: TextStyle(fontWeight: FontWeight.w600)),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.icon),
                      ),
                    ),
                    SizedBox(height: 12),
                    GlassCard(
                      onTap: _signOut,
                      child: ListTile(
                        leading: Icon(Icons.logout_rounded, color: Colors.red),
                        title: Text('تسجيل الخروج', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ===== شاشة الإعدادات =====
class ProfileSettingsScreen extends StatefulWidget {
  final UserModel user;
  const ProfileSettingsScreen({super.key, required this.user});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final repo = SupabaseRepository();
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  File? _imageFile;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _usernameController = TextEditingController(text: widget.user.username?? '');
    _bioController = TextEditingController(text: widget.user.bio?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image!= null) {
      setState(() => _imageFile = File(image.path));
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      String? avatarUrl = widget.user.avatarUrl;

      if (_imageFile!= null) {
        final bytes = await _imageFile!.readAsBytes();
        final fileName = '${repo.supabase.auth.currentUser!.id}.jpg';
        final path = 'avatars/$fileName';

        await repo.supabase.storage.from('avatars').uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(upsert: true),
            );

        avatarUrl = repo.supabase.storage.from('avatars').getPublicUrl(path);
      }

      await repo.supabase.from('profiles').update({
        'name': _nameController.text.trim(),
        'username': _usernameController.text.trim().isEmpty? null : _usernameController.text.trim(),
        'bio': _bioController.text.trim().isEmpty? null : _bioController.text.trim(),
        'avatar_url': avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.user.id);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحفظ: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('تعديل الملف الشخصي'),
        actions: [
          TextButton(
            onPressed: _isSaving? null : _saveProfile,
            child: _isSaving
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: AppBackground(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.all(16),
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: AppColors.button.withOpacity(0.2),
                      backgroundImage: _imageFile!= null
                        ? FileImage(_imageFile!)
                          : (widget.user.avatarUrl!= null? NetworkImage(widget.user.avatarUrl!) : null) as ImageProvider?,
                      child: (_imageFile == null && widget.user.avatarUrl == null)
                        ? Text(
                              widget.user.name.isNotEmpty? widget.user.name[0].toUpperCase() : 'U',
                              style: TextStyle(fontSize: 50, color: Colors.white),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          backgroundColor: AppColors.button,
                          child: Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'الاسم', border: OutlineInputBorder()),
                validator: (val) => val!.isEmpty? 'الاسم مطلوب' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(labelText: 'اسم المستخدم', prefixText: '@', border: OutlineInputBorder()),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _bioController,
                decoration: InputDecoration(labelText: 'النبذة', border: OutlineInputBorder()),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
