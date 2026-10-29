import 'package:flutter/material.dart';

/// 打开宿主底部面板并在子组件释放后返回；不接管业务状态或输入焦点恢复。
/// [context] 提供导航及主题，[builder] 创建内容；取消返回 null，异常透传。
Future<T?> showJournalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) async {
  final navigator = Navigator.of(context);
  final route = ModalBottomSheetRoute<T>(
    builder: (context) => journalModalTheme(context, Builder(builder: builder)),
    capturedThemes: InheritedTheme.capture(
      from: context,
      to: navigator.context,
    ),
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    modalBarrierColor: Colors.black54,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  );
  final result = await navigator.push(route);
  await route.completed;
  return result;
}

/// 打开宿主居中面板，等待退场/资源释放后返回，不写正文或恢复编辑器焦点。
/// [context] 提供主题及根导航，[builder] 创建内容；取消返回 null，异常透传。
Future<T?> showJournalDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<T>(
    context: context,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
    builder: (context) => journalModalTheme(context, Builder(builder: builder)),
    barrierColor: Colors.black54,
  );
  final result = await navigator.push(route);
  await route.completed;
  return result;
}

/// 为借用的 [child] 应用弹窗局部主题；[context] 提供亮度和字体，不影响纸张页面。
/// 配色、圆角及按钮尺寸遵循项目 UI 规范，不持有或释放业务资源。
Widget journalModalTheme(BuildContext context, Widget child) {
  final base = Theme.of(context);
  final dark = base.brightness == Brightness.dark;
  final scheme = base.colorScheme.copyWith(
    primary: Color(dark ? 0xffb0a5ff : 0xff6558d9),
    onPrimary: Color(dark ? 0xff231751 : 0xffffffff),
    surface: Color(dark ? 0xff202126 : 0xffffffff),
    onSurface: Color(dark ? 0xffeeeef5 : 0xff242633),
    onSurfaceVariant: Color(dark ? 0xffa9aab9 : 0xff757888),
    outline: Color(dark ? 0xff383941 : 0xffececf2),
    error: Color(dark ? 0xffff94a4 : 0xffcc4e62),
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(11));
  final button = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(0, 42)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 19, vertical: 10),
    ),
    shape: WidgetStatePropertyAll(shape),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: scheme.outline),
  );
  return Theme(
    data: base.copyWith(
      colorScheme: scheme,
      textTheme: base.textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 19),
      dividerColor: scheme.outline,
      filledButtonTheme: FilledButtonThemeData(style: button),
      textButtonTheme: TextButtonThemeData(style: button),
      outlinedButtonTheme: OutlinedButtonThemeData(style: button),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Color(dark ? 0xff292a32 : 0xfff8f8fb),
        isDense: true,
        contentPadding: const EdgeInsets.all(12),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: scheme.primary),
        ),
      ),
    ),
    child: child,
  );
}
