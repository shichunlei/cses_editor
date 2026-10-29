import 'package:cses_offline_example/daily_guidance/guidance_people.dart';
import 'package:cses_offline_example/daily_guidance/ui/journal_bottom_sheet.dart';
import 'package:cses_offline_example/daily_guidance/ui/journal_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 测试独占目录，无网络资源；长列表用于验证固定区域。
class _Directory implements GuidanceDirectory {
  /// 返回独立、稳定身份的长列表。
  @override
  Future<List<GuidancePerson>> load() async => [
    for (var i = 0; i < 40; i++) GuidancePerson(id: '$i', name: '用户 $i'),
  ];
}

/// 验证宿主面板视口、结果及主题隔离，不依赖根包内部组件。
void main() {
  for (final dark in [false, true]) {
    testWidgets('sheet isolates theme and returns after disposal: dark=$dark', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 714));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const page = Color(0xfffaf8f0);
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: page,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showJournalSheet<String>(
                    context: context,
                    builder: (sheetContext) => JournalBottomSheet(
                      title: '分享',
                      icon: LucideIcons.share2,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext, 'copied'),
                        child: const Text('复制正文'),
                      ),
                    ),
                  );
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(JournalBottomSheet));
      expect(
        Theme.of(context).colorScheme.error,
        Color(dark ? 0xffff94a4 : 0xffcc4e62),
      );
      expect(
        Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor,
        page,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('复制正文'));
      await tester.pumpAndSettle();
      expect(result, 'copied');
      expect(find.byType(JournalBottomSheet), findsNothing);
    });
  }

  for (final scale in [1.6, 2.0]) {
    testWidgets(
      'people search and actions stay fixed with keyboard and large text: $scale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 714));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        List<GuidancePerson>? chosen;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                size: const Size(320, 714),
                textScaler: TextScaler.linear(scale),
                viewInsets: const EdgeInsets.only(bottom: 253),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    chosen = await showGuidancePeoplePicker(
                      context,
                      directory: _Directory(),
                      canEdit: () => true,
                    );
                  },
                  child: const Text('打开'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('打开'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final search = find.byKey(const ValueKey('guidance-people-search'));
        final confirm = find.byKey(const ValueKey('guidance-people-confirm'));
        expect(
          tester
              .getSize(find.byKey(const PageStorageKey('guidance-people-list')))
              .height,
          greaterThanOrEqualTo(100),
        );
        final searchBefore = tester.getRect(search);
        final confirmBefore = tester.getRect(confirm);
        expect(confirmBefore.bottom, lessThanOrEqualTo(461));
        await tester.ensureVisible(
          find.byKey(const ValueKey('guidance-select-user:0')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('guidance-select-user:0')));
        await tester.pumpAndSettle();
        await tester.drag(
          find.byKey(const PageStorageKey('guidance-people-list')),
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(search), searchBefore);
        expect(tester.getRect(confirm), confirmBefore);
        expect(tester.takeException(), isNull);
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(chosen?.map((p) => p.id), ['0']);
        expect(find.byType(JournalBottomSheet), findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
