import 'dart:math' as math;

import 'package:applowy_editor_fork/applowy_editor_fork.dart';
import 'package:cses_editor/src/model/collab_block_colors.dart';
import 'package:cses_editor/src/editor/appflowy_block_editor_adapter.dart';
import 'package:cses_editor/src/editor/collab_ordered_marker.dart';
import 'package:cses_editor/src/editor/collab_inline_entity_mention.dart';
import 'package:cses_editor/src/editor/collab_task_text_flow.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 两端对齐由 Flutter 原生排版；分散对齐使用相同文本和 UTF-16 偏移展开字距。
TextAlign collabTextAlign(Node node) =>
    switch (node.attributes[blockComponentAlign]) {
      'center' => TextAlign.center,
      'right' => TextAlign.right,
      'justify' || 'distributed' => TextAlign.justify,
      _ => TextAlign.left,
    };

/// 复用标准块的样式与操作，分散对齐和换行任务引用使用共用文字外壳。
/// 宿主通过公开排版入口取得包装器，不接管正文资源。
///
/// ```dart
/// import 'package:applowy_editor_fork/applowy_editor_fork.dart';
/// import 'package:cses_editor/cses_editor.dart';
/// final builder = configureEditorTextBlock(
///   ParagraphBlockComponentBuilder(), ParagraphBlockKeys.type);
/// // 注册到借用 EditorState 的 AppFlowyEditor.blockComponentBuilders。
/// ```
class CollabTextAlignmentBuilder extends BlockComponentBuilder {
  /// [standard]提供原生排版和可选列表标记，仅借用，不拥有编辑会话。
  CollabTextAlignmentBuilder(this.standard)
    : super(configuration: standard.configuration) {
    standard.configuration = standard.configuration.copyWith(
      textAlign: collabTextAlign,
    );
    validate = standard.validate;
  }

  /// 借用的原生构建器，复用其自定义列表标记。
  final BlockComponentBuilder standard;

  /// 在借用的[context]中构建原生或有展示映射的文字，保留宿主列表标记。
  @override
  BlockComponentWidget build(BlockComponentContext context) {
    if (context.node.attributes[blockComponentAlign] != 'distributed' &&
        !hasFlowingTaskMention(context.node)) {
      return standard.build(context);
    }
    final original = standard.build(context);
    return _CollabTextBlock(
      key: context.node.key,
      standard: standard,
      node: context.node,
      configuration: original.configuration,
      showActions: original.showActions,
      actionBuilder: original.actionBuilder,
      actionTrailingBuilder: original.actionTrailingBuilder,
    );
  }
}

class _CollabTextBlock extends BlockComponentStatefulWidget {
  /// [key]维持组件身份，[node]和[configuration]为借用的正文及排版配置。
  /// [standard]提供自定义标记，[showActions]/[actionBuilder]/[actionTrailingBuilder]沿用原生块动作。
  const _CollabTextBlock({
    super.key,
    required super.node,
    required super.configuration,
    required this.standard,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
  });

  /// 借用的原生构建器，不承担资源释放。
  final BlockComponentBuilder standard;

  /// 创建本块的原生选区与输入委托。
  @override
  createState() => _CollabTextBlockState();
}

