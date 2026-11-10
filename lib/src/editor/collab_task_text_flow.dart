import 'package:applowy_editor_fork/applowy_editor_fork.dart';
import 'package:cses_editor/src/editor/collab_inline_entity_mention.dart';
import 'package:cses_editor/src/model/collab_inline_formula.dart';
import 'package:cses_editor/src/model/collab_user_mention.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Checks whether borrowed [node] has a task atom that needs visual expansion.
bool hasFlowingTaskMention(Node node) =>
    node.delta?.whereType<TextInsert>().any(
      (run) =>
          run.attributes?[collabMentionTypeAttribute] == 'task' &&
          run.attributes?[collabInlineMentionAttribute] is String &&
          run.text.contains(collabInlineFormulaCharacter),
    ) ??
    false;

/// Projects task atoms into a wrapping title and maps the visual UTF-16
/// offsets back to their single document character. The block State owns and
/// disposes this projection and its tap recognizers.
///
/// ```dart
/// final flow = CollabTaskTextFlow(onTap: (offset) => debugPrint('$offset'));
/// final displayed = flow.project(originalTextSpan);
/// final logicalOffset = flow.toDocument(displayOffset);
/// // When the block unmounts:
/// flow.dispose();
/// ```
final class CollabTaskTextFlow {
  /// [onTap] is borrowed from the block and receives the document atom offset.
  CollabTaskTextFlow({required this.onTap});

  /// Opens actions for the referenced atom. The owner validates the live node.
  final ValueChanged<int> onTap;

  final _recognizers = <int, TapGestureRecognizer>{};
  var _ranges = <({int document, int start, int end})>[];

  /// Whether the current paragraph has any visually expanded references.
  bool get isExpanded => _ranges.isNotEmpty;

  /// Builds a display span from borrowed [source]. Only task placeholders are
  /// replaced. Retains each still-present recognizer and disposes removed ones.
  TextSpan project(TextSpan source) {
    final lengths = <int, int>{};

    /// Walks borrowed [span], preserving text and other embedded objects.
    InlineSpan expand(InlineSpan span) {
      if (span case WidgetSpan(
        child: final CollabInlineEntityMention mention,
      ) when mention.entityType == 'task') {
        final style = collabTaskMentionTextStyle(mention.style);
        final offset = mention.offset;
        final recognizer = _recognizers.putIfAbsent(
          offset,
          () => TapGestureRecognizer()..onTap = () => onTap(offset),
        );
        final title = mention.name.isEmpty ? '未命名任务' : mention.name;
        // The joiners keep the icon, thin space and start of the title together.
        final text = '\u2060\u2009\u2060$title';
        lengths[offset] = 1 + text.length;
        return TextSpan(
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: recognizer.onTap,
                child: Icon(
                  collabTaskMentionIcon,
                  size: style.fontSize ?? 16,
                  color: style.color,
                ),
              ),
            ),
            _TaskTitleSpan(text: text, style: style, recognizer: recognizer),
          ],
        );
      }
      if (span case TextSpan(children: final children?)) {
        final expanded = children.map(expand).toList(growable: false);
        for (var i = 0; i < children.length; i++) {
          if (!identical(children[i], expanded[i])) {
            return span.copyWith(children: expanded);
          }
        }
      }
      return span;
    }

    final projected = expand(source) as TextSpan;
    for (final offset in _recognizers.keys.toList()) {
      if (!lengths.containsKey(offset)) _recognizers.remove(offset)!.dispose();
    }
    var extra = 0;
    _ranges = [];
    for (final offset in lengths.keys.toList()..sort()) {
      final start = offset + extra;
      final length = lengths[offset]!;
      _ranges.add((document: offset, start: start, end: start + length));
      extra += length - 1;
    }
    return projected;
  }

  /// Returns the display offset for a borrowed document boundary [offset].
  int toDisplay(int offset) {
    var extra = 0;
    for (final range in _ranges) {
      if (offset <= range.document) break;
      extra += range.end - range.start - 1;
    }
    return offset + extra;
  }

  /// Finds the model atom at a display [offset], or null for ordinary text.
  int? taskAt(int offset) {
    for (final range in _ranges) {
      if (offset < range.start) break;
      if (offset < range.end) return range.document;
    }
    return null;
  }

  /// Maps display [offset] to a document boundary. Inside an atom [trailing]
  /// can choose its end or start, and null chooses the nearer logical edge.
  int toDocument(int offset, {bool? trailing}) {
    var extra = 0;
    for (final range in _ranges) {
      if (offset <= range.start) break;
      if (offset < range.end) {
        final atEnd = trailing ?? (offset - range.start >= range.end - offset);
        return range.document + (atEnd ? 1 : 0);
      }
      extra += range.end - range.start - 1;
    }
    return offset - extra;
  }

  /// Finds the actual display paragraph below borrowed [object], skipping
  /// placeholders and any RichText inside the inline widgets.
  RenderParagraph? paragraphIn(RenderObject? object) {
    if (object is RenderParagraph &&
        !object.text.visitChildren((span) => span is! _TaskTitleSpan)) {
      return object;
    }
    RenderParagraph? result;
    object?.visitChildren((child) => result ??= paragraphIn(child));
    return result;
  }

  /// Releases the tap recognizers owned by this projection.
  void dispose() {
    for (final recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    _recognizers.clear();
    _ranges = [];
  }
}

/// Marks an expanded title so caret geometry can locate the display paragraph.
final class _TaskTitleSpan extends TextSpan {
  /// [text] is the display-only title with borrowed [style] and [recognizer].
  const _TaskTitleSpan({
    required super.text,
    required super.style,
    required super.recognizer,
  });
}
