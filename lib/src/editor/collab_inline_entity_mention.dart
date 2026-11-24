import 'package:applowy_editor_fork/applowy_editor_fork.dart';
import 'package:cses_editor/src/editor/core/editor_command_context.dart';
import 'package:cses_editor/src/model/collab_entity_mention.dart';
import 'package:cses_editor/src/model/collab_mention_tap.dart';
import 'package:cses_editor/src/ui/modal/collab_bottom_sheet.dart';
import 'package:cses_editor/src/ui/modal/collab_editor_display_scope.dart';
import 'package:cses_editor/src/ui/modal/collab_menu_row.dart';
import 'package:cses_editor/src/ui/modal/collab_modal.dart';
import 'package:cses_editor/src/ui/modal/collab_modal_colors.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'collab_mention_tap_handler.dart';

/// 正文会议/任务/文档单字符对象，显示类型图标及名称；不附加@，不加载人员头像。
/// 会议与任务共用无底色蓝字，配置的正文排版器将其标题展开以支持跨行，数据仍为单个原子。
/// 编辑态点击打开操作面板，打开详情才通知宿主；会议和任务按会话配置提供卡片转换，三类均可删除引用。
/// 显式启用的只读预览直接打开会议/任务详情，不显示编辑面板或修改实体业务数据。
/// ```dart
/// import 'package:flutter/material.dart';
/// import 'package:applowy_editor_fork/applowy_editor_fork.dart';
/// import 'package:cses_editor/src/editor/collab_inline_entity_mention.dart';
/// final chip = CollabInlineEntityMention(node: paragraphNode(), offset: 0,
///   name: '周会', entityType: 'meeting', style: const TextStyle(fontSize: 16));
/// // 将chip放入提供EditorState的WidgetSpan。
/// ```
class CollabInlineEntityMention extends StatefulWidget {
  /// [key] 控制组件身份与复用；[node] 是借用正文节点，[offset] 是UTF-16对象位置；
  /// [name] 为共享正文中的实体名称，[entityType] 为meeting/task/doc类型，[style] 为段落格式，空名称显示“未命名实体”。
  const CollabInlineEntityMention({
    super.key,
    required this.node,
    required this.offset,
    required this.name,
    required this.entityType,
    required this.style,
  });

  /// 编辑器拥有的正文节点，必填，不释放。
  final Node node;

  /// 必填UTF-16对象位置，点击时重新捕获身份及属性。
  final int offset;

  /// 必填原始实体名称，不自动写回业务实体最新标题。
  final String name;

  /// 必填实体类型，meeting/task/doc分别显示会议、任务和文档图标。
  final String entityType;

  /// 必填正文格式；会议/任务引用保留字号和字重，按正文亮度选择蓝色。
  final TextStyle style;

  /// 创建操作面板生命周期状态，不持有业务资源。
  @override
  State<CollabInlineEntityMention> createState() => _EntityMentionState();
}