class _CollabTextBlockState extends State<_CollabTextBlock>
    with
        SelectableMixin,
        DefaultSelectableMixin,
        BlockComponentConfigurable,
        BlockComponentBackgroundColorMixin,
        NestedBlockComponentStatefulWidgetMixin,
        BlockComponentTextDirectionMixin {
  @override
  final forwardKey = GlobalKey(debugLabel: 'collab-rich-text');
  @override
  GlobalKey get containerKey => node.key;
  @override
  final blockComponentKey = GlobalKey(debugLabel: 'collab-text-block');
  @override
  Node get node => widget.node;
  @override
  BlockComponentConfiguration get configuration => widget.configuration;
  late final _flow = CollabTaskTextFlow(
    onTap: (offset) =>
        showCollabEntityMentionActions(context, editorState, node, offset),
  );

  /// Disposes the title gesture recognizers owned by this block.
  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  /// Maps a display [position] from this block to its document boundary.
  Position _documentPosition(Position position, {bool? trailing}) => position
      .copyWith(offset: _flow.toDocument(position.offset, trailing: trailing));

  /// Maps both display endpoints in [selection] back to document coordinates.
  /// A nonempty drag snaps an interior endpoint outwards to include the atom.
  Selection _documentSelection(Selection selection) {
    if (selection.isCollapsed) {
      return Selection.collapsed(_documentPosition(selection.start));
    }
    final range = selection.normalized;
    final mapped = Selection(
      start: _documentPosition(range.start, trailing: false),
      end: _documentPosition(range.end, trailing: true),
    );
    return selection.start == range.start ? mapped : mapped.reversed;
  }

  /// Hit-tests [start] in global coordinates and returns a model offset.
  @override
  Position getPositionInOffset(Offset start) =>
      _documentPosition(forward.getPositionInOffset(start));

  /// Hit-tests the global [start] and [end] of a drag as an atomic selection.
  @override
  Selection getSelectionInRange(Offset start, Offset end) =>
      _documentSelection(forward.getSelectionInRange(start, end));

  /// Finds the caret near global [offset] using the same word rules as the editor.
  @override
  Selection? getWordEdgeInOffset(Offset offset) {
    final hit = forward.getPositionInOffset(offset);
    if (_flow.taskAt(hit.offset) != null) {
      return Selection.collapsed(_documentPosition(hit));
    }
    final wordEdge = forward.getWordEdgeInOffset(offset);
    return wordEdge == null ? null : _documentSelection(wordEdge);
  }

  /// Returns the entire atom for a global [offset] within its rendered title.
  @override
  Selection? getWordBoundaryInOffset(Offset offset) {
    final atom = _flow.taskAt(forward.getPositionInOffset(offset).offset);
    if (atom != null) return _atomSelection(atom);
    final word = forward.getWordBoundaryInOffset(offset);
    return word == null ? null : _documentSelection(word);
  }

  /// Resolves the word containing document [position], selecting task atoms whole.
  @override
  Selection? getWordBoundaryInPosition(Position position) {
    final displayOffset = _flow.toDisplay(position.offset);
    final atom = _flow.taskAt(displayOffset);
    if (atom != null) return _atomSelection(atom);
    final word = forward.getWordBoundaryInPosition(
      position.copyWith(offset: displayOffset),
    );
    return word == null ? null : _documentSelection(word);
  }

  /// Returns the single document character at task [offset].
  Selection _atomSelection(int offset) => Selection.single(
    path: node.path,
    startOffset: offset,
    endOffset: offset + 1,
  );

  /// Maps model [selection] to display rectangles, including every line of a
  /// selected task. [shiftWithBaseOffset] selects block-local coordinates.
  @override
  List<Rect> getRectsInSelection(
    Selection selection, {
    bool shiftWithBaseOffset = false,
  }) {
    if (!_flow.isExpanded) {
      return super.getRectsInSelection(
        selection,
        shiftWithBaseOffset: shiftWithBaseOffset,
      );
    }
    final range = selection.normalized;
    final path = node.path;
    if (path < range.start.path || path > range.end.path) return [];
    final start = path.equals(range.start.path) ? range.start.offset : 0;
    final end = path.equals(range.end.path)
        ? range.end.offset
        : node.delta!.length;
    return super.getRectsInSelection(
      Selection.single(
        path: path,
        startOffset: _flow.toDisplay(start),
        endOffset: _flow.toDisplay(end),
      ),
      shiftWithBaseOffset: shiftWithBaseOffset,
    );
  }

  /// Locates the caret for document [position] in the expanded paragraph.
  /// [shiftWithBaseOffset] adds the rich-text origin within the block.
  @override
  Rect? getCursorRectInPosition(
    Position position, {
    bool shiftWithBaseOffset = false,
  }) {
    if (!_flow.isExpanded) {
      return super.getCursorRectInPosition(
        position,
        shiftWithBaseOffset: shiftWithBaseOffset,
      );
    }
    if (position.offset < 0 || position.offset > node.delta!.length) {
      return null;
    }
    final paragraph = _flow.paragraphIn(
      forwardKey.currentContext?.findRenderObject(),
    );
    if (paragraph == null ||
        !paragraph.hasSize ||
        (kDebugMode && paragraph.debugNeedsLayout)) {
      return null;
    }
    final caret = TextPosition(offset: _flow.toDisplay(position.offset));
    final origin = paragraph.getOffsetForCaret(caret, Rect.zero);
    final width = editorState.editorStyle.cursorWidth;
    return Rect.fromLTWH(
      math.max(0, origin.dx - width / 2),
      origin.dy,
      width,
      paragraph.getFullHeightForCaret(caret),
    ).shift(baseOffset(shiftWithBaseOffset: shiftWithBaseOffset));
  }

  /// 按[direction]复用宿主的列表标记；未自定义时保留原有默认标记。
  Widget? _marker(TextDirection direction) {
    final standard = widget.standard;
    if (standard is NumberedListBlockComponentBuilder &&
        standard.iconBuilder != null) {
      return standard.iconBuilder!(context, node, direction);
    }
    if (standard is BulletedListBlockComponentBuilder &&
        standard.iconBuilder != null) {
      return standard.iconBuilder!(context, node);
    }
    if (standard is TodoListBlockComponentBuilder &&
        standard.iconBuilder != null) {
      return standard.iconBuilder!(context, node, () async {
        if (!editorState.editable || editorState.isDisposed) return;
        await editorState.apply(
          editorState.transaction..updateNode(node, {
            TodoListBlockKeys.checked:
                node.attributes[TodoListBlockKeys.checked] != true,
          }),
        );
      });
    }
    final scale = editorState.editorStyle.textScaleFactor;
    switch (node.type) {
      case NumberedListBlockKeys.type:
        return buildCollabOrderedMarker(context, node, direction);
      case BulletedListBlockKeys.type:
        return SizedBox(
          width: 26 * scale,
          height: 22 * scale,
          child: Center(child: Text('•', textScaler: TextScaler.linear(scale))),
        );
      case TodoListBlockKeys.type:
        return SizedBox(
          width: 26 * scale,
          height: 22 * scale,
          child: Checkbox(
            value: node.attributes[TodoListBlockKeys.checked] == true,
            onChanged: !editorState.editable
                ? null
                : (value) async {
                    await editorState.apply(
                      editorState.transaction
                        ..updateNode(node, {TodoListBlockKeys.checked: value}),
                    );
                  },
          ),
        );
      default:
        return null;
    }
  }

  /// 在借用 [context] 中复用块样式，并将任务标题交给正文排版。
  /// [withBackgroundColor] 由嵌套布局决定是否由本块绘制背景。
  @override
  Widget buildComponent(
    BuildContext context, {
    bool withBackgroundColor = true,
  }) {
    final direction = calculateTextDirection(
      layoutDirection: Directionality.maybeOf(context),
    );
    final marker = _marker(direction);
    final distributed = node.attributes[blockComponentAlign] == 'distributed';
    Widget text = LayoutBuilder(
      builder: (context, constraints) {
        return AppFlowyRichText(
          key: forwardKey,
          delegate: this,
          node: node,
          editorState: editorState,
          textAlign: textAlign,
          textDirection: direction,
          placeholderText: placeholderText,
          placeholderTextSpanDecorator: (span) => span.updateTextStyle(
            placeholderTextStyleWithTextSpan(textSpan: span),
          ),
          textSpanDecorator: (span) {
            var styled = span.updateTextStyle(
              textStyleWithTextSpan(textSpan: span),
            );
            if (node.type == TodoListBlockKeys.type &&
                node.attributes[TodoListBlockKeys.checked] == true) {
              styled = styled.updateTextStyle(
                TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: Colors.grey.shade400,
                ),
              );
            }
            // AppFlowy 同时用此回调修饰单个格式分段；只有完整树参与行布局。
            if (span.children == null) return styled;
            styled = _flow.project(styled);
            if (!distributed) return styled;
            return distributeTextSpan(
              styled,
              width: constraints.maxWidth,
              direction: direction,
              scaler: TextScaler.linear(
                editorState.editorStyle.textScaleFactor,
              ),
            );
          },
          cursorColor: editorState.editorStyle.cursorColor,
          selectionColor: editorState.editorStyle.selectionColor,
          cursorWidth: editorState.editorStyle.cursorWidth,
        );
      },
    );
    if (marker != null) {
      text = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        textDirection: direction,
        children: [
          marker,
          Expanded(child: text),
        ],
      );
    }
    if (node.type == QuoteBlockKeys.type) {
      text = Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color:
                  parseCollabBlockColor(
                    node.attributes[csesBlockBorderColorAttribute] as String?,
                  ) ??
                  const Color(0xff00bcf0),
              width: 3,
            ),
          ),
        ),
        padding: const EdgeInsets.only(left: 8),
        child: text,
      );
    }
    Widget child = Container(
      key: blockComponentKey,
      decoration: withBackgroundColor ? decoration : null,
      padding: padding,
      width: double.infinity,
      child: text,
    );
    child = BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: editorState.selectionNotifier,
      remoteSelection: editorState.remoteSelections,
      blockColor: editorState.editorStyle.selectionColor,
      supportTypes: const [BlockSelectionType.block],
      child: child,
    );
    if (widget.showActions && widget.actionBuilder != null) {
      child = BlockComponentActionWrapper(
        node: node,
        actionBuilder: widget.actionBuilder!,
        actionTrailingBuilder: widget.actionTrailingBuilder,
        child: child,
      );
    }
    return child;
  }
}

