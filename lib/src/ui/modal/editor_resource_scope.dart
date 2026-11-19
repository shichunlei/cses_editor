import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// 只读资源的真实加载和绘制结果；失败不能作为就绪参与截图。
enum EditorResourceStatus {
  /// 资源仍在读取、解码或等待实际绘制。
  loading,

  /// 原视图已产生可绘制内容。
  ready,

  /// 原加载器报告失败，不能作为截图成功。
  failed,
}

/// 聚合一个展示实例的资源状态与媒体关闭等待，不下载或关闭资源；测量和画布各自持有实例。
///
/// ```dart
/// import 'package:cses_editor/cses_editor.dart';
/// final resources = EditorResourceTracker();
/// // EditorResourceScope(tracker: resources, child: body)
/// // 卸载 body 并完成该帧后 await resources.waitForDisposals(); resources.dispose()。
/// ```
class EditorResourceTracker extends ChangeNotifier
    implements ValueListenable<bool> {
  /// 每个实际视图独占凭据，避免相同地址的旧实例放行新实例。
  final Map<Object, EditorResourceStatus> _entries = {};

  /// 组件拥有的关闭操作之观测 Future；观测器只等待，不关闭播放器。
  final List<Future<void>> _disposals = [];

  /// 首个未被等待者消费的关闭失败，保留原异常与堆栈。
  (Object, StackTrace)? _disposalFailure;

  /// 并发等待共享一次排空，防止某个调用提前跳过仍在关闭的播放器。
  Future<void>? _waitingForDisposals;

  /// 关闭后忽略迟到资源报告和帧后回调。
  bool _disposed = false;

  /// 合并同一帧中的资源通知，避免构建阶段重建祖先。
  bool _scheduled = false;

  /// 无异步资源时为 true；已登记的资源必须全部完成真实解码和绘制。
  @override
  bool get value =>
      !_disposed &&
      _entries.values.every((state) => state == EditorResourceStatus.ready);

  /// 当前实例是否存在失败资源，宿主据此显示可重试原因。
  bool get failed =>
      !_disposed && _entries.values.contains(EditorResourceStatus.failed);

  /// 更新视图拥有的 [ticket] 为 [status]，关闭或未变化时忽略；不拥有资源任务。
  void report(Object ticket, EditorResourceStatus status) {
    if (_disposed || _entries[ticket] == status) return;
    _entries[ticket] = status;
    _notifyAfterFrame();
  }

  /// 移除已卸载资源的 [ticket]，不关闭图片流或播放器。
  void release(Object ticket) {
    if (_disposed || _entries.remove(ticket) == null) return;
    _notifyAfterFrame();
  }

  /// 当前帧先更新可读取状态，再合并通知，避免构建或释放子树时重建祖先。
  void _notifyAfterFrame() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  /// 观测组件创建的 [operation]，不取得其资源所有权，也不启动额外关闭。
  /// 卸载期间仍允许登记：祖先的 dispose 可能早于媒体子树的 dispose。
  /// 异常立即被观测并由 [waitForDisposals] 原样传播，避免后台未处理异常。
  void trackDisposal(Future<void> operation) {
    _disposals.add(
      operation.then<void>(
        (_) {},
        onError: (Object error, StackTrace stack) {
          _disposalFailure ??= (error, stack);
        },
      ),
    );
  }

  /// 等待已登记及等待期间新增的媒体关闭操作；调用者先卸载/切换静态并完成该帧。
  /// 并发调用共享排空结果；失败保留原异常堆栈向上传播，不通知已释放的 Widget。
  /// 观测器 dispose 后仍可调用，且不隐式关闭共享客户端或文档。
  Future<void> waitForDisposals() => _waitingForDisposals ??= _drainDisposals()
      .whenComplete(() => _waitingForDisposals = null);

  /// 顺序排空已被观测的 Future 批次，避免新到的关闭操作被前一次快照遗漏。
  Future<void> _drainDisposals() async {
    while (_disposals.isNotEmpty) {
      final batch = List<Future<void>>.of(_disposals);
      _disposals.clear();
      await Future.wait(batch);
    }
    final failure = _disposalFailure;
    _disposalFailure = null;
    if (failure != null) Error.throwWithStackTrace(failure.$1, failure.$2);
  }

  /// 关闭此展示实例的观测，迟到通知不再发布；不接管宿主文档。
  @override
  void dispose() {
    _disposed = true;
    _entries.clear();
    super.dispose();
  }
}

