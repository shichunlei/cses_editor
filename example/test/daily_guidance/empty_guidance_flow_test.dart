import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cses_offline_example/daily_guidance/body_content_codec.dart';
import 'package:cses_offline_example/daily_guidance/empty_guidance_record.dart';
import 'package:cses_offline_example/daily_guidance/guidance_api.dart';
import 'package:cses_offline_example/daily_guidance/journal_draft.dart';
import 'package:cses_offline_example/daily_guidance/journal_share_page.dart';
import 'package:cses_offline_example/daily_guidance/local_journal_page.dart';
import 'package:cses_offline_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 借用 [tester] 当前页面的编辑状态，资源由页面释放。
EditorState _state(WidgetTester tester) =>
    tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor)).editorState;

/// 验证空白初始记录、真实入口编辑提交、分享 PNG 及重开恢复。
void main() {
  test(
    'empty record uses supplied calendar day and saves without editing',
    () async {
      for (final now in [DateTime(2026, 12, 31, 23, 59), DateTime(2027)]) {
        final ids = <String>{};
        for (final type in ['ORIENT', 'RESULT']) {
          final record = createEmptyGuidanceRecord(now, orientType: type);
          expect(ids.add(record['id'] as String), isTrue);
          expect(record['orientType'], type);
          expect(record['bizType'], 'DAILY_ORIENT');
          final field = type == 'ORIENT' ? 'dailyOrient' : 'dailyResult';
          final opposite = type == 'ORIENT' ? 'dailyResult' : 'dailyOrient';
          expect(record[field], {'content': '', 'mentions': []});
          expect(record[opposite], isNull);
          final body = record['bodyContent'] as Map<String, dynamic>;
          expect(body['meta']['dailyType'], type.toLowerCase());
          expect(
            body['children'][0]['meta']['tplFieldName'],
            type == 'ORIENT' ? '成果导向' : '导向成果',
          );
          expect(record['helpItems'], isEmpty);
          expect(record['navigatorItems'], isEmpty);
          expect(record['customData'], isEmpty);
          final api = MockGuidanceApi(record: record, latency: Duration.zero);
          final store = ApiJournalStore(
            api: api,
            recordId: record['id'] as String,
          );
          final draft = await store.read();
          expect(draft.date, journalDate(now));
          expect(BodyContentCodec.encode(draft), body);
          await store.write(draft);
          expect((await store.read()).date, journalDate(now));
        }
      }
    },
  );

  test('unsupported record type is rejected', () {
    expect(
      () => createEmptyGuidanceRecord(DateTime(2026), orientType: 'UNKNOWN'),
      throwsArgumentError,
    );
  });

  testWidgets('switching type keeps the two saved records independent', (
    tester,
  ) async {
    await tester.pumpWidget(const OfflineExampleApp());
    final identities = <String>{};
    for (final type in ['ORIENT', 'RESULT', 'ORIENT']) {
      await tester.tap(
        find.byKey(ValueKey('guidance-type-${type.toLowerCase()}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-daily-guidance')));
      await tester.pumpAndSettle();
      final page = tester.widget<LocalJournalPage>(
        find.byType(LocalJournalPage),
      );
      final store = page.store as ApiJournalStore;
      final firstVisit = identities.add(store.recordId);
      final state = _state(tester);
      final node = state.getNodeAtPath([0, 0])!;
      if (firstVisit) {
        expect(node.delta!.isEmpty, isTrue);
        await state.apply(state.transaction..insertText(node, 0, '$type 的内容'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('journal-save')));
        await tester.pumpAndSettle();
      } else {
        expect(node.delta!.toPlainText(), '$type 的内容');
      }
      await tester.tap(find.byKey(const ValueKey('journal-back')));
      await tester.pumpAndSettle();
    }
    expect(identities, hasLength(2));
    await tester.tap(find.byKey(const ValueKey('guidance-type-result')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('preview-daily-guidance')));
    await tester.pumpAndSettle();
    expect(_state(tester).editable, isFalse);
    expect(
      _state(tester).getNodeAtPath([0, 0])!.delta!.toPlainText(),
      'RESULT 的内容',
    );
    expect(find.text('导向成果'), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final type in ['ORIENT', 'RESULT']) {
    testWidgets(
      '$type starts empty, saves to preview, shares and reopens saved text',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final calls = <MethodCall>[];
        const channel = MethodChannel('cses.offline/journal_image_share');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async {
            calls.add(call);
            return true;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        final date = journalDate(DateTime.now());
        await tester.pumpWidget(const OfflineExampleApp());
        await tester.tap(
          find.byKey(ValueKey('guidance-type-${type.toLowerCase()}')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('open-daily-guidance')));
        await tester.pumpAndSettle();
        final title = type == 'ORIENT' ? '成果导向' : '导向成果';
        expect(find.text(title), findsNWidgets(2));
        final state = _state(tester);
        expect(state.editable, isTrue);
        expect(state.document.root.children, hasLength(1));
        expect(state.getNodeAtPath([0, 0])!.delta!.isEmpty, isTrue);
        final page = tester.widget<LocalJournalPage>(
          find.byType(LocalJournalPage),
        );
        final initial = await tester.runAsync(() => page.store.read());
        expect(initial!.date, date);
        const text = '从空白开始记录今天';
        await state.apply(
          state.transaction..insertText(state.getNodeAtPath([0, 0])!, 0, text),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('journal-save')));
        await tester.pumpAndSettle();
        expect(_state(tester).editable, isFalse);
        expect(find.byKey(const ValueKey('journal-save')), findsNothing);
        final store = page.store as ApiJournalStore;
        final record = (await tester.runAsync(
          () => store.api.fetch(store.recordId),
        ))!;
        expect(record['orientType'], type);
        expect(record[type == 'ORIENT' ? 'dailyOrient' : 'dailyResult'], {
          'content': text,
          'mentions': [],
        });
        expect(
          record[type == 'ORIENT' ? 'dailyResult' : 'dailyOrient'],
          isNull,
        );
        // 等待保存提示退出，避免其覆盖分享页底部操作。
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('journal-share')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        for (
          var i = 0;
          i < 80 &&
              find
                  .byKey(const ValueKey('journal-share-image'))
                  .evaluate()
                  .isEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('journal-share-image')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<JournalSharePage>(find.byType(JournalSharePage))
              .recordTitle,
          title,
        );
        for (final target in ['wechat', 'timeline']) {
          await tester.tap(find.byKey(ValueKey('journal-share-$target')));
          await tester.pumpAndSettle();
          expect(calls.last.method, 'shareImage');
          expect(calls.last.arguments['target'], target);
          expect((calls.last.arguments['png'] as Uint8List).take(8), [
            137,
            80,
            78,
            71,
            13,
            10,
            26,
            10,
          ]);
        }
        await tester.tap(find.byKey(const ValueKey('journal-share-cancel')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('journal-back')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('open-daily-guidance')));
        await tester.pumpAndSettle();
        expect(
          _state(tester).getNodeAtPath([0, 0])!.delta!.toPlainText(),
          text,
        );
        expect(_state(tester).editable, isTrue);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
