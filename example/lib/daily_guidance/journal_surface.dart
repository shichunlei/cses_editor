import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cses_editor/cses_editor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'guidance_entries.dart';
import 'journal_draft.dart';
import 'journal_editing.dart';
import 'journal_exchange_keys.dart';
import 'journal_list_markers.dart';
import 'journal_ruled_content.dart';

/// 日记纸张展示配置；通过共用DocumentEditorView提供编辑和预览，借用会话，不释放正文。
///
/// ```dart
/// import 'package:flutter/material.dart';
/// import 'package:cses_offline_example/daily_guidance/journal_surface.dart';
/// import 'package:cses_offline_example/daily_guidance/local_journal_controller.dart';
/// Widget journalBody(LocalJournalController journal) => JournalSurface(
///   editorState: journal.editor.editorState, preview: false, header: Text(journal.date));
/// ```
class JournalSurface extends StatelessWidget {
  /// [key]控制身份，[editorState]由日记会话拥有，[preview]关闭输入、选区和工具栏。
  /// [header]为与正文一起滚动的纸张标题和日期，编辑与预览使用相同布局。
  /// [onCloseSection]接收可选栏目种类，由宿主持有且可空。
  /// [keyboardActions]为宿主自定义快捷项，默认空；工具栏等待每个动作完成，模态输入恢复由宿主负责。
  const JournalSurface({
    super.key,
    required this.editorState,
    required this.preview,
    required this.header,
    this.onCloseSection,
    this.keyboardActions = const [],
  });

  /// 借用的唯一正文会话，调用方必须在视图移除后释放。
  final EditorState editorState;

  /// true 为只读预览，收紧栏目尾部留白；不修改正文、字号或纸张宽度。
  final bool preview;

  /// 可选栏目关闭回调；null时不显示关闭按钮，回调由业务页面持有。
  final ValueChanged<String>? onCloseSection;

  /// 宿主提供的自定义工具栏动作；预览不显示，回调及其业务资源由宿主持有。
  final List<EditorKeyboardAction> keyboardActions;

  /// 随纸张滚动的日期头部，不进入正文历史。
  final Widget header;

  /// 在[context]注入纸张样式、栏目结构及业务动作；输入、菜单、选区和剪贴板均由共用视图维护。
  /// 编辑/预览使用同一排版配置，正文与滚动资源由共享组件按公开契约管理。
  @override
  Widget build(BuildContext context) {
    final plain =
        editorState.document.root.attributes[journalPlainDesktopAttribute] ==
        true;
    final baseStyle = blockCraftSnapshotRootStyle(
      editorState.document.root,
      plain
          ? const TextStyle(fontSize: 16, color: Colors.black)
          : const TextStyle(fontSize: 16, height: 2, color: Color(0xff3e4650)),
    ).copyWith(fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily);
    return ColoredBox(
      color: plain ? Colors.white : const Color(0xfffaf8f0),
      child: DocumentEditorView(
        editorState: editorState,
        preview: preview,
        header: header,
        editorKey: const ValueKey('journal-editor'),
        // padding 会作用于每个根栏目；悬浮按钮留白仅放在整篇文档的末尾。
        padding: EdgeInsets.fromLTRB(20, 0, 20, preview ? 0 : 40),
        footer: preview
            ? SizedBox(
                key: const ValueKey('journal-preview-bottom-space'),
                height: 96 * MediaQuery.textScalerOf(context).scale(16) / 16,
              )
            : null,
        onUserMention: (state) =>
            handleEditorUserMentionTrigger(context, state),
        configuration: EditorViewConfiguration(
          keyboardActions: keyboardActions,
          characterShortcuts: [journalParagraphEnter],
          style: (context, style) => style.copyWith(
            textSpanDecorator: decorateGuidanceMention,
            textScaleFactor: MediaQuery.textScalerOf(context).scale(16) / 16,
            cursorColor: const Color(0xff8b6e63),
            selectionColor: const Color(0x337e6257),
            textStyleConfiguration: TextStyleConfiguration(
              text: baseStyle,
              lineHeight: baseStyle.height ?? (plain ? 1.5 : 2),
              applyHeightToFirstAscent: true,
              applyHeightToLastDescent: true,
            ),
          ),
          blockBuilders: (builders) {
            if (plain) {
              return blockCraftSnapshotBuilders({
                ...builders,
                journalSectionType: _JournalSectionBuilder(),
              });
            }
            final config = BlockComponentConfiguration(
              padding: (_) => EdgeInsets.zero,
              placeholderText: (_) => ' ',
              textStyle: (node, {textSpan}) =>
                  textSpan?.children != null ? const TextStyle() : baseStyle,
            );
            final paperBuilders = <String, BlockComponentBuilder>{
              PageBlockKeys.type: PageBlockComponentBuilder(
                minimumBodyHeight: 0,
              ),
              journalSectionType: _JournalSectionBuilder(
                preview: preview,
                onClose: preview ? null : onCloseSection,
              ),
              ParagraphBlockKeys.type: ParagraphBlockComponentBuilder(
                configuration: config,
              ),
              HeadingBlockKeys.type: HeadingBlockComponentBuilder(
                configuration: config,
              ),
              BulletedListBlockKeys.type: BulletedListBlockComponentBuilder(
                configuration: config,
                iconBuilder: buildJournalBulletMarker,
              ),
              NumberedListBlockKeys.type: NumberedListBlockComponentBuilder(
                configuration: config,
                iconBuilder: buildJournalNumberMarker,
              ),
              TodoListBlockKeys.type: TodoListBlockComponentBuilder(
                configuration: config,
                iconBuilder: buildJournalTodoMarker,
              ),
            };
            final result = {
              ...builders,
              ...paperBuilders.map(
                (type, builder) => MapEntry(
                  type,
                  type == PageBlockKeys.type || type == journalSectionType
                      ? builder
                      : GuidanceTextBlockBuilder(
                          configureEditorTextBlock(
                            builder,
                            type,
                            listIndentWidth: 28,
                          ),
                        ),
                ),
              ),
            };
            return journalEditorConfiguration(
                  editorState.document,
                ).documentFeatures
                ? blockCraftSnapshotBuilders(result)
                : result;
          },
        ),
      ),
    );
  }
}

