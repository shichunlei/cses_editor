import 'package:applowy_editor_fork/applowy_editor_fork.dart';
import 'package:cses_editor/src/ui/modal/collab_editor_display_scope.dart';
import 'package:flutter/widgets.dart';

/// Renders [node] in the borrowed [editor] and [context], applying the current
/// preview's interaction rules to a structural block's child.
/// The renderer and resulting widget retain their existing resource ownership.
///
/// ```dart
/// final child = buildEditorChildBlock(context, editor, node);
/// ```
Widget buildEditorChildBlock(
  BuildContext context,
  EditorState editor,
  Node node,
) {
  return wrapEditorPreviewBlock(
    context,
    node: node,
    child: editor.renderer.build(context, node),
  );
}

/// Applies the preview rules from [context] to the borrowed [node] and [child].
/// Structural renderers apply the same rules to their own children.
Widget wrapEditorPreviewBlock(
  BuildContext context, {
  required Node node,
  required Widget child,
}) {
  final scope = CollabEditorDisplayScope.maybeOf(context);
  if (scope == null || !scope.preview) return child;
  final allowsMedia =
      scope.previewMediaInteractions &&
      const {'image', 'video', 'audio', 'attachment'}.contains(node.type);
  final allowsChildren =
      scope.previewMediaInteractions &&
      (const {
            'callout',
            'columns',
            'column',
            'table',
            'table-row',
            'table-cell',
            'snapshot-columns',
            'snapshot-column',
            'snapshot-placement-layout',
            'snapshot-object-group',
            'snapshot-render-unit',
            'snapshot-shape',
            'snapshot-text-box',
          }.contains(node.type) ||
          scope.previewContainerTypes.contains(node.type));
  return IgnorePointer(
    ignoring: !(allowsMedia || allowsChildren),
    child: ExcludeFocus(child: child),
  );
}
