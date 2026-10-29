import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cses_offline_example/daily_guidance/guidance_people.dart';
import 'package:cses_offline_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// 测试独占的长组织目录，只提供虚构数据，不拥有网络或账号资源。
class _Directory implements GuidanceDirectory {
  /// 返回足够滚动的独立成员快照，长名称用于验证真实中文换行。
  @override
  Future<List<GuidancePerson>> load() async => [
    for (var i = 0; i < 30; i++)
      GuidancePerson(
        id: '$i',
        name: '示例成员$i：窄屏与大字布局验证',
        department: '示例产品设计与研发部门',
      ),
  ];
}

/// 从 [tester] 借用当前页面编辑器，不持有其资源。
EditorState _editor(WidgetTester tester) =>
    tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor)).editorState;

/// 在 [tester] 中为借用的 [state] 打开真实键盘并显示工具栏。
Future<void> _focus(WidgetTester tester, EditorState state) async {
  final node = state.document.root.children.first.children.first;
  final updating = state.updateSelectionWithReason(
    Selection.collapsed(Position(path: node.path, offset: node.delta!.length)),
    reason: SelectionUpdateReason.uiEvent,
  );
  await tester.pump(const Duration(milliseconds: 300));
  await updating;
  await tester.pumpAndSettle();
}

/// 在 [tester] 的真实工具栏滚动到提及入口，不能通过不可见控件触发。
Future<void> _mention(WidgetTester tester) async {
  final target = find.byKey(const ValueKey('editor-shortcut-mention'));
  final list = find.descendant(
    of: find.byKey(const ValueKey('editor-mobile-toolbar')),
    matching: find.byType(ListView),
  );
  await tester.drag(list, const Offset(1000, 0));
  await tester.pumpAndSettle();
  for (var i = 0; i < 18 && target.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(list, const Offset(-120, 0));
    await tester.pumpAndSettle();
  }
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// 在 [tester] 等待真实平台键盘，超时失败，不以伪造 MediaQuery 代替。
Future<void> _keyboard(WidgetTester tester) async {
  for (var i = 0; i < 40 && tester.view.viewInsets.bottom == 0; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(tester.view.viewInsets.bottom, greaterThan(0), reason: '必须出现真实输入法');
  await tester.pumpAndSettle();
}

/// 核对 [tester] 中 [target] 的完整触控区域处于键盘上方，不接受仅中心可见。
void _visible(WidgetTester tester, Finder target) {
  final rect = tester.getRect(target);
  final view = tester.view;
  final bottom =
      (view.physicalSize.height - view.viewInsets.bottom) /
      view.devicePixelRatio;
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(
    rect.right,
    lessThanOrEqualTo(view.physicalSize.width / view.devicePixelRatio),
  );
  expect(rect.bottom, lessThanOrEqualTo(bottom + 1));
  expect(target.hitTestable(), findsOneWidget);
}

/// 为 [tester] 中的 [name] 场景发出实时原生截屏标记。
/// 宿主脚本在短暂停留中截取设备原生屏幕，包含真实键盘；无业务写入。
Future<void> _capture(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  final error = tester.takeException();
  final view = tester.view;
  debugPrint(
    'DEVICE_METRICS $name width=${view.physicalSize.width / view.devicePixelRatio} height=${view.physicalSize.height / view.devicePixelRatio} keyboard=${view.viewInsets.bottom / view.devicePixelRatio} font=${MediaQuery.textScalerOf(tester.element(find.byType(Scaffold).last)).scale(16) / 16}',
  );
  debugPrint('DEVICE_CAPTURE:$name');
  await Future<void>.delayed(const Duration(seconds: 3));
  expect(error, isNull);
}

/// 在物理设备验证真实页面入口及宿主组织面板，显示密度/字体由宿主脚本配置并恢复。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const scenario = String.fromEnvironment(
    'UI_SCENARIO',
    defaultValue: 'native',
  );
  testWidgets('modal device layout $scenario', (tester) async {
    final originalErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      debugPrint('DEVICE_LAYOUT_ERROR ${details.toString()}');
      originalErrorHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalErrorHandler);
    await tester.pumpWidget(const OfflineExampleApp());
    await tester.pumpAndSettle();
    await _capture(tester, '$scenario-home');
    await tester.tap(find.byKey(const ValueKey('open-daily-guidance')));
    await tester.pumpAndSettle();
    await _focus(tester, _editor(tester));
    await _mention(tester);
    final search = find.byKey(const ValueKey('mention-search'));
    await tester.tap(search);
    await _keyboard(tester);
    _visible(tester, search);
    _visible(tester, find.byKey(const ValueKey('mention-close')));
    await _capture(tester, '$scenario-mention-keyboard');
    await tester.tap(find.byKey(const ValueKey('mention-close')));
    await tester.pumpAndSettle();
    final state = _editor(tester);
    state.service.keyboardService?.closeKeyboard();
    FocusManager.instance.primaryFocus?.unfocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    final node = state.document.root.children.first.children.first;
    await state.apply(
      state.transaction..insertText(node, 0, '弹窗真机验证'),
      skipHistoryDebounce: true,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('journal-back')));
    await tester.pumpAndSettle();
    expect(find.text('有尚未保存的修改'), findsOneWidget);
    for (final text in ['继续编辑', '放弃修改', '保存后离开']) {
      _visible(tester, find.text(text));
    }
    await _capture(tester, '$scenario-leave-dialog');
    await tester.tap(find.text('继续编辑'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('journal-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('journal-back')));
    await tester.pumpAndSettle();
    // 保存提示会短暂覆盖入口，等待自然消失后滚动到真实可触达的预览按钮。
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    final preview = find.byKey(const ValueKey('preview-daily-guidance'));
    await tester.ensureVisible(preview);
    await tester.pumpAndSettle();
    _visible(tester, preview);
    await tester.tap(preview);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('journal-share')));
    await tester.pumpAndSettle();
    _visible(tester, find.byKey(const ValueKey('journal-share-copy')));
    await _capture(tester, '$scenario-share');
    await tester.tap(find.byKey(const ValueKey('journal-share-copy')));
    await tester.pumpAndSettle();
    expect(find.text('正文已复制，可粘贴分享'), findsOneWidget);

    // 使用正式组织组件和独立虚构目录，覆盖当前示例首页未提供的多选入口。
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff8b6e63)),
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                await showGuidancePeoplePicker(
                  context,
                  directory: _Directory(),
                  canEdit: () => true,
                );
              },
              child: const Text('选择人员'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择人员'));
    await tester.pumpAndSettle();
    final peopleSearch = find.byKey(const ValueKey('guidance-people-search'));
    final confirm = find.byKey(const ValueKey('guidance-people-confirm'));
    await tester.tap(peopleSearch);
    await _keyboard(tester);
    _visible(tester, peopleSearch);
    _visible(tester, confirm);
    expect(
      tester
          .getSize(find.byKey(const PageStorageKey('guidance-people-list')))
          .height,
      greaterThanOrEqualTo(100),
    );
    final searchBefore = tester.getRect(peopleSearch);
    final confirmBefore = tester.getRect(confirm);
    await _capture(tester, '$scenario-people-keyboard');
    await tester.drag(
      find.byKey(const PageStorageKey('guidance-people-list')),
      const Offset(0, -250),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(peopleSearch), searchBefore);
    expect(tester.getRect(confirm), confirmBefore);
    await _capture(tester, '$scenario-people-scrolled');
    await tester.tap(find.byKey(const ValueKey('guidance-people-close')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 8)));
}
