import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cses_editor/cses_editor.dart';
import 'package:cses_offline_example/daily_guidance/guidance_entries.dart';
import 'package:cses_offline_example/daily_guidance/journal_blockcraft_codec.dart';
import 'package:cses_offline_example/daily_guidance/journal_draft.dart';

/// 本地会话保留的原始模板，绝不作为独立接口字段提交。
const journalBodyTemplateAttribute = 'guidance_body_template';

/// 正文节点的来源区域；块转换保留它，新段落按相邻节点确定归属。
const journalBodyRegionAttribute = 'guidance_body_region';

/// bodyContent 与既有横格日记模型之间的业务适配，不启用桌面通用渲染模式。
///
/// ```dart
/// final draft = BodyContentCodec.decode(bodyContent);
/// final restored = BodyContentCodec.encode(draft);
/// ```
abstract final class BodyContentCodec {
  /// 从借用的 [body] 创建独立草稿；[now] 仅用于建档时间，不替代接口记录日期。
  /// 原区域/锁/扩展属性保存在会话中，未支持的可编辑块或非法数据整次拒绝。
  static JournalDraft decode(Map<String, dynamic> body, {DateTime? now}) {
    final source = _copy(body);
    final normalized = _copy(body);
    _normalizeTags(normalized);
    BlockCraftJsonCodec.validate(normalized);
    if ((source['meta'] as Map)['dailyTemplate'] != 'daily-writing') {
      throw const FormatException('不支持的今日导向模板');
    }
    final date = (source['meta'] as Map)['dailyDate'];
    if (date is! String || !isJournalDate(date)) {
      throw const FormatException('模板日期无效');
    }
    final sections = <String, Node>{};
    final baseline = <String, String>{};
    final regions = <String, String>{};
    for (final raw in source['children'] as List) {
      final region = Map<String, dynamic>.from(raw as Map);
      final key = _sectionKey(region);
      if (key == null) continue;
      final meta = region['meta'] as Map;
      if (_locked(region)) throw const FormatException('填写区处于锁定状态');
      final section = sections.putIfAbsent(
        key,
        () => Node(
          type: journalSectionType,
          attributes: {'section': key, if (key.startsWith('custom:')) 'guidance_section_label': meta['tplFieldName']},
        ),
      );
      final regionId = region['id'] as String;
      regions[regionId] = key;
      for (final rawBlock in region['children'] as List) {
        final block = Map<String, dynamic>.from(rawBlock as Map);
        if (_locked(block)) {
          if (meta['dailySlot'] == 'daily-cover' && (block['meta'] as Map)['lockKind'] == 'template') {
            continue;
          }
          throw const FormatException('填写区含不支持的锁定正文');
        }
        if (block['nodeType'] != 'editable') {
          throw const FormatException('填写区包含当前日记未支持的内容');
        }
        final sanitized = _copy(block);
        final tag = _normalizeTags(sanitized);
        final node = BlockCraftJsonCodec.decodeBlock(sanitized);
        node.updateAttributes({
          journalBodyRegionAttribute: regionId,
          if (tag != null) ...{guidanceEntryAttribute: tag, 'guidance_entry_id': block['id'], 'guidance_done': false},
        });
        if (!isJournalTextNode(node)) throw const FormatException('正文含不支持的格式');
        section.insert(node);
        baseline[block['id'] as String] = _fingerprint(_encodeNode(node));
      }
    }
    final record = sections.remove('record');
    if (record == null) throw const FormatException('缺少正文填写区');
    final ordered = [record, ...sections.values];
    for (final section in ordered) {
      if (section.children.isEmpty) {
        section.insert(paragraphNode(attributes: {'guidance_body_placeholder': true}));
      }
    }
    final view = (source['meta'] as Map)['mobileGuidanceView'];
    if (view != null && view is! Map) throw const FormatException('栏目视图状态无效');
    final hiddenKeys = view is Map ? view['hiddenSections'] : null;
    if (hiddenKeys != null &&
        (hiddenKeys is! List || hiddenKeys.any((key) => !const ['reflection', 'self-check'].contains(key)))) {
      throw const FormatException('隐藏栏目状态无效');
    }
    final hidden = ordered
        .where((section) => (hiddenKeys as List? ?? []).contains(section.attributes['section']))
        .toList();
    final root = Node(
      type: 'page',
      attributes: {
        journalBodyTemplateAttribute: jsonEncode({'source': source, 'baseline': baseline, 'regions': regions}),
        if (hidden.isNotEmpty) journalClosedSectionsAttribute: hidden.map((node) => node.toJson()).toList(),
      },
      children: ordered.where((node) => !hidden.contains(node)).toList(),
    );
    final document = Document(root: root);
    try {
      validateJournalDocument(document);
      final time = now ?? DateTime.now();
      return JournalDraft(
        id: 'body-${time.microsecondsSinceEpoch}',
        date: date,
        createdAt: time.toUtc(),
        updatedAt: time.toUtc(),
        timezoneOffsetMinutes: time.timeZoneOffset.inMinutes,
        documentJson: jsonEncode(document.toJson()),
        blockCraftIdsJson: JournalBlockCraftCodec.captureIdentities(document),
      );
    } finally {
      document.dispose();
    }
  }

