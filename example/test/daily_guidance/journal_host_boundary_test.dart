import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cses_editor/cses_editor.dart';
import 'package:cses_offline_example/daily_guidance/journal_draft.dart';
import 'package:cses_offline_example/daily_guidance/journal_store.dart';
import 'package:cses_offline_example/daily_guidance/local_journal_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 使用可控读写等待，验证页面生命周期与宿主会话边界。
class _Store implements JournalStore {
  /// 最近确认保存的业务快照。
  JournalDraft draft = JournalDraft.blank(DateTime(2026, 10, 29));

  /// 非空时挂起读取，由测试决定何时返回。
  Completer<JournalDraft?>? pendingRead;

  /// 非空时挂起写入，可模拟磁盘失败。
  Completer<void>? pendingWrite;

  /// 已发起读取次数，用于确认新存储未被旧页面使用。
  int reads = 0;

  /// 返回草稿或等待测试提供读取结果，不访问磁盘。
  @override
  Future<JournalDraft?> read() async {
    reads++;
    return pendingRead == null ? draft : pendingRead!.future;
  }

  /// 等待可选写入门闩后保存[draft]；失败时不覆盖当前快照。
  @override
  Future<void> write(JournalDraft draft) async {
    await pendingWrite?.future;
    this.draft = JournalDraft.fromJson(draft.toJson());
  }
}

/// 在[tester]打开[store]，用[identity]观测宿主身份，借用可选[services]。
Future<EditorState> _open(
  WidgetTester tester,
  _Store store,
  Object? Function() identity, {
  CollabHostServices services = const CollabHostServices(),
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: LocalJournalPage(
        store: store,
        sessionIdentity: identity,
        hostServices: services,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor)).editorState;
}

/// 验证服务可注入且加载、预览与保存失败不会恢复已撤销的会话。
void main() {
  testWidgets('late draft load is rejected after host identity changes', (
    tester,
  ) async {
    final store = _Store()..pendingRead = Completer<JournalDraft?>();
    var identity = 'first';
    await tester.pumpWidget(
      MaterialApp(
        home: LocalJournalPage(store: store, sessionIdentity: () => identity),
      ),
    );
    await tester.pump();
    identity = 'second';
    store.pendingRead!.complete(store.draft);
    await tester.pumpAndSettle();
    expect(find.byType(AppFlowyEditor), findsNothing);
    expect(find.text('宿主会话已变化，请关闭后重新打开'), findsOneWidget);
    identity = 'first';
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AppFlowyEditor), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'replacing a store under the same widget identity freezes the old session',
    (tester) async {
      final first = _Store();
      final second = _Store();
      final state = await _open(tester, first, () => 'same');
      await tester.pumpWidget(
        MaterialApp(
          home: LocalJournalPage(store: second, sessionIdentity: () => 'same'),
        ),
      );
      await tester.pumpAndSettle();
      expect(state.editable, isFalse);
      expect(second.reads, 0);
      expect(find.text('宿主会话已变化，请关闭后重新打开'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'save cannot acknowledge a session changed during keyboard hide',
    (tester) async {
      var identity = 'first';
      final state = await _open(tester, _Store(), () => identity);
      final hidden = Completer<void>();
      var waiting = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.textInput, (call) async {
            if (call.method == 'TextInput.hide') {
              waiting = true;
              await hidden.future;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.textInput, null),
      );
      await tester.tap(find.byKey(const ValueKey('journal-save')));
      await tester.pump();
      expect(waiting, isTrue);
      identity = 'second';
      hidden.complete();
      await tester.pumpAndSettle();
      expect(state.editable, isFalse);
      expect(find.byType(AppFlowyEditor), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('failed exit save never re-enables an obsolete host session', (
    tester,
  ) async {
    final store = _Store();
    var identity = 'first';
    final state = await _open(tester, store, () => identity);
    await state.apply(
      state.transaction..insertText(state.getNodeAtPath([0, 0])!, 0, '旧会话正文'),
    );
    store.pendingWrite = Completer<void>();
    await tester.tap(find.byKey(const ValueKey('journal-back')));
    await tester.pump();
    identity = 'second';
    store.pendingWrite!.completeError(const FileSystemException('full'));
    await tester.pumpAndSettle();
    expect(state.editable, isFalse);
    expect(find.text('宿主会话已变化，请关闭后重新打开'), findsOneWidget);
    store.pendingWrite = null;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('host picker returns its user under protected permission', (
    tester,
  ) async {
    var called = false;
    final state = await _open(
      tester,
      _Store(),
      () => 'same',
      services: CollabHostServices(
        pickMentionUser: (context, {required keyword, required canEdit}) async {
          called = true;
          expect(canEdit.value, isTrue);
          return const CollabMentionUser(id: 'host-user', name: '宿主选人');
        },
      ),
    );
    state.selection = Selection.collapsed(Position(path: [0, 0]));
    await tester.pumpAndSettle();
    final result = await pickEditorMentionUser(
      tester.element(find.byType(AppFlowyEditor)),
      state,
    );
    expect(called, isTrue);
    expect(result?.id, 'host-user');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'host picker result is rejected permanently after observed identity switch',
    (tester) async {
      var identity = 'first';
      final result = Completer<CollabMentionUser?>();
      ValueListenable<bool>? permission;
      final state = await _open(
        tester,
        _Store(),
        () => identity,
        services: CollabHostServices(
          pickMentionUser: (context, {required keyword, required canEdit}) {
            permission = canEdit;
            return result.future;
          },
        ),
      );
      state.selection = Selection.collapsed(Position(path: [0, 0]));
      await tester.pumpAndSettle();
      final picked = pickEditorMentionUser(
        tester.element(find.byType(AppFlowyEditor)),
        state,
      );
      await tester.pump();
      identity = 'second';
      await tester.pump(const Duration(milliseconds: 220));
      expect(permission!.value, isFalse);
      identity = 'first';
      result.complete(const CollabMentionUser(id: 'late', name: '迟到人员'));
      expect(await picked, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  for (final kind in ['pilot', 'help']) {
    testWidgets(
      'host picker integrates with the actual $kind keyboard action',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final state = await _open(
          tester,
          _Store(),
          () => 'same',
          services: CollabHostServices(
            pickMentionUser:
                (context, {required keyword, required canEdit}) async =>
                    CollabMentionUser(id: 'host-$kind', name: '宿主人员'),
          ),
        );
        await state.apply(
          state.transaction..insertText(state.getNodeAtPath([0, 0])!, 0, '来源'),
        );
        state.selection = Selection.collapsed(
          Position(path: [0, 0], offset: 2),
        );
        await tester.pumpAndSettle();
        final action = find.byKey(
          ValueKey('editor-keyboard-host-guidance-action-$kind'),
        );
        final toolbar = find.descendant(
          of: find.byKey(const ValueKey('editor-mobile-toolbar')),
          matching: find.byType(ListView),
        );
        for (
          var i = 0;
          i < 12 && action.hitTestable().evaluate().isEmpty;
          i++
        ) {
          await tester.drag(toolbar, const Offset(-140, 0));
          await tester.pumpAndSettle();
        }
        expect(action.hitTestable(), findsOneWidget);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(state.getNodeAtPath([0, 0])!.delta!.toPlainText(), '来源');
        expect(state.getNodeAtPath([0, 1])!.attributes['guidance_entry'], kind);
        expect(jsonEncode(state.document.toJson()), contains('host-$kind'));
        expect(state.localTransactionsPaused, isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
