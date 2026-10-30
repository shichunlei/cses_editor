import 'dart:convert';
import 'dart:io';

import 'package:cses_offline_example/daily_guidance/body_content_codec.dart';
import 'package:cses_offline_example/daily_guidance/guidance_api.dart';
import 'package:cses_offline_example/daily_guidance/guidance_record_fields.dart';
import 'package:flutter_test/flutter_test.dart';

/// 返回独立样例记录，不修改磁盘文件。
Map<String, dynamic> _record() =>
    jsonDecode(File('文档完整数据结构.json').readAsStringSync())
        as Map<String, dynamic>;

/// 从借用 [runs] 创建供提取器读取的独立段落。
Map<String, dynamic> _paragraph(List<Object> runs) => {
  'nodeType': 'editable',
  'meta': <String, dynamic>{},
  'children': runs,
};

/// 创建身份为 [id]、名称为 [name]、类型为 [type] 的独立引用片段。
Map<String, dynamic> _mention(String id, String name, String type) => {
  'insert': {'mention': name},
  'attributes': {'mentionId': id, 'mentionType': type},
};

/// 创建目标为 [section]、内容为 [blocks] 的独立区域；[key] 为自定义字段身份。
Map<String, dynamic> _region(
  String section,
  List<Object> blocks, {
  String? key,
}) => {
  'nodeType': 'block',
  'meta': {
    'dailySection': section,
    if (key != null) 'dailyCustomField': {'key': key},
  },
  'children': blocks,
};

/// 返回正文可编辑的 [body] 区域，用于模拟全部清空。
Iterable<Map> _regions(Map body) => (body['children'] as List)
    .cast<Map>()
    .where((region) => (region['meta'] as Map)['tplRegion'] == true);

/// 覆盖样例投影、引用归属、全量清空及完整记录的隔离提交。
void main() {
  test('sample derives all five fields exactly, including task mentions', () {
    final record = _record();
    final before = jsonEncode(record);
    final fields = GuidanceRecordFields.extract(
      record['bodyContent'] as Map<String, dynamic>,
    );
    for (final entry in fields.entries) {
      expect(entry.value, record[entry.key], reason: entry.key);
    }
    expect(jsonEncode(record), before);
  });

  test(
    'routes tagged paragraphs, preserves whitespace and scopes mentions',
    () {
      final person = _mention('user-1', '同事', 'user');
      final task = _mention('task-1', '任务', 'task');
      final body = <String, dynamic>{
        'nodeType': 'root',
        'children': [
          _region('reflection', [
            _paragraph([
              {'insert': '  开头\n'},
              person,
              person,
              task,
            ]),
            _paragraph([]),
            _paragraph([
              {'insert': '@手输 结尾  '},
            ]),
            _paragraph([
              {
                'insert': {'dailyTag': 'help'},
              },
              person,
              {'insert': ' 帮忙'},
            ]),
            _paragraph([
              {
                'insert': {'dailyTag': 'pilot'},
              },
              task,
              {'insert': ' 领航'},
            ]),
            _paragraph([
              {'insert': '   '},
            ]),
          ]),
          _region('self-check', [
            _paragraph([person]),
          ]),
          _region('custom', [
            _paragraph([task, person]),
          ], key: 'stable-key'),
          _region('record', [
            _paragraph([
              {
                'insert': {'dailyTag': 'help'},
              },
              task,
            ]),
            _paragraph([
              {
                'insert': {'dailyTag': 'pilot'},
              },
              person,
            ]),
            _paragraph([
              {
                'insert': {'dailyTag': 'help'},
              },
            ]),
          ]),
        ],
      };
      final fields = GuidanceRecordFields.extract(body);
      expect(fields['thinking'], {
        'content': '  开头\n@同事@同事@任务\n\n@手输 结尾  ',
        'mentions': [
          {'mentionId': 'user-1', 'mentionName': '同事'},
          {'mentionId': 'task-1', 'mentionName': '任务'},
        ],
      });
      expect(fields['selfCheck']['mentions'], [
        {'mentionId': 'user-1', 'mentionName': '同事'},
      ]);
      expect(fields['helpItems'], [
        {
          'content': '@同事 帮忙',
          'mentions': [
            {'mentionId': 'user-1', 'mentionName': '同事'},
          ],
          'sortNo': 1,
        },
        {
          'content': '@任务',
          'mentions': [
            {'mentionId': 'task-1', 'mentionName': '任务'},
          ],
          'sortNo': 2,
        },
      ]);
      expect(fields['navigatorItems'], [
        {
          'content': '@任务 领航',
          'mentions': [
            {'mentionId': 'task-1', 'mentionName': '任务'},
          ],
          'sortNo': 1,
        },
        {
          'content': '@同事',
          'mentions': [
            {'mentionId': 'user-1', 'mentionName': '同事'},
          ],
          'sortNo': 2,
        },
      ]);
      expect(fields['customData']['stable-key'], {
        'content': '@任务@同事',
        'mentions': [
          {'mentionId': 'task-1', 'mentionName': '任务'},
          {'mentionId': 'user-1', 'mentionName': '同事'},
        ],
      });
    },
  );

  test(
    'full save preserves other fields and clears removed content and mentions',
    () async {
      final record = _record()
        ..['extension'] = {
          'nested': [1, 2],
        };
      final api = MockGuidanceApi(record: record, latency: Duration.zero);
      final store = ApiJournalStore(api: api, recordId: record['id'] as String);
      await store.read();
      final body = record['bodyContent'] as Map<String, dynamic>;
      for (final region in _regions(body)) {
        (region['children'] as List).removeWhere(
          (block) => (block['meta'] as Map)['lock'] == null,
        );
      }
      await store.write(BodyContentCodec.decode(body));
      final saved = await api.fetch(record['id'] as String);
      expect(saved.keys.toSet(), record.keys.toSet());
      for (final key in [
        'id',
        'bizType',
        'orientType',
        'todoContent',
        'dailyOrient',
        'expectedEffectContent',
        'dailyResult',
        'extension',
      ]) {
        expect(saved[key], record[key]);
      }
      expect(saved['thinking'], {'content': '', 'mentions': []});
      expect(saved['selfCheck'], {'content': '', 'mentions': []});
      expect(saved['helpItems'], isEmpty);
      expect(saved['navigatorItems'], isEmpty);
      expect(saved['customData'], {
        'local_KYlqAwkdYUsE_BTzfk': {'content': '', 'mentions': []},
      });
      saved['extension']['nested'].add(3);
      expect((await api.fetch(record['id'] as String))['extension'], {
        'nested': [1, 2],
      });
    },
  );

  test(
    'mock rejects partial and mismatched submissions without replacing record',
    () async {
      final record = _record();
      final id = record['id'] as String;
      final api = MockGuidanceApi(record: record, latency: Duration.zero);
      await expectLater(
        api.save(id, {'bodyContent': record['bodyContent']}),
        throwsStateError,
      );
      final partial = {...record}..remove('selfCheck');
      await expectLater(api.save(id, partial), throwsFormatException);
      await expectLater(
        api.save(id, {...record, 'id': 'other'}),
        throwsStateError,
      );
      expect(await api.fetch(id), record);
      final store = ApiJournalStore(api: api, recordId: id);
      await expectLater(
        store.write(
          BodyContentCodec.decode(
            record['bodyContent'] as Map<String, dynamic>,
          ),
        ),
        throwsStateError,
      );
    },
  );
}
