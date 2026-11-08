import 'package:cses_offline_example/daily_guidance/guidance_record_fields.dart';
import 'package:cses_offline_example/daily_guidance/journal_draft.dart';

/// 按宿主本地 [now] 创建当天的空白完整 JSON，不读取素材或分配会话资源。
/// [orientType] 为 ORIENT（导向）或 RESULT（成果）；其他值抛 ArgumentError。
/// 复用既有 daily-writing 正文协议，仅保留正文填写区；业务字段从空正文派生。
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
  final title = orientType == 'RESULT' ? '工作成果' : '成果导向';
  final id = 'guidance-$dailyType-${now.microsecondsSinceEpoch}';
  final body = <String, dynamic>{
    'id': '$id-body',
    'flavour': 'root',
    'nodeType': 'root',
    'props': <String, dynamic>{},
    'meta': {
      'dailyDate': journalDate(now),
      'dailyTemplate': 'daily-writing',
      'dailyTemplateVersion': 5,
      'dailyType': dailyType,
    },
    'children': [
      {
        'id': '$id-record',
        'flavour': 'render-unit',
        'nodeType': 'block',
        'props': <String, dynamic>{},
        'meta': {
          'dailySlot': 'daily-body',
          'tplFieldName': title,
          'tplRegion': true,
        },
        'children': <Object>[],
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
