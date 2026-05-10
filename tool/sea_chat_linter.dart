import 'dart:io';

void main() {
  print('=== SeaChat Health Check ===\n');
  int issues = 0;

  final libDir = Directory('lib');
  final files = libDir.listSync(recursive: true)
     .whereType<File>()
     .where((f) => f.path.endsWith('.dart'))
     .toList();

  for (var file in files) {
    final content = file.readAsStringSync();
    final lines = content.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineNum = i + 1;

      // 1. room.name بدل room.roomName
      if (line.contains('room.name') &&!line.contains('room.roomName')) {
        _printIssue(file.path, lineNum,
          'استخدم room.roomName بدل room.name',
          'استبدل: room.name → room.roomName');
        issues++;
      }

      // 2. msg.message بدل msg.text
      if (line.contains('msg.message') &&!line.contains('msg.text')) {
        _printIssue(file.path, lineNum,
          'استخدم msg.text بدل msg.message',
          'استبدل: msg.message → msg.text');
        issues++;
      }

      // 3. descending: true قديم
      if (line.contains('descending: true')) {
        _printIssue(file.path, lineNum,
          'Supabase 2.10+ يستخدم ascending: false',
          'استبدل: descending: true → ascending: false');
        issues++;
      }

      // 4. Divider داخل PopupMenu
      if (line.contains('PopupMenuButton') && files.indexOf(file) < files.length - 1) {
        final nextLines = lines.skip(i).take(10).join('\n');
        if (nextLines.contains('Divider()')) {
          _printIssue(file.path, lineNum,
            'استخدم PopupMenuDivider() بدل Divider()',
            'استبدل: Divider() → PopupMenuDivider()');
          issues++;
        }
      }

      // 5. PopupMenuDivider داخل Uri.parse
      if (line.contains('Uri.parse(PopupMenuDivider')) {
        _printIssue(file.path, lineNum,
          'خطأ فادح: PopupMenuDivider داخل Uri.parse',
          'استبدل بـ: Uri.parse(oldAvatar?[\'avatar_url\']?? \'\')');
        issues++;
      }

      // 6. oldAvatar بدون null check
      if (line.contains('oldAvatar[\'avatar_url\']') &&!line.contains('oldAvatar?')) {
        _printIssue(file.path, lineNum,
          'ممكن يكرش لو oldAvatar null',
          'استبدل: oldAvatar[\'avatar_url\'] → oldAvatar?[\'avatar_url\']?? \'\'');
        issues++;
      }

      // 7..or مع and() قديم
      if (line.contains('.or(\'and(')) {
        _printIssue(file.path, lineNum,
          'صيغة.or القديمة ما تشتغل مع supabase 2.10+',
          'استخدم:.or(\'col.eq.val1,col.eq.val2\')');
        issues++;
      }
    }
  }

  // 8. فحص المكررات
  final classNames = ['PrivateChatsScreen', 'ContactUsScreen', 'RoomModel', 'MessageModel', 'UserModel'];
  for (var className in classNames) {
    final matches = files.where((f) {
      final content = f.readAsStringSync();
      return content.contains('class $className');
    }).toList();

    if (matches.length > 1) {
      print('\n🔴 مكرر: class $className موجود في ${matches.length} ملفات:');
      for (var f in matches) {
        print(' - ${f.path}');
      }
      print(' الحل: احذف الكلاس من كل الملفات ما عدا lib/models.dart\n');
      issues++;
    }
  }

  // 9. فحص pubspec
  final pubspec = File('pubspec.yaml').readAsStringSync();
  if (pubspec.contains('record: ^5.')) {
    _printIssue('pubspec.yaml', 0,
      'record 5.x يتعارض مع Flutter 3.5+',
      'حدث لـ: record: ^6.0.0');
    issues++;
  }
  if (pubspec.contains('supabase_flutter: ^2.8')) {
    _printIssue('pubspec.yaml', 0,
      'supabase_flutter قديم',
      'حدث لـ: supabase_flutter: ^2.10.6');
    issues++;
  }

  print('\n=== النتيجة: $issues مشكلة ===');
  if (issues == 0) print('✅ الكود نظيف وجاهز للتوسع');
  exit(issues > 0? 1 : 0);
}

void _printIssue(String file, int line, String problem, String fix) {
  print('🔴 $file:$line');
  print(' المشكلة: $problem');
  print(' الحل: $fix\n');
}
