import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';

/// 为横格标记正文排版区域，排除业务标签等装饰文字；不影响布局、输入或资源所有权。
///
/// ```dart
/// import 'package:flutter/widgets.dart';
/// import 'package:cses_offline_example/daily_guidance/journal_ruled_text_scope.dart';
/// const body = JournalRuledTextScope(child: Text('正文'));
/// ```
class JournalRuledTextScope extends SingleChildRenderObjectWidget {
  /// [key] 控制展示身份；[child] 是借用的唯一正文子树，不由标记释放。
  const JournalRuledTextScope({super.key, required super.child});

  /// 在 [context] 创建透明的正文标记，不接管命中测试。
  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderJournalRuledTextScope();
}

/// 正文扫描边界；沿用代理布局、绘制与输入，不持有编辑器资源。
///
/// ```dart
/// final scope = RenderJournalRuledTextScope();
/// // 通常由 JournalRuledTextScope 创建并管理挂载生命周期。
/// ```
class RenderJournalRuledTextScope extends RenderProxyBox {}
