import 'package:flutter/foundation.dart';

/// 未绑定编辑会话的展示组件诊断出口，不持有宿主或网络资源。
abstract final class EditorDiagnostics {
  /// 输出[message]、原始[error]、[stackTrace]及可选[tag]到调试控制台。
  static void report(
    String message, {
    required Object error,
    required StackTrace stackTrace,
    String? tag,
  }) {
    debugPrint('${tag ?? 'Editor'}: $message: $error\n$stackTrace');
  }
}