  /// 将借用的实时 [draft] 还原为独立 bodyContent；原模板、标题、属性及引用保持，
  /// 仅更新编辑过的正文/日期；隐藏栏目保留内容并使用根 meta 的可选视图扩展恢复。
  static Map<String, dynamic> encode(JournalDraft draft) {
    final document = Document.fromJson(jsonDecode(draft.documentJson) as Map<String, dynamic>);
    try {
      JournalBlockCraftCodec.restoreIdentities(document, draft.blockCraftIdsJson);
      validateJournalDocument(document);
      final raw = document.root.attributes[journalBodyTemplateAttribute];
      if (raw is! String) throw const FormatException('缺少正文来源模板');
      final state = jsonDecode(raw) as Map;
      final source = _copy(Map<String, dynamic>.from(state['source'] as Map));
      final baseline = state['baseline'] as Map;
      final regionKeys = Map<String, String>.from(state['regions'] as Map);
      final originals = <String, Map<String, dynamic>>{};
      final grouped = <String, List<Map<String, dynamic>>>{};
      final regions = (source['children'] as List).cast<Map>();
      for (final region in regions) {
        if (!regionKeys.containsKey(region['id'])) continue;
        for (final raw in region['children'] as List) {
          final block = Map<String, dynamic>.from(raw as Map);
          originals[block['id'] as String] = block;
        }
      }
      final hidden = closedJournalSections(document);
      final ids = <String>{};
      for (final section in [...document.root.children, ...hidden]) {
        final key = section.attributes['section'] as String;
        var choices = regionKeys.entries.where((entry) => entry.value == key).map((entry) => entry.key).toList();
        if (choices.isEmpty) {
          final regionId = 'region-${section.id}';
          final region = <String, dynamic>{
            'id': regionId,
            'flavour': 'render-unit',
            'nodeType': 'block',
            'props': <String, dynamic>{},
            'meta': {'dailySection': key, 'tplRegion': true, 'tplFieldName': key == 'reflection' ? '感悟' : '自检'},
            'children': <Object>[],
          };
          (source['children'] as List).add(region);
          regionKeys[regionId] = key;
          choices = [regionId];
        }
        var destination = choices.first;
        for (final node in section.children) {
          if (node.attributes['guidance_body_placeholder'] == true && node.delta!.isEmpty) {
            continue;
          }
          final preferred = node.attributes[journalBodyRegionAttribute];
          if (choices.contains(preferred)) destination = preferred as String;
          var block = _encodeNode(node);
          final identity = block['id'] as String;
          if (!ids.add(identity)) {
            block['id'] = 'block-${node.id}';
            if (!ids.add(block['id'] as String)) {
              throw const FormatException('正文块身份冲突');
            }
          }
          if (baseline[identity] == _fingerprint(block) && originals[identity] != null) {
            block = _copy(originals[identity]!);
          }
          grouped.putIfAbsent(destination, () => []).add(block);
        }
      }
      for (final region in (source['children'] as List).cast<Map>()) {
        final id = region['id'];
        if (!regionKeys.containsKey(id)) continue;
        region['children'] = [
          for (final block in region['children'] as List)
            if (_locked(block as Map)) block,
          ...?grouped[id],
        ];
      }
      final metadata = source['meta'] as Map;
      if (metadata['dailyDate'] != draft.date) {
        metadata['dailyDate'] = draft.date;
        _updateDates(source, draft.date);
      }
      final hiddenKeys = hidden.map((section) => section.attributes['section']).toList();
      final rawView = metadata['mobileGuidanceView'];
      final view = rawView is Map ? Map<String, dynamic>.from(rawView) : <String, dynamic>{};
      if (hiddenKeys.isNotEmpty) {
        view['hiddenSections'] = hiddenKeys;
      } else {
        view.remove('hiddenSections');
      }
      if (view.isEmpty) {
        metadata.remove('mobileGuidanceView');
      } else {
        metadata['mobileGuidanceView'] = view;
      }
      final normalized = _copy(source);
      _normalizeTags(normalized);
      BlockCraftJsonCodec.validate(normalized);
      return source;
    } finally {
      document.dispose();
    }
  }