/// 向资源组件借出实例观测器，默认只观察，不改变编辑权限。
///
/// ```dart
/// import 'package:flutter/widgets.dart';
/// import 'package:cses_editor/cses_editor.dart';
/// final tracker = EditorResourceTracker();
/// final view = EditorResourceScope(tracker: tracker, staticMedia: true, child: const SizedBox());
/// // 卸载 view 后 tracker.dispose()。
/// ```
class EditorResourceScope extends InheritedWidget {
  /// [key] 标识作用域；[tracker] 由宿主拥有；[staticMedia] 默认 false，true 时音视频仅显示静态封面或卡片。
  /// [child] 借用正文子树，作用域不创建或关闭媒体、文档及观测器。
  const EditorResourceScope({
    super.key,
    required this.tracker,
    this.staticMedia = false,
    required super.child,
  });

  /// 宿主持有的资源观测器，各个展示实例不得共享。
  final EditorResourceTracker tracker;

  /// true 时媒体只输出静态封面/卡片，不初始化音视频播放器；切换时由媒体创建者关闭。
  final bool staticMedia;

  /// 在 [context] 中读取可空作用域；初始化阶段只读取，不注册依赖。
  static EditorResourceScope? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<EditorResourceScope>();

  /// 当 [oldWidget] 的实例配置变化时更新资源观测绑定。
  @override
  bool updateShouldNotify(EditorResourceScope oldWidget) =>
      tracker != oldWidget.tracker || staticMedia != oldWidget.staticMedia;
}

/// 将原加载组件的状态同步登记、帧后通知作用域，不替换加载、缓存和渲染。
/// 仅供包内资源组件组合；资源生命周期仍由实际组件负责。
class EditorResourceView extends StatefulWidget {
  /// [key] 控制资源实例；[status] 描述本帧结果；[child] 是原加载器输出。
  const EditorResourceView({
    super.key,
    required this.status,
    required this.child,
  });

  /// 当前帧加载结果；ready 仅在真实图片帧或原 SVG 内容可绘制后使用。
  final EditorResourceStatus status;

  /// 原组件输出，不接管其资源所有权。
  final Widget child;

  /// 创建此资源独占的登记凭据。
  @override
  State<EditorResourceView> createState() => _EditorResourceViewState();
}

/// 帧后通知避免组件构建、替换和释放期间同步重建祖先。
class _EditorResourceViewState extends State<EditorResourceView> {
  /// 本视图独占的观测凭据，换源/卸载解除旧绑定。
  final Object _ticket = Object();

  /// 从作用域借用的当前观测器，本视图不释放它。
  EditorResourceTracker? _tracker;

  /// 继承的观测器改变时解除旧绑定并登记当前帧。
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context
        .dependOnInheritedWidgetOfExactType<EditorResourceScope>()
        ?.tracker;
    if (!identical(next, _tracker)) {
      _tracker?.release(_ticket);
      _tracker = next;
    }
    _report();
  }

  /// [oldWidget] 状态变化后交付新帧，旧帧回调不能覆盖新状态。
  @override
  void didUpdateWidget(EditorResourceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _report();
  }

  /// 同步登记最新状态，通知合并到帧后；卸载后不继续登记资源。
  void _report() => _tracker?.report(_ticket, widget.status);

  /// 同步解除登记并帧后通知，不关闭外部观测器。
  @override
  void dispose() {
    _tracker?.release(_ticket);
    super.dispose();
  }

  /// 在 [context] 输出原加载内容，不执行数据请求。
  @override
  Widget build(BuildContext context) => widget.child;
}
