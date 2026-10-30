import 'dart:convert';

import 'package:cses_offline_example/daily_guidance/body_content_codec.dart';
import 'package:cses_offline_example/daily_guidance/journal_draft.dart';
import 'package:cses_offline_example/daily_guidance/guidance_record_fields.dart';
import 'package:cses_offline_example/daily_guidance/journal_store.dart';

/// 宿主注入的单记录服务：读取和提交完整记录，正文与派生业务字段在同次请求中保存。
/// 宿主负责认证与客户端释放，页面不拥有网络资源。
///
/// ```dart
/// final api = MockGuidanceApi(record: response);
/// final store = ApiJournalStore(api: api, recordId: response['id'] as String);
/// final draft = await store.read();
/// await store.write(draft);
/// ```
abstract interface class GuidanceApi {
  /// 异步获取固定 [recordId] 的完整记录，包含所有业务字段和 bodyContent；失败抛错。
  Future<Map<String, dynamic>> fetch(String recordId);

  /// 异步提交 [recordId] 的完整 JSON [record]；实现方不得修改借用的请求，完成表示后台确认。
  Future<void> save(String recordId, Map<String, dynamic> record);
}

/// 无网络 mock 服务，宿主持有实例；JSON 深拷贝隔离请求响应，重开保留，重启重置。
///
/// ```dart
/// final api = MockGuidanceApi(record: response);
/// final data = await api.fetch(response['id'] as String);
/// ```
final class MockGuidanceApi implements GuidanceApi {
  /// 拷贝宿主传入的完整 [record]；[latency] 模拟请求耗时，不得为负。
  MockGuidanceApi({
    required Map<String, dynamic> record,
    this.latency = const Duration(milliseconds: 200),
  }) : _recordJson = jsonEncode(record) {
    if (latency.isNegative) throw ArgumentError.value(latency, 'latency');
  }

  /// 请求模拟时长，不持有循环定时器或客户端。
  final Duration latency;

  /// mock 后台独占的数据值，不与页面共享 Map。
  String _recordJson;

  /// 按 [recordId] 返回独立接口记录，错误身份抛错。
  @override
  Future<Map<String, dynamic>> fetch(String recordId) async {
    if (latency != Duration.zero) await Future<void>.delayed(latency);
    final data = jsonDecode(_recordJson) as Map<String, dynamic>;
    if (data['id'] != recordId) throw StateError('记录不存在');
    return data;
  }

  /// 深拷贝并校验 [recordId] 的完整 [record]；异步成功后整体替换后台记录。
  /// 调用者仍拥有请求；身份错误、缺字段或正文无效时不修改后台。
  @override
  Future<void> save(String recordId, Map<String, dynamic> record) async {
    final snapshot = jsonEncode(record);
    final data = jsonDecode(snapshot) as Map<String, dynamic>;
    final previous = jsonDecode(_recordJson) as Map<String, dynamic>;
    if (previous['id'] != recordId || data['id'] != recordId) {
      throw StateError('记录不存在');
    }
    if (!previous.keys.every(data.containsKey) ||
        data['bizType'] is! String ||
        !const ['ORIENT', 'RESULT'].contains(data['orientType']) ||
        data['bodyContent'] is! Map<String, dynamic> ||
        data[data['orientType'] == 'ORIENT' ? 'dailyOrient' : 'dailyResult']
            is! Map ||
        !data.containsKey(
          data['orientType'] == 'ORIENT' ? 'dailyResult' : 'dailyOrient',
        ) ||
        data[data['orientType'] == 'ORIENT' ? 'dailyResult' : 'dailyOrient'] !=
            null ||
        !const [
          'todoContent',
          'expectedEffectContent',
          'thinking',
          'selfCheck',
          'customData',
        ].every((key) => data[key] is Map) ||
        data['helpItems'] is! List ||
        data['navigatorItems'] is! List) {
      throw const FormatException('必须提交完整记录');
    }
    BodyContentCodec.decode(data['bodyContent'] as Map<String, dynamic>);
    if (latency != Duration.zero) await Future<void>.delayed(latency);
    _recordJson = snapshot;
  }
}

/// 固定记录身份的服务适配器，页面借用；保留完整记录并从最新正文派生栏目与聚合业务字段。
///
/// ```dart
/// final store = ApiJournalStore(api: api, recordId: 'record-1');
/// final draft = await store.read();
/// print(store.title);
/// ```
final class ApiJournalStore implements JournalStore {
  /// 借用宿主的 [api]，将全部请求绑定到不可变 [recordId]。
  ApiJournalStore({required this.api, required this.recordId});

  /// 不获取其资源所有权的宿主服务。
  final GuidanceApi api;

  /// 当前会话不可变的后台记录身份。
  final String recordId;

  /// 经读取确认的头部标题；非法 orientType 拒绝加载。
  String get title => _title;

  /// 读取成功后固定的标题，不接受外部直接修改。
  String _title = '今日导向';

  /// 最近成功读取的完整记录快照；独占 JSON 值，隔离服务返回值的后续修改。
  String? _recordJson;

  /// 获取并校验当前记录，接口失败或正文无效时抛错，不替换为空白草稿。
  @override
  Future<JournalDraft> read() async {
    final data = await api.fetch(recordId);
    if (data['id'] != recordId ||
        !const ['ORIENT', 'RESULT'].contains(data['orientType']) ||
        data['bodyContent'] is! Map<String, dynamic>) {
      throw const FormatException('今日导向响应无效');
    }
    final draft = BodyContentCodec.decode(
      data['bodyContent'] as Map<String, dynamic>,
    );
    _recordJson = jsonEncode(data);
    _title = data['orientType'] == 'RESULT' ? '今日成果' : '今日导向';
    return draft;
  }

  /// 从实时 [draft] 同步捕获正文及派生字段，与成功读取的完整记录一起异步提交。
  /// 保留其他字段和扩展值；读取前拒绝保存，失败可使用相同来源重试。
  @override
  Future<void> write(JournalDraft draft) async {
    final original = _recordJson;
    if (original == null) throw StateError('请先读取完整记录');
    final body = BodyContentCodec.encode(draft);
    final record = jsonDecode(original) as Map<String, dynamic>;
    record.addAll({
      'bodyContent': body,
      ...GuidanceRecordFields.extract(
        body,
        orientType: record['orientType'] as String,
      ),
    });
    await api.save(recordId, record);
  }
}
