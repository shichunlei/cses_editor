import 'dart:convert';

import 'package:applowy_editor_fork/applowy_editor_fork.dart';
import 'package:cses_editor/src/editor/core/editor_command_context.dart';
import 'package:cses_editor/src/editor/editor_shortcut_toolbar.dart';
import 'package:cses_editor/src/model/collab_host_services.dart';
import 'package:cses_editor/src/model/collab_inline_formula.dart';
import 'package:cses_editor/src/model/collab_mention_tap.dart';
import 'package:cses_editor/src/model/collab_user_mention.dart';
import 'package:flutter/material.dart';

import 'package:cses_editor/src/ui/modal/collab_editor_display_scope.dart';

/// 每个编辑器同时只运行一个提及面板或点击；弱关联不延长编辑器生命周期。
final _pendingMentionTap = Expando<bool>('pendingMentionTap');

/// 从借用[node]的UTF-16[offset]读取回调快照；不是有效提及时返回null。
/// 原始属性损坏或尚未就绪时抛出StateError/FormatException，不从业务接口补造属性。
CollabMentionTap? collabMentionTapAt(Node node, int offset) {
  final delta = node.delta;
  if (delta == null || offset < 0 || offset >= delta.length) return null;
  final operation = delta.slice(offset, offset + 1).first;
  final attrs = operation.attributes;
  if (operation is! TextInsert ||
      operation.text != collabInlineFormulaCharacter) {
    return null;
  }
  final kind = attrs?[collabMentionTypeAttribute] as String? ?? 'user';
  final type = CollabMentionType.values
      .where((v) => v.name == kind)
      .firstOrNull;
  final id = attrs?[collabMentionIdAttribute];
  final name = attrs?[collabInlineMentionAttribute];
  if (type == null || id is! String || id.isEmpty || name is! String) {
    return null;
  }
  final raw = attrs?[collabMentionAttributesAttribute];
  if (raw is! String) throw StateError('提及原始属性尚未就绪，请在投影确认后重试');
  return CollabMentionTap(
    type: type,
    id: id,
    name: name,
    attributes: jsonDecode(raw) as Map<String, dynamic>,
  );
}

/// 在借用[context]/[state]中串行运行提及[action]，向其提供本次冻结的宿主服务。
/// action须等待弹窗退场、回调完成，并自行在异步间隔后复核目标及会话。
/// 编辑态暂停正文输入，忽略重复点击；完成后仅向有效原页面恢复选区。
/// 只读预览仅等待宿主回调，不创建编辑模态会话、块锁租约或恢复选区与键盘。
/// [restoreFocus]默认true，卡片可传false以防操作结束后弹正文键盘。
/// 异常向原宿主报告，失效会话不提示；不拥有编辑器、宿主或导航资源。
Future<void> runCollabMentionInteraction(
  BuildContext context,
  EditorState state,
  Future<void> Function(CollabHostServices services) action, {
  bool restoreFocus = true,
}) async {
  if (!context.mounted ||
      state.isDisposed ||
      _pendingMentionTap[state] == true) {
    return;
  }
  final services = EditorCommandContext.of(state).services;
  _pendingMentionTap[state] = true;
  try {
    /// 复核当前页面和借用服务后执行原动作，不持有额外资源或编辑权限。
    Future<void> invoke() async {
      if (!context.mounted ||
          state.isDisposed ||
          !identical(EditorCommandContext.of(state).services, services)) {
        return;
      }
      await action(services);
    }

    if (CollabEditorDisplayScope.maybeOf(context)?.preview == true) {
      await invoke();
    } else {
      await runEditorHeaderAction<void>(
        context,
        state,
        invoke,
        canRestore: () =>
            restoreFocus &&
            identical(EditorCommandContext.of(state).services, services),
      );
    }
  } catch (error, stack) {
    services.report('提及点击操作失败', error, stack, 'DocCollab');
    if (context.mounted &&
        !state.isDisposed &&
        identical(EditorCommandContext.of(state).services, services)) {
      if (services.showFeedback case final feedback?) {
        feedback('操作失败，请重试');
      } else {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(const SnackBar(content: Text('操作失败，请重试')));
      }
    }
  } finally {
    _pendingMentionTap[state] = null;
  }
}

