import 'dart:math' as math;

import 'package:cses_offline_example/daily_guidance/ui/journal_modal_header.dart';
import 'package:flutter/material.dart';

/// 固定头尾的宿主底部面板，正文滚动策略由调用方选择，不接管业务资源。
///
/// ```dart
/// JournalBottomSheet(title: '分享', icon: LucideIcons.share2, child: Text('正文'));
/// ```
class JournalBottomSheet extends StatelessWidget {
  /// [key] 控制身份；[title]/[icon] 提供标题，[child] 为借用正文。
  /// [header] 为固定搜索等内容，[actions] 为右对齐固定按钮，[footer] 为固定说明。
  /// [expand] 填满可用高度，[scrollBody] 默认由外壳滚动，false 时正文自管有限视口。
  /// [closeKey] 标识关闭按钮；本组件仅负责一次键盘避让和底部安全区。
  const JournalBottomSheet({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.header,
    this.actions = const [],
    this.footer,
    this.expand = false,
    this.scrollBody = true,
    this.closeKey,
  });

  /// 完整标题。
  final String title;

  /// 标题装饰图标。
  final IconData icon;

  /// 借用正文，不在本层释放其控制器。
  final Widget child;

  /// 固定在标题下的可选搜索区。
  final Widget? header;

  /// 固定右侧操作；窄屏大字可换行。
  final List<Widget> actions;

  /// 可选左侧固定说明，最多占操作栏一半宽度。
  final Widget? footer;

  /// 是否让正文填满剩余空间。
  final bool expand;

  /// 是否由本外壳滚动正文。
  final bool scrollBody;

  /// 可选关闭按钮标识。
  final Key? closeKey;

  /// 基于借用 [context] 的实际视口限高，不叠加键盘或安全区留白。
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: LayoutBuilder(
        builder: (context, constraints) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: math.max(
              0,
              math.min(
                637,
                math.min(
                  constraints.maxHeight,
                  media.size.height * .9 - media.viewInsets.bottom,
                ),
              ),
            ),
          ),
          child: Material(
            color: scheme.surface,
            clipBehavior: Clip.antiAlias,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Padding(
              padding: EdgeInsets.only(
                bottom: math.max(12, media.padding.bottom),
              ),
              child: Column(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  JournalModalHeader(
                    title: title,
                    icon: icon,
                    closeKey: closeKey,
                  ),
                  ?header,
                  Flexible(
                    fit: expand ? FlexFit.tight : FlexFit.loose,
                    child: scrollBody
                        ? SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                            child: child,
                          )
                        : child,
                  ),
                  if (footer != null || actions.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: scheme.outline)),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 2),
                      child: LayoutBuilder(
                        builder: (context, constraints) => Row(
                          children: [
                            if (footer != null) ...[
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: constraints.maxWidth / 2,
                                ),
                                child: footer!,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: OverflowBar(
                                alignment: MainAxisAlignment.end,
                                overflowAlignment: OverflowBarAlignment.end,
                                spacing: 10,
                                overflowSpacing: 8,
                                children: actions,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
