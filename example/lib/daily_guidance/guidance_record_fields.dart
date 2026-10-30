/// 从服务正文派生业务字段，不修改正文，也不持有编辑器或网络资源。
///
/// ```dart
/// final fields = GuidanceRecordFields.extract(bodyContent, orientType: 'ORIENT');
/// final request = {...record, 'bodyContent': bodyContent, ...fields};
/// ```
abstract final class GuidanceRecordFields {
  /// 同步读取已由正文 Codec 校验的 [body]，返回独立的业务字段，不修改来源。
  /// [orientType] 必须为 ORIENT 或 RESULT，分别派生 dailyOrientContent 或
  /// dailyResultContent，另一类型字段显式为 null；其他类型抛出 FormatException。
  /// help/pilot 保留在所属栏目，同时按文档顺序聚合；引用和空字段规则保持一致。
  static Map<String, dynamic> extract(
    Map<String, dynamic> body, {
    required String orientType,
  }) {
    if (!const ['ORIENT', 'RESULT'].contains(orientType)) {
      throw const FormatException('今日导向类型无效');
    }
    final record = _Content();
    final thinking = _Content();
    final selfCheck = _Content();
    final custom = <String, _Content>{};
    final help = <Map<String, dynamic>>[];
    final navigator = <Map<String, dynamic>>[];

    /// 按文档顺序遍历借用的 [node]；[destination] 是当前栏目收集器。
    void visit(Map node, _Content? destination) {
      final meta = node['meta'] as Map? ?? const {};
      if (meta['lock'] is String && (meta['lock'] as String).isNotEmpty) {
        return;
      }
      if (const ['daily-cover', 'daily-body'].contains(meta['dailySlot'])) {
        destination = record;
      }
      switch (meta['dailySection']) {
        case 'record':
          destination = record;
        case 'reflection':
          destination = thinking;
        case 'self-check':
          destination = selfCheck;
        case 'custom':
          final field = meta['dailyCustomField'] as Map;
          destination = custom.putIfAbsent(
            field['key'] as String,
            _Content.new,
          );
      }
      if (node['nodeType'] == 'editable') {
        final runs = node['children'] as List;
        final first = runs.isEmpty ? null : (runs.first as Map)['insert'];
        final tag = first is Map ? first['dailyTag'] : null;
        if (tag == 'help' || tag == 'pilot') {
          final content = _Content()..add(runs);
          final item = content.toJson();
          if ((item['content'] as String).trim().isNotEmpty) {
            final items = tag == 'help' ? help : navigator;
            items.add({...item, 'sortNo': items.length + 1});
          }
        }
        destination?.add(runs);
        return;
      }
      for (final child in node['children'] as List) {
        visit(child as Map, destination);
      }
    }

    visit(body, null);
    return {
      'dailyOrientContent': orientType == 'ORIENT' ? record.toJson() : null,
      'dailyResultContent': orientType == 'RESULT' ? record.toJson() : null,
      'thinking': thinking.toJson(),
      'selfCheck': selfCheck.toJson(),
      'helpItems': help,
      'navigatorItems': navigator,
      'customData': {
        for (final entry in custom.entries) entry.key: entry.value.toJson(),
      },
    };
  }
}

/// 单个业务字段的段落和引用收集器；由一次提取独占，不对外共享可变数据。
final class _Content {
  /// 按原顺序收集段落，输出时仅去掉末尾空白段落。
  final List<String> _lines = [];

  /// 以引用 ID 去重，保持首次出现的名称和顺序。
  final Map<String, String> _mentions = {};

  /// 同步读取借用的行内 [runs]，保留文本、换行及实体名称，忽略非文本对象。
  void add(List runs) {
    final text = StringBuffer();
    for (final raw in runs) {
      final run = raw as Map;
      final insert = run['insert'];
      if (insert is String) {
        text.write(insert);
      } else if (insert is Map && insert['mention'] is String) {
        final name = insert['mention'] as String;
        final attributes = run['attributes'] as Map? ?? const {};
        final id = attributes['mentionId'] ?? attributes['d:mentionId'];
        if (id is! String || id.trim().isEmpty) {
          throw const FormatException('引用缺少身份');
        }
        text.write('@$name');
        _mentions.putIfAbsent(id, () => name);
      }
    }
    _lines.add(text.toString());
  }

  /// 返回独立的字段对象，保留段内空格和中间空行；无内容时返回空串和空引用数组。
  Map<String, dynamic> toJson() {
    var end = _lines.length;
    while (end > 0 && _lines[end - 1].trim().isEmpty) {
      end--;
    }
    return {
      'content': _lines.take(end).join('\n'),
      'mentions': [
        for (final entry in _mentions.entries)
          {'mentionId': entry.key, 'mentionName': entry.value},
      ],
    };
  }
}
