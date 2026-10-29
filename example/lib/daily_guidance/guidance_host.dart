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

/// 创建 example 实例拥有的头像服务，不创建账号、订阅或客户端。
/// [avatarUrls] 是宿主明确提供的用户 ID 到图片地址映射，创建时复制，缺省使用姓名首字。
/// 头像槽传入的 userId/name/size/avatarUrl 均来自当前位置，图片由 Flutter 持有和释放。
///
/// ```dart
/// final services = createDemoGuidanceHostServices(avatarUrls: {'u1': 'https://host.example/u1.png'});
/// LocalJournalPage(store: store, hostServices: services);
/// ```
CollabHostServices createDemoGuidanceHostServices({Map<String, String> avatarUrls = const {}}) {
  final urls = Map<String, String>.unmodifiable(avatarUrls);
  return CollabHostServices(
    mentionAvatarBuilder: (context, {required userId, required name, required size, avatarUrl}) =>
        DemoMentionAvatar(userId: userId, name: name, size: size, avatarUrl: avatarUrl ?? urls[userId]),
  );
}

/// 由宿主构建的离线姓名头像，不推断任何网络地址。
///
/// ```dart
/// const avatar = DemoMentionAvatar(userId: 'local-1', name: '本地成员');
/// ```
class DemoMentionAvatar extends StatelessWidget {
  /// [key]控制身份，[userId]是人员标识，[name]用于首字回退，[size]为正逻辑像素直径。
  /// [avatarUrl]仅在宿主明确提供时加载，null显示姓名首字。
  const DemoMentionAvatar({super.key, required this.userId, required this.name, this.size = 36, this.avatarUrl});

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
  Widget build(BuildContext context) {
    const colors = [Color(0xff8b6e63), Color(0xff5f82a4), Color(0xff6b8f71), Color(0xffa779a9)];
    final color = colors[userId.runes.fold<int>(0, (value, rune) => value + rune) % colors.length];
    final url = avatarUrl?.trim();
    final image = url == null || url.isEmpty ? null : NetworkImage(url);
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: color,
      foregroundImage: image,
      onForegroundImageError: image == null ? null : (_, _) {},
      child: Text(
        name.isEmpty ? '?' : name.characters.first,
        textScaler: TextScaler.noScaling,
        style: TextStyle(fontSize: size * .56, height: 1, fontWeight: FontWeight.w600, color: Colors.white),
      ),
    );
  }
}
