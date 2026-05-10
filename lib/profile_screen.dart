import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'models.dart';
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
                                child: _user!.avatarUrl != null && _user!.avatarUrl!.isNotEmpty
                                    ? ClipOval(
                                        child: CachedNetworkImage(
                                          imageUrl: _user!.avatarUrl!,
                                          fit: BoxFit.cover,
                                          width: 108,
                                          height: 108,
                                          placeholder: (context, url) => const CircularProgressIndicator(strokeWidth: 2),
                                          errorWidget: (context, url, error) => const Icon(Icons.error_outline, color: Colors.red),
                                        ),
                                      )
                                    : Text(
                                        _user!.name.isNotEmpty ? _user!.name[0].toUpperCase() : 'U',
                                        style: const TextStyle(fontSize: 42, color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(_user!.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                        if (_user!.username != null) ...[
                          const SizedBox(height: 4),
                          Text('@${_user!.username}', style: TextStyle(fontSize: 15, color: AppColors.icon, fontWeight: FontWeight.w500)),
                        ],
                        if (_user!.zodiac != null) ...[
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
                        if (_user!.bio != null && _user!.bio!.isNotEmpty) ...[
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

class ProfileSettingsScreen extends StatefulWidget {
  final UserModel user;
  const ProfileSettingsScreen({super.key, required this.user});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  late TextEditingController nameController;
  late TextEditingController usernameController;
  late TextEditingController bioController;
  String? selectedZodiac;
  String? avatarUrl;
  bool isLoading = false;
  final repo = SupabaseRepository();
  final picker = ImagePicker();

  final zodiacs = [
    'الحمل', 'الثور', 'الجوزاء', 'السرطان', 'الأسد', 'العذراء',
    'الميزان', 'العقرب', 'القوس', 'الجدي', 'الدلو', 'الحوت'
  ];

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.user.name);
    usernameController = TextEditingController(text: widget.user.username);
    bioController = TextEditingController(text: widget.user.bio);
    selectedZodiac = widget.user.zodiac;
    avatarUrl = widget.user.avatarUrl;
  }

  @override
  void dispose() {
    nameController.dispose();
    usernameController.dispose();
    bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75, maxWidth: 1024);
      if (image == null) return;
      setState(() => isLoading = true);
      final url = await repo.uploadAvatar(File(image.path));
      if (mounted) {
        setState(() {
          avatarUrl = url;
          isLoading = false;
        });
        _showSnackBar('تم تحديث الصورة بنجاح');
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showSnackBar('فشل رفع الصورة: $e');
      }
    }
  }

  Future<void> _deleteImage() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف الصورة'),
        content: const Text('هل أنت متأكد من حذف صورة الملف الشخصي؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => isLoading = true);
    try {
      await repo.deleteAvatar();
      if (mounted) {
        setState(() {
          avatarUrl = null;
          isLoading = false;
        });
        _showSnackBar('تم حذف الصورة');
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showSnackBar('فشل الحذف: $e');
      }
    }
  }

  Future<void> _saveProfile() async {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      _showSnackBar('الاسم مطلوب');
      return;
    }
    if (usernameController.text.trim().isNotEmpty && usernameController.text.trim().length < 3) {
      _showSnackBar('المعرف يجب أن يكون 3 أحرف على الأقل');
      return;
    }

    setState(() => isLoading = true);
    try {
      await repo.updateProfile(
        name: name,
        username: usernameController.text.trim().isEmpty ? null : usernameController.text.trim(),
        bio: bioController.text.trim().isEmpty ? null : bioController.text.trim(),
        zodiac: selectedZodiac,
      );
      if (mounted) {
        Navigator.pop(context, true);
        _showSnackBar('تم حفظ التعديلات بنجاح');
      }
    } catch (e) {
      if (mounted) _showSnackBar('فشل الحفظ: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppColors.icon.withOpacity(0.8)),
      prefixIcon: Icon(icon, color: AppColors.icon),
      filled: true,
      fillColor: Colors.white.withOpacity(0.5),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.button, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('إعدادات الملف الشخصي'),
        centerTitle: true,
      ),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 100, 16, 32),
          children: [
            GlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [AppColors.button, AppColors.button.withOpacity(0.6)]),
                      ),
                    ),
                    CircleAvatar(
                      radius: 54,
                      backgroundColor: AppColors.button.withOpacity(0.2),
                      child: avatarUrl != null && avatarUrl!.isNotEmpty
                          ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: avatarUrl!,
                                fit: BoxFit.cover,
                                width: 108,
                                height: 108,
                                placeholder: (context, url) => const CircularProgressIndicator(strokeWidth: 2),
                                errorWidget: (context, url, error) => const Icon(Icons.error_outline, color: Colors.red),
                              ),
                            )
                          : Text(
                              widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : 'U',
                              style: const TextStyle(fontSize: 42, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: isLoading ? null : _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.button,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)],
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                    if (avatarUrl != null)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: GestureDetector(
                          onTap: isLoading ? null : _deleteImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)],
                            ),
                            child: const Icon(Icons.delete_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: nameController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: _decoration('الاسم *', Icons.person_outline_rounded),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: usernameController,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration('المعرف', Icons.alternate_email_rounded),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedZodiac,
                  decoration: _decoration('البرج', Icons.auto_awesome_rounded),
                  dropdownColor: AppColors.backgroundEnd,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('بدون')),
                    ...zodiacs.map((z) => DropdownMenuItem(value: z, child: Text(z))),
                  ],
                  onChanged: (val) => setState(() => selectedZodiac = val),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: bioController,
                  maxLines: 3,
                  maxLength: 150,
                  textInputAction: TextInputAction.done,
                  decoration: _decoration('النبذة التعريفية', Icons.info_outline_rounded),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.button,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: isLoading ? null : _saveProfile,
                    child: isLoading
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('حفظ التعديلات', style: TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
