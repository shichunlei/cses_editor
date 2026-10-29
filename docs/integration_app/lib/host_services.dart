import 'package:cses_editor/cses_editor.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// 以宿主提供的[navigator]和[isCurrent]装配实例级端口；[mediaUpload]为空时禁用本地上传。
/// 示例人员及任务均明确是本机演示数据，接入时由宿主数据层替换；不创建登录或网络客户端。
///
/// ```dart
/// import 'package:flutter/material.dart';
/// import 'package:cses_editor_host_sample/host_services.dart';
/// final key = GlobalKey<NavigatorState>();
/// final services = createHostServices(key, () => true);
/// // 将services传给EditorCommandContext，宿主持有并释放外部资源。
/// ```
CollabHostServices createHostServices(
  GlobalKey<NavigatorState> navigator,
  bool Function() isCurrent, {
  EditorMediaUploadService? mediaUpload,
}) => CollabHostServices(
  mediaUpload: mediaUpload,
  onError: (message, error, stack, tag) {
    debugPrint('$tag $message: $error\n$stack');
  },
  mentionAvatarBuilder:
      (context, {required userId, required name, required size, avatarUrl}) =>
          CircleAvatar(
            radius: size / 2,
            child: Text(name.isEmpty ? '?' : name.characters.first),
          ),
  pickMentionUser: (context, {required keyword, required canEdit}) async {
    if (!isCurrent() || !canEdit.value) return null;
    const people = [
      CollabMentionUser(id: 'demo-lin', name: '演示小林'),
      CollabMentionUser(id: 'demo-chen', name: '演示小陈'),
    ];
    var query = keyword;
    final route = DialogRoute<CollabMentionUser>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('宿主人员选择（演示）'),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: keyword,
                decoration: const InputDecoration(labelText: '搜索人员'),
                onChanged: (value) => update(() => query = value),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: canEdit,
                builder: (context, allowed, child) => Column(
                  children: [
                    for (final person in people.where(
                      (p) => p.name.contains(query),
                    ))
                      TextButton(
                        onPressed: allowed && isCurrent()
                            ? () => Navigator.of(dialogContext).pop(person)
                            : null,
                        child: Text(person.name),
                      ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
          ],
        ),
      ),
    );
    final result = await Navigator.of(context).push(route);
    await route.completed;
    return isCurrent() && canEdit.value ? result : null;
  },
  onMentionTap: (mention) async {
    if (!isCurrent()) return;
    final context = navigator.currentContext;
    if (context == null || !context.mounted) return;
    final route = DialogRoute<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('宿主${mention.type.name}详情'),
        content: Text('${mention.name}\nID: ${mention.id}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
    await Navigator.of(context).push(route);
    await route.completed;
  },
  loadTaskCard: (taskId) async {
    if (!isCurrent()) throw StateError('宿主会话已失效');
    if (taskId != 'demo-task') return null;
    return CollabTaskCardData(taskId: taskId, title: '宿主本地演示任务', progress: 30);
  },
);

/// 宿主文件选择与上传实现的薄适配器，不持有客户端；认证、重试、离线策略由宿主实现。
///
/// ```dart
/// import 'package:cses_editor_host_sample/host_services.dart';
/// final media = HostMediaUpload(
///   pick: (kind) async => null, // 最小离线实现：取消选择。
///   send: (file, kind, {required cancelToken, required onProgress}) async {
///     throw StateError('宿主尚未配置上传');
///   },
/// );
/// // 将pick/send替换为宿主真实实现后注入createHostServices的mediaUpload。
/// ```
final class HostMediaUpload extends EditorMediaUploadService {
  /// [pick]返回宿主选择的文件，取消返回null；[send]等待上传完成，失败抛错。
  /// 两个回调及其客户端仅借用，调用者负责取消正在执行的任务并释放资源。
  HostMediaUpload({required this.pick, required this.send});

  /// 根据image/video/audio/attachment等资源类型选择文件，不请求上传凭据。
  final Future<EditorLocalFile?> Function(String kind) pick;

  /// 宿主上传端口，必须响应cancelToken并上报0～1进度，仅在成功后返回稳定资源URL。
  final Future<EditorMediaSource> Function(
    EditorLocalFile file,
    String kind, {
    required CancelToken cancelToken,
    required void Function(double progress) onProgress,
  })
  send;

  /// 按[kind]委托宿主选择文件；取消返回null，错误透传。
  @override
  Future<EditorLocalFile?> pickFile(String kind) => pick(kind);

  /// 校验[file]/[kind]并将[cancelToken]/[onProgress]交给宿主，不伪造离线上传成功。
  @override
  Future<EditorMediaSource> upload(
    EditorLocalFile file,
    String kind, {
    required CancelToken cancelToken,
    required void Function(double progress) onProgress,
  }) {
    final error = validateEditorMediaFile(kind, file);
    if (error != null) throw ArgumentError(error);
    return send(file, kind, cancelToken: cancelToken, onProgress: onProgress);
  }
}
