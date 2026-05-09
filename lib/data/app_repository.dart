// ===== الجسر بين الواجهة وقاعدة البيانات =====
// كل دالة هنا = أمر بالواجهة
// كل تعليق فوق الدالة = اسم الجدول المطلوب في SQL

abstract class AppRepository {
  
  // ========== جدول: profiles ==========
  
  // يستدعى من: LoginScreen - زر تسجيل الدخول
  Future<bool> signInWithEmail({required String email, required String password});
  
  // يستدعى من: LoginScreen - زر Google
  Future<void> signInWithGoogle();
  
  // يستدعى من: ProfileScreen - تعديل البيانات
  Future<bool> updateProfile({required String userId, required String username, String? avatarUrl});
  
  // يستدعى من: ProfileScreen - جلب بيانات المستخدم الحالي
  Future<UserModel?> getCurrentUser();

  // ========== جدول: rooms ==========
  
  // يستدعى من: HomeScreen - عرض قائمة الغرف
  Future<List<RoomModel>> getAllActiveRooms();
  
  // يستدعى من: AppDrawer - زر إنشاء غرفة - يحفظها مباشرة كـ room_type = 'user'
  Future<bool> createRoom({required String roomName, String? description});
  
  // يستدعى من: ChatScreen - حذف الغرفة - للـ owner فقط
  Future<bool> deleteRoom({required String roomId});

  // ========== جدول: room_members ==========
  
  // يستدعى من: ChatScreen - دخول الغرفة
  Future<bool> joinRoom({required String roomId});
  
  // يستدعى من: ChatScreen - خروج من الغرفة
  Future<bool> leaveRoom({required String roomId});
  
  // يستدعى من: ChatScreen - عرض أعضاء الغرفة مع النقاط
  Future<List<RoomMemberModel>> getRoomMembers({required String roomId});
  
  // يستدعى من: ChatScreen - إزالة عضو - للـ owner فقط
  Future<bool> kickRoomMember({required String roomId, required String userId});
  
  // يستدعى من: ChatScreen - زيادة نقاط العضو تلقائي بعد كل رسالة
  Future<void> incrementMemberPoints({required String roomId, required String userId});

  // ========== جدول: messages ==========
  
  // يستدعى من: ChatScreen - تحميل رسائل الغرفة - Stream
  Stream<List<MessageModel>> getRoomMessagesStream({required String roomId});
  
  // يستدعى من: ChatScreen - زر إرسال نص
  Future<bool> sendMessage({required String roomId, required String message});
  
  // يستدعى من: ChatScreen - زر إرسال صورة
  Future<bool> sendImageMessage({required String roomId, required File imageFile});
  
  // يستدعى من: ChatScreen - زر إرسال صوت
  Future<bool> sendVoiceMessage({required String roomId, required String voiceUrl});
  
  // يستدعى من: ChatScreen - حذف رسالة - للـ owner أو صاحب الرسالة
  Future<bool> deleteMessage({required String messageId});

  // ========== جدول: bans ==========
  
  // يستدعى من: ChatScreen - حظر عضو من التطبيق كله - للـ admin فقط
  Future<bool> banUser({required String userId});

  // ========== جدول: app_settings ==========
  
  // يستدعى من: PrivacyPolicyScreen - تحميل النص
  Future<String> getPrivacyPolicy();
  
  // يستدعى من: ContactUsScreen - تحميل الإيميل
  Future<String> getSupportEmail();
}
