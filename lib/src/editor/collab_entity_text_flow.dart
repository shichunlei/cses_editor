import 'package:applowy_editor_fork/applowy_editor_fork.dart';
import 'package:cses_editor/src/editor/collab_inline_entity_mention.dart';
import 'package:cses_editor/src/model/collab_inline_formula.dart';
import 'package:cses_editor/src/model/collab_user_mention.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 检查借用 [node] 是否含需展开为可换行文字的会议/任务原子。
/// [entityTypes] 默认包含两类；旧任务预览策略传入 task 单独筛选，不改变权限。
/// 无 Delta、名称属性缺失或非对象文字返回 false，不读取业务数据。
bool hasFlowingEntityMention(
  Node node, {
  Set<String> entityTypes = const {'meeting', 'task'},
}) =>
    node.delta?.whereType<TextInsert>().any(
      (run) =>
          entityTypes.contains(run.attributes?[collabMentionTypeAttribute]) &&
          run.attributes?[collabInlineMentionAttribute] is String &&
          run.text.contains(collabInlineFormulaCharacter),
    ) ??
    false;

/// 将会议/任务原子投影为无底色的蓝色图标与可换行标题，并将显示 UTF-16 偏移映射回单个正文字符。
/// 投影只参与渲染，不写回 Delta、身份或原属性；前后普通文字和其他内嵌对象保留原样。
/// 块 State 创建并释放本对象及其点击识别器；重新投影复用仍存在的识别器，移除的立即释放。
///
/// ```dart
/// import 'package:cses_editor/src/editor/collab_entity_text_flow.dart';
/// import 'package:flutter/material.dart';
/// final flow = CollabEntityTextFlow(onTap: (offset) => debugPrint('$offset'));
/// final displayed = flow.project(const TextSpan(text: '普通正文'));
/// final logicalOffset = flow.toDocument(0);
/// // When the block unmounts:
/// flow.dispose();
/// ```
final class CollabEntityTextFlow {
  /// [onTap] 借用块的同步派发入口，传入原子在正文中的 UTF-16 偏移；不拥有其导航资源。
  CollabEntityTextFlow({required this.onTap});

  /// 原子点击入口，由块复核当前节点并选择编辑菜单或只读详情，不修改标题文字。
  final ValueChanged<int> onTap;

  final _recognizers = <int, TapGestureRecognizer>{};
  var _ranges = <({int document, int start, int end})>[];

  /// Whether the current paragraph has any visually expanded references.
  bool get isExpanded => _ranges.isNotEmpty;

  /// 从借用 [source] 生成显示 Span，仅展开会议和任务占位符。
  /// 返回完整标题，空名称按类型显示“未命名会议/任务”；保留字号、字重与删除线。
  /// 重建显示偏移映射，复用现有识别器并释放已移除项；不修改源 Span 或正文。
  TextSpan project(TextSpan source) {
    final lengths = <int, int>{};

    /// Walks borrowed [span], preserving text and other embedded objects.
    InlineSpan expand(InlineSpan span) {
      if (span case WidgetSpan(
        child: final CollabInlineEntityMention mention,
      ) when const {'meeting', 'task'}.contains(mention.entityType)) {
        final style = collabEntityMentionTextStyle(mention.style);
        final offset = mention.offset;
        final recognizer = _recognizers.putIfAbsent(
          offset,
          () => TapGestureRecognizer()..onTap = () => onTap(offset),
        );
        final title = mention.name.isEmpty
            ? (mention.entityType == 'meeting' ? '未命名会议' : '未命名任务')
            : mention.name;
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
                  collabEntityMentionIcon(mention.entityType),
                  size: style.fontSize ?? 16,
                  color: style.color,
                ),
              ),
            ),
            _EntityTitleSpan(text: text, style: style, recognizer: recognizer),
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

  /// 返回显示 UTF-16 [offset] 命中的会议/任务原子的正文位置，普通文字返回 null。
  int? entityAt(int offset) {
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
        !object.text.visitChildren((span) => span is! _EntityTitleSpan)) {
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
final class _EntityTitleSpan extends TextSpan {
  /// [text] is the display-only title with borrowed [style] and [recognizer].
  const _EntityTitleSpan({
    required super.text,
    required super.style,
    required super.recognizer,
  });
}
