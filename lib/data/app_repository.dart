import 'dart:io';
import '../models.dart';  // ← غيرت هذا السطر بس: ضفت ../ 

// ===== الجسر بين الواجهة وقاعدة البيانات (SeaChat Official) =====
// كل دالة هنا = أمر بالواجهة
// كل تعليق فوق الدالة = اسم الجدول المطلوب في SQL

abstract class AppRepository {
  
  // ========== جدول: profiles ==========
  
  // يستدعى من: LoginScreen - زر تسجيل الدخول (يدوي)
  Future<bool> signInWithEmail({required String email, required String password});
  
  // يستدعى من: LoginScreen - زر Google (معطل مؤقتاً برمجياً)
  Future<void> signInWithGoogle();
  
  // يستدعى من: ProfileSettingsScreen - حفظ التعديلات
  // تم دمج (userId) مع الحقول المطلوبة لضمان دقة التحديث
  Future<void> updateProfile({
    required String name,
    String? username,
    String? bio,
    String? zodiac,
  });
  
  // يستدعى من: ProfileScreen & ProfileSettingsScreen - التعامل مع الصور
  Future<String?> uploadAvatar(File file);
  Future<void> deleteAvatar();
  
  // يستدعى من: ProfileScreen - جلب بيانات المستخدم الحالي
  Future<UserModel?> getCurrentUser();

  // ========== جدول: rooms ==========
  
  // يستدعى من: HomeScreen - عرض قائمة الغرف (بث مباشر Stream)
  Stream<List<RoomModel>> getRoomsStream();
  
  // يستدعى من: AppDrawer - زر إنشاء غرفة
  Future<void> createRoom({required String roomName, String? description});
  
  // يستدعى من: ChatScreen - حذف الغرفة - للـ owner أو admin فقط
  Future<void> deleteRoom({required String roomId});

  // ========== جدول: room_members ==========
  
  // يستدعى من: ChatScreen - عرض أعضاء الغرفة مع النقاط
  Future<List<RoomMemberModel>> getRoomMembers({required String roomId});
  
  // يستدعى من: ChatScreen - إزالة عضو أو الخروج
  Future<void> leaveRoom({required String roomId});
  Future<void> kickRoomMember({required String roomId, required String userId});
  
  // يستدعى من: ChatScreen - زيادة نقاط العضو تلقائي بعد كل رسالة
  Future<void> incrementMemberPoints({required String roomId, required String userId});

  // ========== جدول: messages ==========
  
  // يستدعى من: ChatScreen - تحميل رسائل الغرفة - Stream (الرسائل الأحدث أولاً)
  Stream<List<MessageModel>> getRoomMessagesStream({required String roomId});
  
  // يستدعى من: ChatScreen - أزرار إرسال (نص، صورة، صوت)
  Future<void> sendMessage({required String roomId, required String message});
  Future<void> sendImageMessage({required String roomId, required File imageFile});
  Future<void> sendVoiceMessage({required String roomId, required String voicePath});
  
  // يستدعى من: ChatScreen - حذف رسالة
  Future<void> deleteMessage({required String messageId});

  // ========== جدول: profiles (الإدارة) ==========
  
  // يستدعى من: AdminPanel - حظر عضو من التطبيق نهائياً
  Future<void> banUser({required String userId});
  
  // يستدعى من: AppDrawer - للتحقق من إظهار لوحة الإدارة
  Future<bool> isCurrentUserAdmin();

  // ========== جدول: app_settings ==========
  
  // يستدعى من: PrivacyPolicyScreen & ContactUsScreen
  Future<String> getPrivacyPolicy();
  Future<String> getSupportEmail();
}
