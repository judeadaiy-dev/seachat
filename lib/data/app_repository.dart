// ===== الجسر بين الواجهة وقاعدة البيانات =====
// كل دالة هنا = أمر بالواجهة
// كل تعليق فوق الدالة = اسم الجدول المطلوب في SQL

abstract class AppRepository {
  
  // ========== جدول: users ==========
  
  // يستدعى من: LoginScreen - زر تسجيل الدخول
  Future<UserModel?> loginUser({required String email, required String password});
  
  // يستدعى من: ProfileScreen - تعديل البيانات
  Future<bool> updateUser({required String userId, required String name, required String email});
  
  // يستدعى من: ProfileScreen - جلب بيانات المستخدم الحالي
  Future<UserModel?> getCurrentUser({required String userId});

  // ========== جدول: rooms ==========
  
  // يستدعى من: HomeScreen - عرض قائمة الغرف
  Future<List<RoomModel>> getAllActiveRooms();
  
  // يستدعى من: AppDrawer - زر إنشاء غرفة جديد
  Future<bool> createRoomRequest({required String userId, required String requestedName, required String requestedBio});
  // جدول: room_requests

  // ========== جدول: messages ==========
  
  // يستدعى من: ChatScreen - تحميل رسائل الغرفة
  Future<List<MessageModel>> getRoomMessages({required String roomId});
  
  // يستدعى من: ChatScreen - زر إرسال
  Future<bool> sendMessage({required String roomId, required String senderId, required String message, required String messageType});
  
  // يستدعى من: ChatScreen - حذف رسالة
  Future<bool> deleteMessage({required String messageId});

  // ========== جدول: room_members ==========
  
  // يستدعى من: ChatScreen - عرض أعضاء الغرفة
  Future<List<UserModel>> getRoomMembers({required String roomId});
  
  // يستدعى من: ChatScreen - كتم عضو
  Future<bool> muteRoomMember({required String roomId, required String userId});
  
  // يستدعى من: ChatScreen - حظر عضو
  Future<bool> banUserFromRoom({required String roomId, required String bannedUserId, required String bannedBy, required String reason});
  // جدول: bans

  // ========== جدول: notifications ==========
  
  // يستدعى من: HomeScreen - أيقونة الإشعارات
  Future<List<NotificationModel>> getUserNotifications({required String userId});
  
  // يستدعى من: NotificationsScreen - تحديد كمقروء
  Future<bool> markNotificationAsRead({required String notificationId});

  // ========== جدول: support_messages ==========
  
  // يستدعى من: ContactUsScreen - زر إرسال
  Future<bool> sendSupportMessage({required String userId, required String subject, required String message});

  // ========== جدول: reports ==========
  
  // يستدعى من: ChatScreen - زر إبلاغ عن مستخدم
  Future<bool> reportUser({required String reporterId, required String reportedUserId, required String roomId, required String reason});

  // ========== جدول: app_settings ==========
  
  // يستدعى من: PrivacyPolicyScreen - تحميل النص
  Future<String> getPrivacyPolicy();
  
  // يستدعى من: ContactUsScreen - تحميل الإيميل
  Future<String> getSupportEmail();
}