/// 管理提及操作面板；卡片转换由引用类型及当前会话配置共同控制。
class _EntityMentionState extends State<CollabInlineEntityMention> {
  /// 在借用[context]中显示行内实体名称和与操作面板共用的图标。
  /// 单字符视图中的会议/任务以无底色蓝字展示；正文投影负责自然跨行和原子偏移映射。
  @override
  Widget build(BuildContext context) {
    final state = context.read<EditorState>();
    final node = widget.node;
    final offset = widget.offset;
    final entityType = widget.entityType;
    final name = widget.name;
    final style = widget.style;
    final fontSize = style.fontSize ?? 16;
    final flowsWithText = const {'meeting', 'task'}.contains(entityType);
    final titleStyle = flowsWithText
        ? collabEntityMentionTextStyle(style)
        : style.copyWith(color: style.color ?? const Color(0xFF2563EB));
    final id = node.attributes['cses_collab_block_id'] as String? ?? node.id;
    final kind = switch (entityType) {
      'meeting' => '会议',
      'task' => '任务',
      _ => '文档',
    };
    final title = name.isEmpty ? '未命名$kind' : name;
    final availableWidth = (MediaQuery.sizeOf(context).width - 40).clamp(
      40.0,
      double.infinity,
    );
    return Semantics(
      label: '$kind $title',
      button: true,
      child: ExcludeFocus(
        child: GestureDetector(
          key: ValueKey('collab-inline-entity-$id-$offset'),
          onTap: () =>
              CollabEditorDisplayScope.maybeOf(
                    context,
                  )?.previewMentionInteractions ==
                  true
              ? handleCollabPreviewMentionTap(context, state, node, offset)
              : showCollabEntityMentionActions(context, state, node, offset),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: availableWidth),
            child: Container(
              padding: flowsWithText
                  ? EdgeInsets.zero
                  : const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: flowsWithText
                  ? null
                  : BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(4),
                    ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    collabEntityMentionIcon(
                      entityType,
                      resolver: EditorCommandContext.of(
                        state,
                      ).services.mentionIconResolver,
                    ),
                    size: fontSize,
                    color: flowsWithText
                        ? titleStyle.color
                        : const Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      title,
                      maxLines: flowsWithText ? null : 1,
                      overflow: flowsWithText
                          ? TextOverflow.clip
                          : TextOverflow.ellipsis,
                      style: titleStyle.copyWith(height: 1.2),
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

/// 任务引用与操作面板共用的剪贴板图标，与待办复选框区分。
const collabTaskMentionIcon = LucideIcons.clipboardList;

/// 为 [entityType] 选取行内、换行投影及引用面板共用的图标；不改写正文或持有资源。
/// [resolver] 可空，仅以 meeting/task 类型同步调用，返回 null 时沿用默认图标。
/// 文档及未知类型不调用回调，默认使用文档图标；会议默认日历、任务默认剪贴板。
/// 回调异常沿构建或面板交互边界传播；颜色、大小和基线由各展示位置继续控制。
IconData collabEntityMentionIcon(
  String entityType, {
  IconData? Function(CollabMentionType type)? resolver,
}) {
  final type = switch (entityType) {
    'meeting' => CollabMentionType.meeting,
    'task' => CollabMentionType.task,
    _ => null,
  };
  return (type == null ? null : resolver?.call(type)) ??
      switch (entityType) {
        'meeting' => LucideIcons.calendarClock,
        'task' => collabTaskMentionIcon,
        _ => LucideIcons.fileText,
      };
}

/// 为会议/任务按借用正文 [style] 的亮度选择蓝色，去掉衬底和下划线，保留删除线。
/// 返回独立样式，不改写原格式；浅色正文选浅蓝、深色正文选深蓝，字号和字重沿用正文。
TextStyle collabEntityMentionTextStyle(TextStyle style) => style.copyWith(
  color: (style.color?.computeLuminance() ?? 0) > .5
      ? const Color(0xFF93C5FD)
      : const Color(0xFF1D4ED8),
  backgroundColor: Colors.transparent,
  decoration: style.decoration?.contains(TextDecoration.lineThrough) == true
      ? TextDecoration.lineThrough
      : TextDecoration.none,
);

/// 在借用 [context] 中展示 [state] 的 [node] 在 UTF-16 [offset] 处的引用操作。
/// Future 等待面板及选定操作完成，退场后复核目标与会话，不拥有编辑器或路由。
/// 标题沿用行内引用图标，仅显示一行，超出可用宽度以省略号展示；原始名称完整交付详情回调。
/// 正文标题仍自然换行，面板操作基于捕获的引用原子身份。
/// 会议和任务详情优先调用各自的宿主回调，视图切换和删除在正文内执行。
/// 会议和任务的切换入口及退场后的转换执行均读取同一会话配置。
/// 新预览开关直接派发会议/任务详情；旧任务专用开关保留原只读面板。
/// 编辑态的删除按钮按类型显示「删除会议」「删除任务」或「删除文档」，只移除正文中的引用。
Future<void> showCollabEntityMentionActions(
  BuildContext context,
  EditorState state,
  Node node,
  int offset,
) async {
  final target = CollabEntityMentionTarget.capture(node, offset);
  if (target == null) return;
  final display = CollabEditorDisplayScope.maybeOf(context);
  final preview = display?.preview == true;
  if (preview &&
      display?.previewMentionInteractions != true &&
      (target.entityType != 'task' ||
          display?.previewTaskMentionInteractions != true)) {
    return;
  }
  if (preview && display?.previewMentionInteractions == true) {
    await handleCollabPreviewMentionTap(context, state, node, offset);
    return;
  }
  final configuration = EditorCommandContext.of(state).configuration;
  final canSwitchView = configuration.allowsMentionCardAction(target.entityType);
  await runCollabMentionInteraction(context, state, (services) async {
    final openDetails = switch (target.entityType) {
      'meeting' => services.onMeetingMentionTap ?? services.onMentionTap,
      'task' => services.onTaskMentionTap ?? services.onMentionTap,
      _ => services.onMentionTap,
    };
    final kind = switch (target.entityType) {
      'meeting' => '会议',
      'task' => '任务',
      _ => '文档',
    };
    final action = await showCollabBottomSheet<_EntityAction>(
      context: context,
      builder: (sheetContext) => CollabBottomSheet(
        title: Text(
          target.name.isEmpty ? '未命名$kind' : target.name,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
        icon: collabEntityMentionIcon(
          target.entityType,
          resolver: services.mentionIconResolver,
        ),
        subtitle: '$kind引用 · 当前为链接视图',
        contentPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CollabMenuRow(
              key: const ValueKey('entity-mention-open-detail'),
              leading: const Icon(LucideIcons.externalLink),
              title: Text('打开$kind详情'),
              enabled: openDetails != null,
              onTap: () => Navigator.of(sheetContext).pop(_EntityAction.detail),
            ),
            if (!preview)
              ListenableBuilder(
                listenable: state.editableNotifier,
                builder: (context, _) => Column(
                  children: [
                    if (canSwitchView)
                      CollabMenuRow(
                        key: const ValueKey('entity-mention-switch-view'),
                        leading: const Icon(LucideIcons.panelTop),
                        title: const Text('切换为卡片视图'),
                        subtitle: const Text('当前：链接视图'),
                        enabled: state.editable,
                        onTap: () => Navigator.of(
                          sheetContext,
                        ).pop(_EntityAction.switchView),
                      ),
                    CollabMenuRow(
                      key: const ValueKey('entity-mention-delete'),
                      enabled: state.editable,
                      leading: Icon(
                        LucideIcons.trash2,
                        color: state.editable
                            ? CollabModalColors.of(context).danger
                            : null,
                      ),
                      title: Text(
                        '删除$kind',
                        style: state.editable
                            ? TextStyle(
                                color: CollabModalColors.of(context).danger,
                              )
                            : null,
                      ),
                      onTap: () =>
                          Navigator.of(sheetContext).pop(_EntityAction.delete),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );

    if (!context.mounted || state.isDisposed) return;
    final commandContext = EditorCommandContext.of(state);
    if (!identical(commandContext.services, services)) return;
    final current = target.resolve(state);
    if (current == null || action == null) return;
    switch (action) {
      case _EntityAction.detail:
        final event = collabMentionTapAt(current, target.offset);
        if (event != null) await openDetails?.call(event);
      case _EntityAction.switchView:
        if (!canSwitchView ||
            !commandContext.configuration.allowsMentionCardAction(
              target.entityType,
            ) ||
            !state.editable) {
          return;
        }
        if (!await convertCollabEntityMentionToCard(state, target) &&
            context.mounted) {
          ScaffoldMessenger.maybeOf(
            context,
          )?.showSnackBar(const SnackBar(content: Text('无法转换此提及，请重新打开')));
        }
      case _EntityAction.delete:
        if (!await deleteCollabEntityMention(state, target) &&
            context.mounted) {
          ScaffoldMessenger.maybeOf(
            context,
          )?.showSnackBar(const SnackBar(content: Text('提及已变化，请重新打开')));
        }
    }
  }, restoreFocus: !preview);
}

/// 面板选择在路由完全退场后执行，不在面板内发起业务导航或正文写入。
enum _EntityAction {
  /// 只通知宿主打开详情。
  detail,

  /// 转换为正式会议或任务卡片块。
  switchView,

  /// 仅删除正文中的引用。
  delete,
}
