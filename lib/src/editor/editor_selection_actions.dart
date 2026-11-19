import 'package:applowy_editor_fork/applowy_editor_fork.dart';
import 'package:cses_editor/src/editor/blockcraft_json_codec.dart';
import 'package:cses_editor/src/editor/collab_block_locks.dart';
import 'package:cses_editor/src/editor/collab_formula_sheet.dart';
import 'package:cses_editor/src/editor/editor_shortcut_toolbar.dart';
import 'package:cses_editor/src/model/collab_inline_formula.dart';
import 'package:cses_editor/src/model/collab_meeting.dart';
import 'package:cses_editor/src/model/collab_mention_tap.dart';
import 'package:cses_editor/src/model/collab_task_card.dart';
import 'package:cses_editor/src/model/collab_text_range.dart';
import 'package:cses_editor/src/model/collab_user_mention.dart';
import 'package:cses_editor/src/editor/core/editor_command_context.dart';
import 'package:cses_editor/src/ui/modal/collab_dialog.dart';
import 'package:cses_editor/src/ui/modal/collab_modal.dart';
import 'package:cses_editor/src/ui/modal/collab_modal_colors.dart';
import 'package:cses_editor/src/ui/modal/collab_modal_field.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 在借用的 [context] 中按 [type] 调用宿主的创建流程；[editor] 及正文由调用方拥有。
/// [range] 用于锚定原文，并为会议主题或任务标题提供本次选中的文字。
/// [isEditorCurrent] 由调用方提供，用于拒绝组件更换编辑器后的迟到结果。
/// 等待表单退场，复核稳定块身份及权限后以独立撤销项替换原选区。取消保留原文；
/// 已创建但无法写入时提示。本函数只拥有临时权限信号，发布异常透传菜单。
Future<void> showEditorSelectionReference(
  BuildContext context,
  EditorState editor,
  CollabTextRange range, {
  required CollabMentionType type,
  required bool Function() isEditorCurrent,
}) async {
  final commands = EditorCommandContext.of(editor);
  final services = commands.services;
  final kind = switch (type) {
    CollabMentionType.meeting => '会议',
    CollabMentionType.task => '任务',
    _ => null,
  };
  if (kind == null ||
      !range.canConvert ||
      !commands.configuration.allowsFormat(collabInlineMentionAttribute)) {
    return;
  }
  final document = editor.document;

  /// 核对页面、正文和会话端口，写入时另行复核权限和范围。
  bool isCurrent() =>
      context.mounted &&
      isEditorCurrent() &&
      !editor.isDisposed &&
      identical(editor.document, document) &&
      identical(EditorCommandContext.of(editor), commands);

  if (!isCurrent() || !editor.canInputAt(range.resolve(editor))) return;
  final canEdit = ValueNotifier(true);
  final locks = CollabBlockLocks.of(editor);

  /// 永久撤销本次发布授权；发布页只借用该信号。
  void revoke() => canEdit.value = false;

  /// 编辑权限丢失后，重新授权只影响下一次划词。
  void trackEditable() {
    if (!isCurrent() || !editor.canInputAt(range.resolve(editor))) revoke();
  }

  Selection? landing;
  editor.editableNotifier.addListener(trackEditable);
  locks?.addListener(trackEditable);
  editor.onDispose.addListener(revoke);
  try {
    await runEditorHeaderAction<void>(
      context,
      editor,
      () async {
        final (String, String)? reference;
        if (type == CollabMentionType.meeting) {
          final meeting = await services.createMeetingFromText?.call(
            context,
            initialTitle: range.text.trim(),
            canEdit: canEdit,
          );
          reference = meeting == null
              ? null
              : (meeting.meetingId, meeting.title);
        } else {
          final task = await services.createTaskFromSelection?.call(
            context,
            initialTitle: range.text.trim(),
            canEdit: canEdit,
          );
          reference = task == null ? null : (task.taskId, task.title);
        }
        if (reference == null || !isCurrent()) return;
        final (id, title) = reference;
        final selection = range.resolve(editor);
        final valid = switch (type) {
          CollabMentionType.meeting => CollabMeeting.valid({
            'meetingId': id,
            'title': title,
          }),
          CollabMentionType.task => CollabTaskCard.valid({
            'taskId': id,
            'title': title,
          }),
          _ => false,
        };
        if (canEdit.value &&
            selection != null &&
            editor.canInputAt(selection) &&
            title.trim().isNotEmpty &&
            valid) {
          final node = editor.getNodeAtPath(selection.start.path)!;
          final start = selection.start.offset;
          final before = node.delta!.slice(start, selection.end.offset);
          final after = BlockCraftJsonCodec.decodeInline([
            {
              'insert': {'mention': title},
              'attributes': {'mentionId': id, 'mentionType': type.name},
            },
          ]);
          final caret = Selection.single(
            path: node.path,
            startOffset: start + 1,
          );
          try {
            await applyCollabInlineCommand(
              editor,
              node,
              start,
              before,
              after,
              historyBeforeSelection: selection,
              historyAfterSelection: caret,
            );
          } catch (error, stack) {
            services.report('已创建的$kind引用写入失败', error, stack, 'DocCollab');
          }
          if (!isCurrent()) return;
          final current = editor.getNodeAtPath(node.path);
          if (identical(current, node) &&
              node.delta?.slice(start, start + 1) == after) {
            landing = caret;
            return;
          }
        }
        final message = '$kind已创建，未能添加到正文';
        final feedback = services.showFeedback;
        if (feedback == null) {
          if (context.mounted) _selectionMessage(context, message);
        } else {
          feedback(message);
        }
      },
      canRestore: () =>
          isCurrent() &&
          canEdit.value &&
          (landing != null || range.resolve(editor) != null),
      selectionAfterAction: () => landing,
    );
  } finally {
    editor.editableNotifier.removeListener(trackEditable);
    locks?.removeListener(trackEditable);
    editor.onDispose.removeListener(revoke);
    canEdit.dispose();
  }
}

