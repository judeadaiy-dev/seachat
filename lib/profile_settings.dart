import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'models.dart';
import 'data/supabase_repository.dart';

class ProfileSettings extends StatefulWidget {
  const ProfileSettings({super.key});

  @override
  State<ProfileSettings> createState() => _ProfileSettingsState();
}

class _ProfileSettingsState extends State<ProfileSettings> {
  final supabase = Supabase.instance.client;
  UserModel? currentUser;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await repo.getCurrentUser();
      if (mounted) {
        setState(() {
          currentUser = user;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.button))
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: (currentUser?.avatarUrl != null && currentUser!.avatarUrl!.isNotEmpty)
                        ? NetworkImage(currentUser!.avatarUrl!)
                        : null,
                    child: (currentUser?.avatarUrl == null || currentUser!.avatarUrl!.isEmpty)
                        ? const Icon(Icons.person, size: 50)
                        : null,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    currentUser?.name ?? 'مستخدم',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    currentUser?.email ?? '',
                    style: const TextStyle(fontSize: 16, color: AppColors.textLight),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.button),
                    onPressed: _signOut,
                    child: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
    );
  }
}