/// 对每个自然行增加字距；保持原字符串、富文本样式和 UTF-16 光标偏移。
/// 一个字和空行保留自然宽度；内嵌 WidgetSpan 仍交给原生排版，避免重建行内对象。
TextSpan distributeTextSpan(
  TextSpan source, {
  required double width,
  required TextDirection direction,
  TextScaler scaler = TextScaler.noScaling,
}) {
  final plain = source.toPlainText();
  var hasObject = false;
  source.visitChildren((span) {
    if (span is! TextSpan) hasObject = true;
    return true;
  });
  if (plain.isEmpty || !width.isFinite || width <= 0 || hasObject) {
    return source;
  }
  final natural = TextPainter(
    text: source,
    textDirection: direction,
    textScaler: scaler,
  )..layout(maxWidth: width);
  final result = <InlineSpan>[];
  var offset = 0;
  while (offset < plain.length) {
    final boundary = natural.getLineBoundary(TextPosition(offset: offset));
    var end = boundary.end;
    if (end <= offset) end = offset + 1;
    // 换行和行末空白不参与分散；原字符随后原样附回。
    var visibleEnd = end;
    while (visibleEnd > offset &&
        RegExp(r'\s').hasMatch(plain[visibleEnd - 1])) {
      visibleEnd--;
    }
    final line = _sliceSpan(source, offset, visibleEnd);
    final count = plain.substring(offset, visibleEnd).characters.length;
    if (count > 1) {
      final measure = TextPainter(textDirection: direction, textScaler: scaler);
      double lineWidth(double spacing) {
        measure.text = _spaceSpan(line, spacing);
        measure.layout();
        return measure.maxIntrinsicWidth;
      }

      var low = 0.0;
      var high = math.max(0.0, width / count);
      for (var i = 0; i < 12; i++) {
        final mid = (low + high) / 2;
        if (lineWidth(mid) <= width - 0.1) {
          low = mid;
        } else {
          high = mid;
        }
      }
      result.add(_spaceSpan(line, low));
      measure.dispose();
    } else {
      result.add(line);
    }
    if (visibleEnd < end) result.add(_sliceSpan(source, visibleEnd, end));
    offset = end;
    if (offset < plain.length && plain[offset] == '\n') {
      result.add(_sliceSpan(source, offset, offset + 1));
      offset++;
    }
  }
  natural.dispose();
  return TextSpan(style: source.style, children: result);
}

