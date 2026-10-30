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
  test('sample retains tagged content in sections and aggregates it', () {
    final record = _record();
    final before = jsonEncode(record);
    final fields = GuidanceRecordFields.extract(
      record['bodyContent'] as Map<String, dynamic>,
      orientType: record['orientType'] as String,
    );
    for (final key in [
      'selfCheck',
      'helpItems',
      'navigatorItems',
      'customData',
    ]) {
      expect(fields[key], record[key], reason: key);
    }
    expect(fields['thinking'], {
      'content':
          'XSNJKJCDSJJCKLJCDSKLDC,MN\nXBSGJHSDCDH \nXOIKCSCDSMK  \n@擎天柱 ewhbjkfdhfiohf bnm\nmdskljfo ',
      'mentions': [
        {'mentionId': '678', 'mentionName': '擎天柱'},
      ],
    });
    expect(fields['dailyResultContent'], {
      'content':
          'KJDCJODCJDCK \n@威震天 SJIDLJDCOIDNCS\nMDKLD\nKLDJDCF \n热风南方科技大V佛大V发大V发',
      'mentions': [
        {'mentionId': '5ffd465e263864787b87aa01', 'mentionName': '威震天'},
      ],
    });
    expect(fields, containsPair('dailyOrientContent', null));
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
      final fields = GuidanceRecordFields.extract(body, orientType: 'ORIENT');
      expect(fields['thinking'], {
        'content': '  开头\n@同事@同事@任务\n\n@手输 结尾  \n@同事 帮忙\n@任务 领航',
        'mentions': [
          {'mentionId': 'user-1', 'mentionName': '同事'},
          {'mentionId': 'task-1', 'mentionName': '任务'},
        ],
      });
      expect(fields['dailyOrientContent'], {
        'content': '@任务\n@同事',
        'mentions': [
          {'mentionId': 'task-1', 'mentionName': '任务'},
          {'mentionId': 'user-1', 'mentionName': '同事'},
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

  for (final type in ['ORIENT', 'RESULT']) {
    test(
      '$type saves matching record field and explicitly clears opposite type',
      () async {
        final record = _record()..['orientType'] = type;
        final target = type == 'ORIENT'
            ? 'dailyOrientContent'
            : 'dailyResultContent';
        final other = type == 'ORIENT'
            ? 'dailyResultContent'
            : 'dailyOrientContent';
        record[target] = {'content': '旧摘要', 'mentions': []};
        record[other] = {'content': '另一类型原值', 'mentions': []};
        final api = MockGuidanceApi(record: record, latency: Duration.zero);
        final store = ApiJournalStore(
          api: api,
          recordId: record['id'] as String,
        );
        final draft = await store.read();
        await store.write(draft);
        final saved = await api.fetch(record['id'] as String);
        expect(saved[target]['content'], contains('@威震天 SJIDLJDCOIDNCS'));
        expect(saved[target]['content'], contains('热风南方科技大V佛大V发大V发'));
        expect(saved[target]['content'], isNot(contains('今日成果')));
        expect(saved, containsPair(other, null));
        expect(saved['bodyContent'], record['bodyContent']);
        expect(saved['helpItems'], record['helpItems']);
        expect(
          saved['thinking']['content'],
          contains('@擎天柱 ewhbjkfdhfiohf bnm'),
        );
        final clearedBody =
            jsonDecode(jsonEncode(record['bodyContent']))
                as Map<String, dynamic>;
        for (final region in _regions(clearedBody)) {
          (region['children'] as List).removeWhere(
            (block) => (block['meta'] as Map)['lock'] == null,
          );
        }
        await store.write(BodyContentCodec.decode(clearedBody));
        final cleared = await api.fetch(record['id'] as String);
        expect(cleared[target], {'content': '', 'mentions': []});
        expect(cleared, containsPair(other, null));
      },
    );
  }

  test('tagged self-check and custom content stays in its original field', () {
    final tagged = _paragraph([
      {
        'insert': {'dailyTag': 'pilot'},
      },
      _mention('user-1', '同事', 'user'),
      {'insert': ' 领航'},
    ]);
    final body = <String, dynamic>{
      'nodeType': 'root',
      'children': [
        _region('self-check', [tagged]),
        _region('custom', [tagged], key: 'custom-key'),
      ],
    };
    final before = jsonEncode(body);
    final fields = GuidanceRecordFields.extract(body, orientType: 'RESULT');
    final expected = {
      'content': '@同事 领航',
      'mentions': [
        {'mentionId': 'user-1', 'mentionName': '同事'},
      ],
    };
    expect(fields['selfCheck'], expected);
    expect(fields['customData']['custom-key'], expected);
    expect(fields['navigatorItems'], [
      {...expected, 'sortNo': 1},
      {...expected, 'sortNo': 2},
    ]);
    expect(fields['dailyResultContent'], {'content': '', 'mentions': []});
    expect(jsonEncode(body), before);
  });

  test('unknown orientType is rejected without changing body', () {
    final body = <String, dynamic>{'nodeType': 'root', 'children': []};
    expect(
      () => GuidanceRecordFields.extract(body, orientType: 'UNKNOWN'),
      throwsFormatException,
    );
    expect(body['children'], isEmpty);
  });

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
      expect(saved.keys.toSet(), {
        ...record.keys,
        'dailyOrientContent',
        'dailyResultContent',
      });
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
      expect(saved['dailyResultContent'], {'content': '', 'mentions': []});
      expect(saved, containsPair('dailyOrientContent', null));
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
