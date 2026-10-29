import 'dart:convert';

import 'package:cses_offline_example/daily_guidance/body_content_codec.dart';
import 'package:cses_offline_example/daily_guidance/journal_draft.dart';
import 'package:cses_offline_example/daily_guidance/journal_store.dart';

/// 宿主注入的单记录服务：读取接口记录，仅提交 bodyContent 补丁，不生成其他业务字段。
/// 宿主负责认证与客户端释放，页面不拥有网络资源。
///
/// ```dart
/// final api = MockGuidanceApi(record: response);
/// final store = ApiJournalStore(api: api, recordId: response['id'] as String);
/// final draft = await store.read();
/// await store.write(draft);
/// ```
abstract interface class GuidanceApi {
  /// 异步获取固定 [recordId] 的记录，包含 id、orientType 和 bodyContent；失败抛错。
  Future<Map<String, dynamic>> fetch(String recordId);

  /// 异步提交 [recordId] 的 JSON [patch]，只允许 bodyContent；完成表示后台确认。
  Future<void> save(String recordId, Map<String, dynamic> patch);
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

  /// 捕获并校验 [recordId] 的独立 [patch]，只替换 bodyContent，其他字段保持。
  @override
  Future<void> save(String recordId, Map<String, dynamic> patch) async {
    if (patch.length != 1 || patch['bodyContent'] is! Map<String, dynamic>) {
      throw const FormatException('只能提交正文');
    }
    final body =
        jsonDecode(jsonEncode(patch['bodyContent'])) as Map<String, dynamic>;
    BodyContentCodec.decode(body);
    if (latency != Duration.zero) await Future<void>.delayed(latency);
    final data = jsonDecode(_recordJson) as Map<String, dynamic>;
    if (data['id'] != recordId) throw StateError('记录不存在');
    data['bodyContent'] = body;
    _recordJson = jsonEncode(data);
  }
}

/// 固定记录身份的服务适配器，页面借用；只解析 orientType 和 bodyContent。
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
    _title = data['orientType'] == 'RESULT' ? '今日成果' : '今日导向';
    return draft;
  }

  /// 将实时 [draft] 转回原始正文协议，仅提交 bodyContent JSON。
  @override
  Future<void> write(JournalDraft draft) =>
      api.save(recordId, {'bodyContent': BodyContentCodec.encode(draft)});
}