TextSpan _spaceSpan(TextSpan span, double extra, [double inherited = 0]) {
  final original = span.style?.letterSpacing ?? inherited;
  return TextSpan(
    text: span.text,
    style: (span.style ?? const TextStyle()).copyWith(
      letterSpacing: original + extra,
    ),
    recognizer: span.recognizer,
    mouseCursor: span.mouseCursor,
    onEnter: span.onEnter,
    onExit: span.onExit,
    locale: span.locale,
    spellOut: span.spellOut,
    semanticsLabel: span.semanticsLabel,
    children: span.children
        ?.map((child) => _spaceSpan(child as TextSpan, extra, original))
        .toList(),
  );
}

TextSpan _sliceSpan(TextSpan root, int start, int end) {
  var offset = 0;
  TextSpan slice(TextSpan span) {
    final text = span.text ?? '';
    final from = (start - offset).clamp(0, text.length);
    final to = (end - offset).clamp(0, text.length);
    offset += text.length;
    return TextSpan(
      text: text.substring(from, math.max(from, to)),
      style: span.style,
      recognizer: span.recognizer,
      mouseCursor: span.mouseCursor,
      onEnter: span.onEnter,
      onExit: span.onExit,
      locale: span.locale,
      spellOut: span.spellOut,
      children: span.children
          ?.map((child) => slice(child as TextSpan))
          .toList(),
    );
  }

  return slice(root);
}
