import 'dart:math' as math;

import 'package:applowy_editor_fork/applowy_editor_fork.dart';
import 'package:flutter/widgets.dart';

/// 在键盘与工具栏改变正文视口后，让当前输入行保持可见，不改变选区或请求输入焦点。
///
/// ```dart
/// import 'package:cses_editor/src/editor/editor_caret_visibility.dart';
/// final body = EditorCaretVisibility(editorState: state, child: editor);
/// // state 与 editor 的滚动资源由宿主创建、移除视图后释放。
/// ```
class EditorCaretVisibility extends StatefulWidget {
  /// [key] 控制组件身份；[editorState] 是借用会话，[child] 须使用该会话的正文滚动区域。
  /// 此组件仅拥有选区/窗口指标监听与帧后请求，不释放会话或滚动控制器。
  const EditorCaretVisibility({
    super.key,
    required this.editorState,
    required this.child,
  });

  /// 借用的输入会话，替换后旧排版请求失效。
  final EditorState editorState;

  /// 已扣除主菜单与子菜单高度的正文区域。
  final Widget child;

  /// 创建拥有监听和排版请求令牌的局部状态。
  @override
  State<EditorCaretVisibility> createState() => _EditorCaretVisibilityState();
}

/// 同一帧合并视口和光标变化，按最终排版同步滚动，不保留异步滚动任务。
class _EditorCaretVisibilityState extends State<EditorCaretVisibility>
    with WidgetsBindingObserver {
  /// 最近正文约束；只在可用尺寸变化时跟随排版，不干扰普通手动滚动。
  BoxConstraints? _lastConstraints;

  /// 当前帧后请求身份；替换会话或卸载时作废，不触碰借用资源。
  Object? _pendingReveal;

  /// 订阅当前输入位置变化，不主动打开键盘。
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.editorState.selectionNotifier.addListener(_scheduleReveal);
  }

  /// 键盘与路由依赖变化后按最终视口复核光标。
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleReveal();
  }

  /// 实际窗口指标变化后重算，覆盖宿主已消费 MediaQuery 键盘边距的情形。
  @override
  void didChangeMetrics() => _scheduleReveal();

  /// [oldWidget] 的会话被替换时注销旧监听，作废旧请求并绑定新会话。
  @override
  void didUpdateWidget(covariant EditorCaretVisibility oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.editorState, widget.editorState)) {
      oldWidget.editorState.selectionNotifier.removeListener(_scheduleReveal);
      _pendingReveal = null;
      widget.editorState.selectionNotifier.addListener(_scheduleReveal);
      _scheduleReveal();
    }
  }

  /// 注销自身选区/窗口指标监听并作废未执行请求，会话和滚动对象仍由创建者释放。
  @override
  void dispose() {
    _pendingReveal = null;
    WidgetsBinding.instance.removeObserver(this);
    widget.editorState.selectionNotifier.removeListener(_scheduleReveal);
    super.dispose();
  }

  /// 合并一帧内的输入及尺寸变化；回调必须仍属于相同会话和组件。
  void _scheduleReveal() {
    if (!mounted || _pendingReveal != null) return;
    final owner = widget.editorState;
    final token = Object();
    _pendingReveal = token;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_pendingReveal, token)) return;
      _pendingReveal = null;
      if (!identical(widget.editorState, owner)) return;
      _revealCaret(owner);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// 使用 [owner] 当前行的全局行框与最终正文视口比较，同步滚动必要距离。
  /// 不对只读、暂停、非当前路由或非折叠选区执行操作，也不重新附着输入连接。
  void _revealCaret(EditorState owner) {
    if (owner.isDisposed ||
        !owner.editable ||
        owner.localTransactionsPaused ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    final selection = owner.selection;
    if (selection == null ||
        !selection.isCollapsed ||
        !owner.canInputAt(selection)) {
      return;
    }
    final view = View.of(context);
    final keyboardHeight = math.max(
      MediaQuery.viewInsetsOf(context).bottom,
      view.viewInsets.bottom / view.devicePixelRatio,
    );
    if (keyboardHeight <= 0) return;
    final viewport = context.findRenderObject();
    final scrollable = owner.scrollableState;
    if (viewport is! RenderBox ||
        !viewport.hasSize ||
        !viewport.attached ||
        scrollable == null ||
        !scrollable.mounted) {
      return;
    }
    final position = scrollable.position;
    if (!position.hasContentDimensions ||
        position.axisDirection != AxisDirection.down) {
      return;
    }
    final rects = owner.selectionRects();
    if (rects.isEmpty) return;
    final line = rects.last;
    final origin = viewport.localToGlobal(Offset.zero);
    final top = origin.dy + 8;
    final bottom =
        math.min(
          origin.dy + viewport.size.height,
          view.physicalSize.height / view.devicePixelRatio - keyboardHeight,
        ) -
        8;
    if (bottom <= top || !line.top.isFinite || !line.bottom.isFinite) return;
    final delta = line.bottom > bottom
        ? line.bottom - bottom
        : line.top < top
        ? line.top - top
        : 0.0;
    if (delta.abs() <= .5) return;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() <= .5) return;
    owner.autoScroller?.stopAutoScroll();
    position.jumpTo(target);
  }

  /// 在 [context] 中观察实际正文约束，菜单展开和键盘动画均按当前尺寸处理。
  @override
  Widget build(BuildContext context) {
    // 注册键盘依赖，宿主即使自行消费 viewInsets 也可由实际 View 复核。
    MediaQuery.viewInsetsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_lastConstraints != constraints) {
          _lastConstraints = constraints;
          _scheduleReveal();
        }
        return widget.child;
      },
    );
  }
}
