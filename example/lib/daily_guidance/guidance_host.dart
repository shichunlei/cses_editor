import 'package:cses_editor/cses_editor.dart';
import 'package:flutter/material.dart';

/// 未配置人员查询时使用的空目录，不持有账号或网络资源。
///
/// ```dart
/// const directory = EmptyMentionDirectory();
/// final users = await directory.search('');
/// ```
final class EmptyMentionDirectory implements CollabMentionDirectory {
  /// 创建无资源目录。
  const EmptyMentionDirectory();

  /// 对任意[keyword]返回空结果，不发出网络请求。
  @override
  Future<List<CollabMentionUser>> search(String keyword) async => const [];

  /// 对任意[userId]返回null，表示未配置人员资料。
  @override
  Future<CollabMentionUser?> load(String userId) async => null;
}

/// 由宿主构建的离线姓名头像，不推断任何网络地址。
///
/// ```dart
/// const avatar = DemoMentionAvatar(userId: 'local-1', name: '本地成员');
/// ```
class DemoMentionAvatar extends StatelessWidget {
  /// [key]控制身份，[userId]是人员标识，[name]用于首字回退，[size]为正逻辑像素直径。
  /// [avatarUrl]仅在宿主明确提供时加载，null显示姓名首字。
  const DemoMentionAvatar({
    super.key,
    required this.userId,
    required this.name,
    this.size = 36,
    this.avatarUrl,
  });

  /// 宿主人员标识，不用于拼接网络地址。
  final String userId;

  /// 显示名称，空名称使用问号。
  final String name;

  /// 头像直径，默认36逻辑像素。
  final double size;

  /// 宿主明确提供的可选头像地址。
  final String? avatarUrl;

  /// 在[context]展示固定尺寸头像；网络失败使用姓名回退。
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: size / 2,
    foregroundImage: avatarUrl == null ? null : NetworkImage(avatarUrl!),
    onForegroundImageError: avatarUrl == null ? null : (_, _) {},
    child: Text(name.isEmpty ? '?' : name.characters.first),
  );
}