/// 在借用 [context]/[editor] 中编辑单段文字链接；取消不写入。
/// 仅修改 href，保留原文和其他格式；弹窗完整退场后重新核对稳定身份、原文及权限。
/// 错误由此边界报告，失败保留原文并显示提示，不拥有编辑器。
Future<void> showEditorTextLink(
  BuildContext context,
  EditorState editor,
) async {
  final range = CollabTextRange.capture(editor);
  if (!editor.editable || range == null || !range.canConvert) return;
  final selection = range.resolve(editor)!;
  final node = editor.getNodeAtPath(selection.start.path)!;
  final selected = node.delta!.slice(
    selection.start.offset,
    selection.end.offset,
  );
  final links = selected
      .map((op) => op.attributes?[AppFlowyRichTextKeys.href])
      .toList();
  final initial =
      links.every((link) => link == links.first) && links.first is String
      ? links.first as String
      : '';
  try {
    await runEditorHeaderAction<void>(context, editor, () async {
      final result = await showCollabDialog<String>(
        context: context,
        builder: (dialogContext) {
          return _TextLinkDialog(
            initial: initial,
            canRemove: links.any((link) => link is String),
          );
        },
      );

      if (result == null ||
          !context.mounted ||
          editor.isDisposed ||
          !editor.editable) {
        return;
      }
      final current = range.resolve(editor);
      if (current == null) {
        _selectionMessage(context, '选中文字已变化，请重新选择');
        return;
      }
      if (editor.undoManager.undoStack.isNonEmpty) {
        editor.undoManager.undoStack.last.seal();
      }
      final target = editor.getNodeAtPath(current.start.path)!;
      await editor.apply(
        editor.transaction..formatText(
          target,
          current.start.offset,
          current.end.offset - current.start.offset,
          {AppFlowyRichTextKeys.href: result.isEmpty ? null : result},
        ),
        withUpdateSelection: false,
        skipHistoryDebounce: true,
      );
    });
  } catch (error, stack) {
    EditorCommandContext.of(
      editor,
    ).services.report('文字链接修改失败', error, stack, 'DocCollab');
    if (context.mounted) _selectionMessage(context, '链接修改失败，请重试');
  }
}

