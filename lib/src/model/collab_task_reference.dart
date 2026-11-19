import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// 可插入正文的任务引用快照，不持有表单、业务请求或编辑器资源。
///
/// ```dart
/// import 'package:cses_editor/cses_editor.dart';
/// const reference = CollabTaskReference(taskId: 't1', title: '回访客户');
/// ```
final class CollabTaskReference {
  /// [taskId] 是服务端确认的稳定身份，[title] 是写入正文的任务标题。
  const CollabTaskReference({required this.taskId, required this.title});

  /// 任务的稳定业务身份。
  final String taskId;

  /// 创建成功时确认的展示标题。
  final String title;
}

/// 用借用的 [context] 导航到任务表单，以 [initialTitle] 预填本次划词标题。
/// [canEdit] 由编辑器持有，提交前须检查。
/// 成功后等表单完全退场再返回引用，取消返回 null。宿主拥有表单、路由及任务资源。
///
/// ```dart
/// import 'package:cses_editor/cses_editor.dart';
/// final services = CollabHostServices(
///   createTaskFromSelection: (context, {required initialTitle, required canEdit}) async => null,
///   onTaskMentionTap: (mention) async {},
/// );
/// ```
typedef CollabTaskCreator =
    Future<CollabTaskReference?> Function(
      BuildContext context, {
      required String initialTitle,
      required ValueListenable<bool> canEdit,
    });
