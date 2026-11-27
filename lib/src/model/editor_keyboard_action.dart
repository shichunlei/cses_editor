import 'package:flutter/widgets.dart';

/// 宿主注入键盘快捷栏的业务动作，不持有编辑器或业务资源。
///
/// 工具栏只管理同一实例内的点击互斥和异常反馈；宿主负责在异步回写前
/// 检查账号、权限、目标修订及会话生命周期，并自行管理弹窗和输入恢复。
///
/// ```dart
/// import 'package:cses_editor/cses_editor.dart';
/// import 'package:lucide_icons_flutter/lucide_icons.dart';
/// final action = EditorKeyboardAction(
///   id: 'reflection',
///   label: '感悟',
///   icon: LucideIcons.lightbulb,
///   onPressed: () async { /* 等待宿主业务事务完成。 */ },
/// );
/// // 通过 EditorInteractionShell(keyboardActions: [action], ...) 注入。
/// ```
@immutable
class EditorKeyboardAction {
  /// [id] 为同一工具栏内唯一且稳定的非空标识，[label] 用作文字提示及动作名称。
  /// [showLabel] 默认 true，在图标旁绘制 [label]；false 时仅绘制图标，仍沿用文字提示。
  /// [icon]提供动作图标；[enabled]默认true，false时保留入口并禁用点击。
  /// [onPressed]由宿主持有，返回的Future须等待业务及弹窗退场完成；
  /// 失败可抛出异常由当前工具栏反馈，不得向已失效的业务会话回写。
  const EditorKeyboardAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.enabled = true,
    this.showLabel = true,
  }) : assert(id != ''),
       assert(label != '');

  /// 宿主提供的稳定身份；同一工具栏内不得重复，不进入正文数据。
  final String id;

  /// 必填的动作名称，用作工具栏文字提示及错误反馈；可见短文字随工具栏横向滚动。
  final String label;

  /// 是否在图标旁显示 [label]，默认 true。false 时去掉可见文字及其间距。
  final bool showLabel;

  /// 必填视觉图标，不改变业务含义或文档协议。
  final IconData icon;

  /// 是否允许执行，默认true；禁用时保留标签、图标及语义。
  final bool enabled;

  /// 宿主拥有的异步动作；工具栏借用且不取消、释放或重放该回调。
  final Future<void> Function() onPressed;
}
