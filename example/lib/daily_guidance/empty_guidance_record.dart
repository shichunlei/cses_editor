import 'package:cses_offline_example/daily_guidance/body_content_codec.dart';
import 'package:cses_offline_example/daily_guidance/guidance_record_fields.dart';
import 'package:cses_offline_example/daily_guidance/journal_draft.dart';

/// 按时刻 [now] 对应的上海业务日创建空白完整 JSON，不读取素材或分配会话资源。
/// [orientType] 为 ORIENT（导向）或 RESULT（成果）；其他值抛 ArgumentError。
/// 正文包含 v9 日期区和主填写区；业务字段从空正文派生。
/// 返回值由调用者独占，同次启动可交给 mock 服务保存并重开。
///
/// ```dart
/// final record = createEmptyGuidanceRecord(DateTime.now(), orientType: 'RESULT');
/// final api = MockGuidanceApi(record: record);
/// ```
Map<String, dynamic> createEmptyGuidanceRecord(
  DateTime now, {
  required String orientType,
}) {
  if (!const ['ORIENT', 'RESULT'].contains(orientType)) {
    throw ArgumentError.value(orientType, 'orientType', '仅支持 ORIENT 或 RESULT');
  }
  final dailyType = orientType.toLowerCase();
  final title = orientType == 'RESULT' ? '成果' : '导向';
  final date = journalDate(now.toUtc().add(const Duration(hours: 8)));
  final id = 'guidance-$dailyType-${now.microsecondsSinceEpoch}';
  final body = <String, dynamic>{
    'id': '$id-body',
    'flavour': 'root',
    'nodeType': 'root',
    'props': {
      'fs': 16,
      'lh': 2,
      'color': '#39414C',
      'background': '#FAF7EF',
      'showHeader': false,
    },
    'meta': {
      'dailyDate': date,
      'dailyTemplate': 'daily-writing',
      'dailyTemplateVersion': 9,
      'dailyType': dailyType,
    },
    'children': [
      {
        'id': '$id-date-region',
        'flavour': 'render-unit',
        'nodeType': 'block',
        'props': {
          'p': [0, 32, 16],
          'backColor': '#FAF7EF',
        },
        'meta': {
          'lock': 'daily-template',
          'lockKind': 'template',
          'dailyRegion': 'daily-date',
        },
        'children': [
          {
            'id': '$id-date-card',
            'flavour': 'date-card',
            'nodeType': 'void',
            'props': {
              'style': 'masthead',
              'format': 'full',
              'width': 206,
              'height': 136,
              'bg': 'transparent',
              'fg': '#39414C',
              'bw': '0px solid',
              'date': '${date}T12:00:00',
            },
            'meta': {'dailyDate': true},
            'children': <Object>[],
          },
        ],
      },
      {
        'id': '$id-record',
        'flavour': 'render-unit',
        'nodeType': 'block',
        'props': {
          'p': [40, 40, 40],
          'backColor': '#FAF7EF',
          'background':
              'repeating-linear-gradient(to bottom, transparent 0px, transparent 39px, #E8E0CE 39px, #E8E0CE 40px)',
          ...BodyContentCodec.writingTextProps,
        },
        'meta': {
          'dailySection': 'primary',
          'dailySlot': 'daily-body',
          'tplFieldName': title,
          'tplRegion': true,
          'incl': BodyContentCodec.writingFlavours,
        },
        'children': [
          {
            'id': '$id-paragraph',
            'flavour': 'paragraph',
            'nodeType': 'editable',
            'props': {'depth': 0, 'psa': 0, 'psb': 0},
            'meta': {'plh': '请输入', 'plhMode': 'always'},
            'children': <Object>[],
          },
        ],
      },
    ],
  };
  return {
    'id': id,
    'bizType': 'DAILY_ORIENT',
    'orientType': orientType,
    'todoContent': {'content': '', 'mentions': <Object>[]},
    'expectedEffectContent': {'content': '', 'mentions': <Object>[]},
    'bodyContent': body,
    ...GuidanceRecordFields.extract(body, orientType: orientType),
  };
}
