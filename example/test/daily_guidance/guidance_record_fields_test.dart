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
        {'mentionId': '678', 'mentionName': '擎天柱', 'mentionType': 'user'},
      ],
    });
    expect(fields['dailyResult'], {
      'content':
          'KJDCJODCJDCK \n@威震天 SJIDLJDCOIDNCS\nMDKLD\nKLDJDCF \n热风南方科技大V佛大V发大V发',
      'mentions': [
        {
          'mentionId': '5ffd465e263864787b87aa01',
          'mentionName': '威震天',
          'mentionType': 'user',
        },
      ],
    });
    expect(fields, containsPair('dailyOrient', null));
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
          {'mentionId': 'user-1', 'mentionName': '同事', 'mentionType': 'user'},
          {'mentionId': 'task-1', 'mentionName': '任务', 'mentionType': 'task'},
        ],
      });
      expect(fields['dailyOrient'], {
        'content': '@任务\n@同事',
        'mentions': [
          {'mentionId': 'task-1', 'mentionName': '任务', 'mentionType': 'task'},
          {'mentionId': 'user-1', 'mentionName': '同事', 'mentionType': 'user'},
        ],
      });
      expect(fields['selfCheck']['mentions'], [
        {'mentionId': 'user-1', 'mentionName': '同事', 'mentionType': 'user'},
      ]);
      expect(fields['helpItems'], [
        {
          'content': '@同事 帮忙',
          'mentions': [
            {'mentionId': 'user-1', 'mentionName': '同事', 'mentionType': 'user'},
          ],
          'sortNo': 1,
        },
        {
          'content': '@任务',
          'mentions': [
            {'mentionId': 'task-1', 'mentionName': '任务', 'mentionType': 'task'},
          ],
          'sortNo': 2,
        },
      ]);
      expect(fields['navigatorItems'], [
        {
          'content': '@任务 领航',
          'mentions': [
            {'mentionId': 'task-1', 'mentionName': '任务', 'mentionType': 'task'},
          ],
          'sortNo': 1,
        },
        {
          'content': '@同事',
          'mentions': [
            {'mentionId': 'user-1', 'mentionName': '同事', 'mentionType': 'user'},
          ],
          'sortNo': 2,
        },
      ]);
      expect(fields['customData']['stable-key'], {
        'content': '@任务@同事',
        'mentions': [
          {'mentionId': 'task-1', 'mentionName': '任务', 'mentionType': 'task'},
          {'mentionId': 'user-1', 'mentionName': '同事', 'mentionType': 'user'},
        ],
      });
    },
  );

  for (final type in ['ORIENT', 'RESULT']) {
    test(
      '$type saves matching record field and explicitly clears opposite type',
      () async {
        final record = _record()..['orientType'] = type;
        final target = type == 'ORIENT' ? 'dailyOrient' : 'dailyResult';
        final other = type == 'ORIENT' ? 'dailyResult' : 'dailyOrient';
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
        {'mentionId': 'user-1', 'mentionName': '同事', 'mentionType': 'user'},
      ],
    };
    expect(fields['selfCheck'], expected);
    expect(fields['customData']['custom-key'], expected);
    expect(fields['navigatorItems'], [
      {...expected, 'sortNo': 1},
      {...expected, 'sortNo': 2},
    ]);
    expect(fields['dailyResult'], {'content': '', 'mentions': []});
    expect(jsonEncode(body), before);
  });

  test(
    'all fields retain four mention types and deduplicate by type and ID',
    () {
      const types = ['user', 'task', 'meeting', 'doc'];
      final runs = <Object>[
        for (final type in types) ...[
          _mention('shared-id', type, type),
          _mention('shared-id', '后来的名称', type),
        ],
      ];
      final body = <String, dynamic>{
        'nodeType': 'root',
        'children': [
          for (final section in [
            'record',
            'reflection',
            'self-check',
            'custom',
          ])
            _region(section, [
              _paragraph([
                {
                  'insert': {
                    'dailyTag': section == 'reflection' ? 'pilot' : 'help',
                  },
                },
                ...runs,
              ]),
            ], key: section == 'custom' ? 'typed-key' : null),
        ],
      };
      final before = jsonEncode(body);
      final expected = [
        for (final type in types)
          {'mentionId': 'shared-id', 'mentionName': type, 'mentionType': type},
      ];
      for (final orient in ['ORIENT', 'RESULT']) {
        final fields = GuidanceRecordFields.extract(body, orientType: orient);
        final main = orient == 'ORIENT' ? 'dailyOrient' : 'dailyResult';
        for (final key in [main, 'thinking', 'selfCheck']) {
          expect(fields[key]['mentions'], expected, reason: key);
        }
        expect(fields['customData']['typed-key']['mentions'], expected);
        expect(fields['helpItems'], hasLength(3));
        expect(fields['navigatorItems'], hasLength(1));
        for (final item in [
          ...fields['helpItems'],
          ...fields['navigatorItems'],
        ]) {
          expect(item['mentions'], expected);
        }
        expect(fields[main]['content'], contains('@后来的名称'));
      }
      expect(jsonEncode(body), before);
    },
  );

  test(
    'missing mentionType defaults to user and namespaced attributes are read',
    () {
      final body = <String, dynamic>{
        'nodeType': 'root',
        'children': [
          _region('self-check', [
            _paragraph([
              {
                'insert': {'mention': '旧用户'},
                'attributes': {'mentionId': 'shared-id'},
              },
              _mention('shared-id', '新用户名称', 'user'),
              _mention('shared-id', '同ID任务', 'task'),
              {
                'insert': {'mention': '旧会议'},
                'attributes': {
                  'd:mentionId': 'meeting-id',
                  'd:mentionType': 'meeting',
                },
              },
            ]),
          ]),
        ],
      };
      final before = jsonEncode(body);
      final fields = GuidanceRecordFields.extract(body, orientType: 'ORIENT');
      expect(fields['selfCheck']['mentions'], [
        {'mentionId': 'shared-id', 'mentionName': '旧用户', 'mentionType': 'user'},
        {
          'mentionId': 'shared-id',
          'mentionName': '同ID任务',
          'mentionType': 'task',
        },
        {
          'mentionId': 'meeting-id',
          'mentionName': '旧会议',
          'mentionType': 'meeting',
        },
      ]);
      expect(jsonEncode(body), before);
    },
  );

  test(
    'saving legacy body without types submits explicit user mentions',
    () async {
      final record = _record();

      /// 仅修改本测试拥有的 [value]，模拟旧正文未携带引用类型。
      void removeTypes(Object? value) {
        if (value is Map) {
          value.remove('mentionType');
          value.remove('d:mentionType');
          for (final child in value.values) {
            removeTypes(child);
          }
        } else if (value is List) {
          for (final child in value) {
            removeTypes(child);
          }
        }
      }

      removeTypes(record['bodyContent']);
      final api = MockGuidanceApi(record: record, latency: Duration.zero);
      final store = ApiJournalStore(api: api, recordId: record['id'] as String);
      final draft = await store.read();
      await store.write(draft);
      final saved = await api.fetch(record['id'] as String);
      expect(saved['selfCheck']['mentions'], [
        {
          'mentionId': '6ae2bd06bc2701ed9ddf443c',
          'mentionName': 'CDCKD;OSDCKP[CK',
          'mentionType': 'user',
        },
        {
          'mentionId': '5ffd465e263864787b87aa01',
          'mentionName': '威震天',
          'mentionType': 'user',
        },
      ]);
      expect(saved['bodyContent'], record['bodyContent']);
    },
  );

  for (final invalid in ['', 'department', 42]) {
    test('unsupported mention type $invalid is rejected', () {
      final body = <String, dynamic>{
        'nodeType': 'root',
        'children': [
          _region('record', [
            _paragraph([
              {
                'insert': {'mention': '引用'},
                'attributes': {'mentionId': 'id-1', 'mentionType': invalid},
              },
            ]),
          ]),
        ],
      };
      expect(
        () => GuidanceRecordFields.extract(body, orientType: 'ORIENT'),
        throwsFormatException,
      );
    });
  }

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
      expect(saved.keys.toSet(), record.keys.toSet());
      for (final key in [
        'id',
        'bizType',
        'orientType',
        'todoContent',
        'expectedEffectContent',
        'extension',
      ]) {
        expect(saved[key], record[key]);
      }
      expect(saved['dailyResult'], {'content': '', 'mentions': []});
      expect(saved, containsPair('dailyOrient', null));
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

  test('saved record follows final sample field and mention schema', () async {
    final sample = _record();
    final api = MockGuidanceApi(record: sample, latency: Duration.zero);
    final store = ApiJournalStore(api: api, recordId: sample['id'] as String);
    final draft = await store.read();
    await store.write(draft);
    final submitted = await api.fetch(sample['id'] as String);
    expect(submitted.keys.toSet(), sample.keys.toSet());
    expect(submitted['dailyOrient'], isNull);
    final contents = <Map>[
      for (final key in [
        'todoContent',
        'dailyResult',
        'expectedEffectContent',
        'thinking',
        'selfCheck',
      ])
        submitted[key] as Map,
      ...(submitted['helpItems'] as List).cast<Map>(),
      ...(submitted['navigatorItems'] as List).cast<Map>(),
      ...(submitted['customData'] as Map).values.cast<Map>(),
    ];
    for (final content in contents) {
      expect(content['content'], isA<String>());
      expect(content['mentions'], isA<List>());
      for (final mention in content['mentions'] as List) {
        expect((mention as Map).keys.toSet(), {
          'mentionId',
          'mentionName',
          'mentionType',
        });
        expect(mention['mentionId'], isA<String>());
        expect(mention['mentionName'], isA<String>());
        expect([
          'user',
          'task',
          'meeting',
          'doc',
        ], contains(mention['mentionType']));
      }
    }
    for (final key in ['helpItems', 'navigatorItems']) {
      final items = submitted[key] as List;
      for (var index = 0; index < items.length; index++) {
        expect((items[index] as Map).keys.toSet(), {
          'content',
          'mentions',
          'sortNo',
        });
        expect(items[index]['sortNo'], index + 1);
      }
    }
    expect(submitted['bodyContent'], sample['bodyContent']);
  });

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
