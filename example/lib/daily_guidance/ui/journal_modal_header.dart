import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 宿主弹窗的可换行标题及关闭入口，资源与导航结果由调用方持有。
///
/// ```dart
/// JournalModalHeader(title: '分享', icon: LucideIcons.share2);
/// ```
class JournalModalHeader extends StatelessWidget {
  /// [key] 控制身份；[title] 为完整标题，[icon] 为装饰图标。
  /// [closeKey] 可标识关闭入口；关闭只返回 null，不写业务数据。
  const JournalModalHeader({
    super.key,
    required this.title,
    required this.icon,
    this.closeKey,
  });

  /// 可随大字换行的标题。
  final String title;

  /// 不重复朗读的标题装饰。
  final IconData icon;

  /// 可选关闭按钮标识。
  final Key? closeKey;

  /// 在借用的 [context] 内按受约束标题宽度布局，关闭不恢复正文焦点。
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            size: 19,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          key: closeKey,
          tooltip: '关闭',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(LucideIcons.x),
        ),
      ],
    ),
  );
}