/// 处理借用[context]/[state]中[node]的UTF-16[offset]点击。
/// 仅配置宿主onMentionTap时暂停输入并派发；无回调直接返回，不创建默认业务面板。
/// 失效节点、位置或会话不派发，原始属性与异常语义沿用[collabMentionTapAt]及交互包装。
Future<void> handleCollabMentionTap(
  BuildContext context,
  EditorState state,
  Node node,
  int offset,
) async {
  if (EditorCommandContext.of(state).services.onMentionTap == null) return;
  await runCollabMentionInteraction(context, state, (services) async {
    final blockId =
        node.attributes['cses_collab_block_id'] as String? ?? node.id;
    final current = findCollabInlineTextNode(state, blockId);
    if (current == null ||
        offset < 0 ||
        offset >= current.delta!.length ||
        current.delta!.slice(offset, offset + 1) !=
            node.delta?.slice(offset, offset + 1)) {
      return;
    }
    final event = collabMentionTapAt(current, offset);
    if (event != null) await services.onMentionTap?.call(event);
  });
}

/// 判断借用 [node] 是否含可展示的会议、任务或人员原子，仅用于放行该块内的只读命中。
/// 不解析业务详情、不授予普通文字编辑或菜单；损坏/空身份不作为交互入口。
bool hasPreviewableCollabMention(Node node) =>
    node.delta?.whereType<TextInsert>().any(
      (run) =>
          const {
            'meeting',
            'task',
            'user',
          }.contains(run.attributes?[collabMentionTypeAttribute] ?? 'user') &&
          run.attributes?[collabInlineMentionAttribute] is String &&
          run.attributes?[collabMentionIdAttribute] is String &&
          (run.attributes![collabMentionIdAttribute] as String)
              .trim()
              .isNotEmpty &&
          run.text.contains(collabInlineFormulaCharacter),
    ) ??
    false;

/// 在借用 [context]/[state] 中直接打开 [node] 的 UTF-16 [offset] 引用详情。
/// 只在显式启用的只读预览派发；等待宿主详情关闭期间共享原防重复锁，不恢复输入。
/// 当前节点/原子身份变化、空 ID、无回调或页面关闭均不导航；原始属性使用独立只读快照。
Future<void> handleCollabPreviewMentionTap(
  BuildContext context,
  EditorState state,
  Node node,
  int offset,
) async {
  final display = CollabEditorDisplayScope.maybeOf(context);
  if (display?.preview != true || display?.previewMentionInteractions != true) {
    return;
  }
  await runCollabMentionInteraction(context, state, (services) async {
    if (CollabEditorDisplayScope.maybeOf(context)?.previewMentionInteractions !=
        true) {
      return;
    }
    final blockId =
        node.attributes['cses_collab_block_id'] as String? ?? node.id;
    final current = findCollabInlineTextNode(state, blockId);
    if (current == null ||
        offset < 0 ||
        offset >= current.delta!.length ||
        current.delta!.slice(offset, offset + 1) !=
            node.delta?.slice(offset, offset + 1)) {
      return;
    }
    final event = collabMentionTapAt(current, offset);
    if (event == null || event.id.trim().isEmpty) return;
    final callback = switch (event.type) {
      CollabMentionType.meeting =>
        services.onMeetingMentionTap ?? services.onMentionTap,
      CollabMentionType.task =>
        services.onTaskMentionTap ?? services.onMentionTap,
      CollabMentionType.user => services.onMentionTap,
      _ => null,
    };
    await callback?.call(event);
  }, restoreFocus: false);
}