/// 在借用 [context]/[editor] 中预填选中文字并预览 LaTeX，确认后复用行内公式原子命令。
/// 仅支持单段非空普通文字；取消、权限撤销及原文或格式变化均不替换。
/// 成功作为独立历史项，撤销恢复原文字及格式；面板退场后恢复公式后的光标。
Future<void> showEditorSelectionFormula(
  BuildContext context,
  EditorState editor,
) async {
  final range = CollabTextRange.capture(editor);
  if (!editor.editable || range == null || !range.canConvert) return;
  Selection? landing;
  try {
    await runEditorHeaderAction<void>(context, editor, () async {
      final latex = await showCollabFormulaInput(
        context,
        editor,
        initialLatex: range.text,
      );
      if (latex == null ||
          !context.mounted ||
          editor.isDisposed ||
          !editor.editable) {
        return;
      }
      final current = range.resolve(editor);
      if (current == null) {
        _selectionMessage(context, '选中文字已变化，请重新选择');
        return;
      }
      landing = await insertCollabInlineFormula(editor, current, latex);
      if (landing == null && context.mounted) {
        _selectionMessage(context, '此处无法转换为行内公式');
      }
    }, selectionAfterAction: () => landing);
  } catch (error, stack) {
    EditorCommandContext.of(
      editor,
    ).services.report('选中文字转换公式失败', error, stack, 'DocCollab');
    if (context.mounted) _selectionMessage(context, '转换失败，请重试');
  }
}

/// 在借用 [context] 中提示可重试的选区错误，[message] 为面向用户的原因。
void _selectionMessage(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(message)));
}

/// 文字链接输入框，拥有输入控制器；返回空字符串表示移除链接，null 表示取消。
class _TextLinkDialog extends StatefulWidget {
  /// [initial] 为共同链接或空字符串，[canRemove] 表示选区至少包含一个链接。
  const _TextLinkDialog({required this.initial, required this.canRemove});

  /// 初始共同链接；空值显示地址提示，不代表移除。
  final String initial;

  /// 是否显示移除入口；混合选区只要有链接就允许清除。
  final bool canRemove;

  /// 创建本弹窗持有的输入状态。
  @override
  createState() => _TextLinkDialogState();
}

/// 持有链接输入和错误提示，不直接修改正文。
class _TextLinkDialogState extends State<_TextLinkDialog> {
  late final TextEditingController _input;
  String? _error;

  /// 复制初始链接，输入控制器由本状态释放。
  @override
  void initState() {
    super.initState();
    _input = TextEditingController(text: widget.initial);
  }

  /// 释放弹窗创建的输入资源。
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  /// 校验显式协议，禁止脚本或不完整地址；合法结果只返回调用方，尚不写正文。
  void _confirm() {
    final value = _input.text.trim();
    final uri = Uri.tryParse(value);
    final valid =
        value.length <= 4096 &&
        !RegExp(r'\s').hasMatch(value) &&
        uri != null &&
        ((const {'http', 'https'}.contains(uri.scheme) &&
                uri.host.isNotEmpty) ||
            (const {'mailto', 'tel'}.contains(uri.scheme) &&
                uri.path.isNotEmpty));
    if (!valid) {
      setState(() => _error = '请输入完整的 http(s)、mailto 或 tel 链接');
      return;
    }
    Navigator.pop(context, value);
  }

  /// 在借用 [context] 中展示输入和红色移除动作，取消不产生结果。
  @override
  Widget build(BuildContext context) => CollabDialog(
    icon: LucideIcons.link,
    title: const Text('文字链接'),
    content: CollabModalField(
      label: '链接地址',
      child: TextField(
        key: const ValueKey('editor-text-link-input'),
        controller: _input,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: InputDecoration(
          hintText: 'https://example.com',
          errorText: _error,
        ),
        onSubmitted: (_) => _confirm(),
      ),
    ),
    leadingAction: widget.canRemove
        ? TextButton(
            key: const ValueKey('editor-text-link-remove'),
            style: TextButton.styleFrom(
              foregroundColor: CollabModalColors.of(context).danger,
            ),
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('移除链接'),
          )
        : null,
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        key: const ValueKey('editor-text-link-save'),
        onPressed: _confirm,
        child: const Text('保存'),
      ),
    ],
  );
}
