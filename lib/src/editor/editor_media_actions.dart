import 'dart:convert';

import 'package:applowy_editor_fork/applowy_editor_fork.dart';
import 'package:cses_editor/src/editor/collab_block_actions.dart';
import 'package:cses_editor/src/editor/collab_block_locks.dart';
import 'package:cses_editor/src/editor/core/editor_command_context.dart';
import 'package:cses_editor/src/editor/editor_media_source_sheet.dart';
import 'package:cses_editor/src/model/collab_resource.dart';
import 'package:flutter/widgets.dart';

/// Whether [node] is one of the four media types inside a container authorized
/// by the borrowed [editor]'s host configuration. The transaction guard still
/// controls every mutation.
bool isHostedEditorMedia(EditorState editor, Node node) {
  final config = EditorCommandContext.of(editor).configuration;
  return const {'image', 'video', 'audio', 'attachment'}.contains(node.type) &&
      config.allowsBlock(node.type) &&
      config.mediaContainerTypes.contains(node.parent?.type);
}

/// Builds the replacement action for borrowed [editor], [node] and [context].
/// [label] names the action. A host with file picking can replace by file or
/// link; generic local editors retain their existing property menus.
Iterable<({String label, Key? key, Future<void> Function() run})>
editorMediaReplacementActions(
  BuildContext context,
  EditorState editor,
  Node node, {
  required String label,
}) sync* {
  if (EditorCommandContext.of(editor).services.mediaUpload == null) return;
  yield (
    label: label,
    key: ValueKey('replace-media-${node.type}'),
    run: () => _replaceMedia(context, editor, node),
  );
}

/// Selects a source for borrowed [node] through the existing sheet in [context].
/// Commits URL and file metadata in a single undo step on [editor]. Cancelling,
/// losing edit permission or changing the target while the picker is open
/// discards the result. The sheet owns upload cancellation.
Future<void> _replaceMedia(
  BuildContext context,
  EditorState editor,
  Node node,
) async {
  final services = EditorCommandContext.of(editor).services;
  final id = CollabBlockLocks.idOf(node);
  final parent = node.parent;
  final original = jsonEncode(node.attributes);
  var revoked = false;

  /// Records an edit permission loss for the duration of this picker.
  void observePermission() {
    if (!editor.editable) revoked = true;
  }

  /// Confirms the same editable media reference is still present.
  bool isCurrent() =>
      context.mounted &&
      !revoked &&
      !editor.isDisposed &&
      editor.editable &&
      identical(EditorCommandContext.of(editor).services, services) &&
      identical(findCollabActionNode(editor, id), node) &&
      identical(node.parent, parent) &&
      jsonEncode(node.attributes) == original &&
      canEditCollabNode(editor, node);

  if (!isCurrent()) return;
  editor.editableNotifier.addListener(observePermission);
  try {
    final source = await showEditorMediaSourceSheet(
      context,
      blockType: node.type,
      replacing: true,
      initialValue: node.attributes['url'] as String? ?? '',
      canEdit: isCurrent,
      editorState: editor,
    );
    if (source == null || !isCurrent()) return;
    if (source.file == null && source.url == node.attributes['url']) return;
    if (!isCollabResourceUrl(node.type, source.url)) {
      throw const FormatException('资源链接无效');
    }
    final file = source.file;
    final attributes = <String, dynamic>{'url': source.url};
    if (node.type == 'audio' || node.type == 'attachment') {
      final fields = <String, Object?>{
        'name':
            file?.name ??
            (node.type == 'attachment'
                ? Uri.parse(source.url).pathSegments.lastOrNull
                : null),
        'size': file?.size,
        if (node.type == 'attachment') 'type': file?.mimeType,
        if (node.type == 'audio') 'sourceType': file == null ? 'link' : 'local',
      };
      final resource = CollabResource.fromValues({
        for (final entry in fields.entries)
          if (entry.value != null) entry.key: entry.value,
      });
      for (final key in fields.keys) {
        attributes[resourcePropertyAttribute(key)] = resource.field(key);
      }
    }
    final transaction = editor.transaction..updateNode(node, attributes);
    if (!editor.canApplyTransaction(transaction)) {
      throw StateError('媒体替换未通过正文校验');
    }
    if (editor.undoManager.undoStack.isNonEmpty) {
      editor.undoManager.undoStack.last.seal();
    }
    await editor.apply(
      transaction,
      withUpdateSelection: false,
      skipHistoryDebounce: true,
    );
  } finally {
    editor.editableNotifier.removeListener(observePermission);
  }
}