/// 为动态栏目注册纯结构渲染器，标题不进入可编辑正文。
class _JournalSectionBuilder extends BlockComponentBuilder {
  /// [preview] 收紧只读栏目留白；[onClose] 由页面处理栏目关闭，null 不展示按钮。
  _JournalSectionBuilder({this.preview = false, this.onClose});

  /// 本构建器所属视图的固定预览模式，不从可变编辑权限推断。
  final bool preview;

  /// 借用的业务关闭动作。
  final ValueChanged<String>? onClose;

  /// 使用[context]中的借用栏目构建结构组件。
  @override
  BlockComponentWidget build(BlockComponentContext context) => _JournalSection(
    key: context.node.key,
    node: context.node,
    configuration: configuration,
    preview: preview,
    onClose: onClose,
  );
}

/// 单个栏目外壳，使用一个编辑器渲染其全部子段落。
class _JournalSection extends BlockComponentStatelessWidget {
  /// [key]保持栏目身份，[node]为受保护的栏目，[configuration]为渲染配置。
  /// [preview] 仅改变只读留白，不修改节点；[onClose] 可空，由宿主负责保存关闭草稿及撤销。
  const _JournalSection({
    super.key,
    required super.node,
    required super.configuration,
    this.preview = false,
    this.onClose,
  });

  /// true 时收紧栏目末尾的纯空段落和书写留白，仅影响展示。
  final bool preview;

  /// 可选业务关闭回调，不释放。
  final ValueChanged<String>? onClose;

  /// 在 [context] 构建栏目和横格；编辑保留三行书写区，预览收紧末尾纯空段落。
  @override
  Widget build(BuildContext context) {
    final editor = context.read<EditorState>();
    if (editor.document.root.attributes[journalPlainDesktopAttribute] == true) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final child in node.children)
            editor.renderer.build(context, child),
        ],
      );
    }
    final titleDelta = node.attributes['guidance_heading_delta'];
    final title = titleDelta is List
        ? Delta.fromJson(titleDelta).toPlainText()
        : node.attributes['guidance_section_label'] as String? ??
              switch (node.attributes['section']) {
                'record' => '今日记录',
                'reflection' => '感悟',
                _ => '自检',
              };
    final lineHeight = MediaQuery.textScalerOf(context).scale(16) * 2;
    // 只从视图列表移除末尾普通空段落，正文、撤销历史和保存 JSON 均保留。
    final children = preview ? List<Node>.of(node.children) : node.children;
    if (preview) {
      while (children.length > 1 && _previewBlankParagraph(children.last)) {
        children.removeLast();
      }
    }
    return Padding(
      key: ValueKey('journal-section-${node.attributes['section']}'),
      padding: EdgeInsets.only(bottom: preview ? lineHeight : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xff9a9387),
                    ),
                  ),
                ),
                if (node.attributes['section'] != 'record' &&
                    !(node.attributes['section'] as String).startsWith(
                      'custom:',
                    ) &&
                    onClose != null)
                  InkWell(
                    key: ValueKey(
                      'journal-close-${node.attributes['section']}',
                    ),
                    onTap: () => onClose!(node.attributes['section'] as String),
                    child: const Text(
                      '关闭',
                      style: TextStyle(fontSize: 11, color: Color(0xff9a9387)),
                    ),
                  ),
              ],
            ),
          ),
          JournalRuledContent(
            onBlankTap: editor.editable
                ? () => editor.selection = Selection.collapsed(
                    Position(
                      path:
                          journalContentNodes(node.children)
                              .where((child) => child.delta != null)
                              .lastOrNull
                              ?.path ??
                          node.children.last.path,
                      offset:
                          journalContentNodes(node.children)
                              .where((child) => child.delta != null)
                              .lastOrNull
                              ?.delta
                              ?.length ??
                          0,
                    ),
                  )
                : null,

            textLines: false,
            minimumHeight: preview ? 0 : lineHeight * 3,
            lineHeight: lineHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final child in children)
                  JournalRuledContent(
                    key: ValueKey('journal-lines-${child.id}'),
                    lineHeight: lineHeight,
                    child: IgnorePointer(
                      ignoring: !editor.editable,
                      child: editor.renderer.build(context, child),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 判断借用的 [node] 是否为可在预览栏目末尾折叠的普通空段落。
/// 保留带任务/人员业务标记、子块或非空文本的块；不修改原节点或属性。
bool _previewBlankParagraph(Node node) =>
    node.type == ParagraphBlockKeys.type &&
    node.children.isEmpty &&
    node.attributes[guidanceEntryAttribute] == null &&
    node.delta != null &&
    node.delta!.toPlainText().trim().isEmpty;