  /// 从借用的 [region] 元数据识别原有日记栏目，自定义字段保持稳定 key。
  static String? _sectionKey(Map region) {
    if (region['flavour'] != 'render-unit') {
      throw const FormatException('不支持的模板区域');
    }
    final meta = region['meta'] as Map;
    if (meta['dailySlot'] == 'daily-cover' || meta['dailySlot'] == 'daily-body') {
      return 'record';
    }
    final key = meta['dailySection'];
    if (key == 'reflection' || key == 'self-check') return key as String;
    if (key == 'custom') {
      final field = meta['dailyCustomField'];
      if (field is! Map ||
          field['key'] is! String ||
          (field['key'] as String).isEmpty ||
          (field['key'] as String).length > 200 ||
          meta['tplFieldName'] is! String) {
        throw const FormatException('自定义栏目无效');
      }
      return 'custom:${field['key']}';
    }
    if ((region['children'] as List).every((child) => (child as Map)['flavour'] == 'date-card')) {
      return null;
    }
    throw const FormatException('未知模板区域');
  }

  /// 检查借用的 [block] 是否为不可编辑的模板节点。
  static bool _locked(Map block) =>
      (block['meta'] as Map)['lock'] is String && ((block['meta'] as Map)['lock'] as String).isNotEmpty;

  /// 从独立 [block] 移出前缀业务标签，保持核心 Codec 的已注册协议不变。
  /// 标签只允许 help/pilot 且位于正文起始；其他位置或值整次拒绝。
  static String? _normalizeTags(Map block) {
    String? tag;
    if (block['nodeType'] == 'editable') {
      final runs = block['children'] as List;
      final filtered = <Object>[];
      for (var index = 0; index < runs.length; index++) {
        final run = runs[index] as Map;
        final insert = run['insert'];
        if (insert is Map && insert.containsKey('dailyTag')) {
          if (index != 0 ||
              insert.length != 1 ||
              !const ['help', 'pilot'].contains(insert['dailyTag']) ||
              run.length != 1) {
            throw const FormatException('业务标签无效');
          }
          tag = insert['dailyTag'] as String;
        } else {
          filtered.add(run);
        }
      }
      block['children'] = filtered;
    } else {
      for (final child in block['children'] as List) {
        _normalizeTags(child as Map);
      }
    }
    return tag;
  }

  /// 编码借用的本地文字 [node]，过滤移动端内部属性并还原业务前缀。
  static Map<String, dynamic> _encodeNode(Node node) {
    final attributes = {...node.attributes};
    final delta = Delta();
    for (final run in node.delta!.whereType<TextInsert>()) {
      final attrs = {...?run.attributes};
      if (attrs[guidanceMentionAttribute] != null) {
        final person = readGuidanceMention(attrs);
        attrs.remove(guidanceMentionAttribute);
        attrs.addAll({
          'cses_inline_mention': person.name,
          'cses_mention_id': person.id,
          'cses_mention_type': person.type,
        });
      }
      delta.insert(run.text, attributes: attrs.isEmpty ? null : attrs);
    }
    attributes.removeWhere((key, _) => key.startsWith('guidance_'));
    attributes['delta'] = delta.toJson();
    // 列表转段落等转换后，实际本地类型决定输出 flavour，来源样式属性仍保留。
    attributes.remove('bc.flavour');
    final copy = node.copyWith(attributes: attributes, children: []);
    final block = BlockCraftJsonCodec.encodeBlock(copy);
    final kind = node.attributes[guidanceEntryAttribute];
    if (kind == 'help' || kind == 'pilot') {
      (block['children'] as List).insert(0, {
        'insert': {'dailyTag': kind},
      });
    }
    return block;
  }

  /// 深拷贝 JSON [value]，确保来源与编辑模型没有可变共享。
  static Map<String, dynamic> _copy(Map<String, dynamic> value) =>
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

  /// 对借用 JSON [value] 生成顺序无关指纹，仅用于判定节点是否编辑。
  static String _fingerprint(Object? value) => jsonEncode(_sorted(value));

  /// 递归排序借用 JSON [value] 的键，不修改值和数组顺序。
  static Object? _sorted(Object? value) {
    if (value is Map) {
      return {for (final key in value.keys.map((key) => '$key').toList()..sort()) key: _sorted(value[key])};
    }
    if (value is List) return value.map(_sorted).toList();
    return value;
  }

  /// 更新独立 [block] 中标记的日期卡片为 [date]，保留原时分秒和样式。
  static void _updateDates(Map block, String date) {
    if (block['flavour'] == 'date-card' && (block['meta'] as Map)['dailyDate'] == true) {
      final props = block['props'] as Map;
      final old = props['date'];
      props['date'] = old is String && old.length >= 10 ? '$date${old.substring(10)}' : '${date}T12:00:00';
    }
    if (block['nodeType'] != 'editable') {
      for (final child in block['children'] as List) {
        _updateDates(child as Map, date);
      }
    }
  }
}
