import 'dart:convert';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cses_offline_example/daily_guidance/guidance_api.dart';
import 'package:cses_offline_example/daily_guidance/guidance_host.dart';
import 'package:cses_offline_example/daily_guidance/guidance_entries.dart';
import 'package:cses_offline_example/daily_guidance/guidance_people.dart';
import 'package:cses_offline_example/daily_guidance/journal_draft.dart';
import 'package:cses_offline_example/daily_guidance/journal_store.dart';
import 'package:cses_offline_example/daily_guidance/local_journal_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 本测试独占的旧引用快照存储，不创建文件或客户端。
class _Store implements JournalStore {
  /// 持有独立 [value]，供兼容旧本地引用展示。
  _Store(this.value);

  /// 最后一次成功持久化的数据。
  JournalDraft value;

  /// 读取当前快照。
  @override
  Future<JournalDraft?> read() async => value;

  /// 校验并保存 [draft]，不访问用户数据。
  @override
  Future<void> write(JournalDraft draft) async {
    value = JournalDraft.fromJson(draft.toJson());
  }
}

/// 在独立 [record] 正文追加人员引用；[kind] 可选 help/pilot，省略则普通 @。
void _appendUser(
  Map<String, dynamic> record,
  String id,
  String name, {
  String? kind,
}) {
  final body = record['bodyContent'] as Map;
  final cover = (body['children'] as List).first as Map;
  (cover['children'] as List).add({
    'id': 'mention-$id',
    'flavour': 'paragraph',
    'nodeType': 'editable',
    'props': {},
    'meta': {},
    'children': [
      if (kind != null)
        {
          'insert': {'dailyTag': kind},
        },
      {
        'insert': {'mention': name},
        'attributes': {'mentionId': id, 'mentionType': 'user'},
      },
    ],
  });
}

/// 验证头像通过宿主注入覆盖所有引用形式，任务保持实体图标，展示不改变 JSON。
void main() {
  for (final mode in JournalPageMode.values) {
    testWidgets(
      '$mode shares avatars across user/help/pilot and keeps original task icon',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        const captureImages = bool.fromEnvironment('SAVE_AVATAR_SCREENSHOTS');
        final capture = GlobalKey();
        if (captureImages) {
          await tester.runAsync(() async {
            await ui.loadFontFromList(
              await File(
                '/System/Library/Fonts/STHeiti Medium.ttc',
              ).readAsBytes(),
              fontFamily: 'AvatarPreview',
            );
            await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
                  rootBundle.load(
                    'packages/lucide_icons_flutter/assets/lucide.ttf',
                  ),
                ))
                .load();
          });
        }
        final record =
            jsonDecode(File('文档完整数据结构.json').readAsStringSync())
                as Map<String, dynamic>;
        _appendUser(record, 'ordinary-user', '普通用户');
        _appendUser(record, 'pilot-user', '领航用户', kind: 'pilot');
        final api = MockGuidanceApi(record: record, latency: Duration.zero);
        await tester.pumpWidget(
          RepaintBoundary(
            key: capture,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                fontFamily: captureImages ? 'AvatarPreview' : null,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xff8b6e63),
                ),
              ),
              home: LocalJournalPage(
                store: ApiJournalStore(
                  api: api,
                  recordId: record['id'] as String,
                ),
                mode: mode,
                hostServices: createDemoGuidanceHostServices(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final avatars = tester
            .widgetList<DemoMentionAvatar>(find.byType(DemoMentionAvatar))
            .toList();
        final users = avatars.map((widget) => widget.userId).toSet();
        expect(
          users,
          containsAll([
            'ordinary-user',
            'pilot-user',
            '5ffd465e263864787b87aa01',
            '678',
          ]),
        );
        expect(users, isNot(contains('6ae2bd06bc2701ed9ddf443c')));
        expect(find.byIcon(LucideIcons.squareCheck), findsOneWidget);
        expect(find.byIcon(LucideIcons.listTodo), findsNothing);
        for (final avatar in avatars) {
          expect(avatar.size, greaterThan(0));
        }
        final data = await api.fetch(record['id'] as String);
        expect(data, record);
        if (captureImages) {
          await tester.runAsync(
            () => precacheImage(
              const AssetImage('assets/images/daily_guidance_mountain.png'),
              tester.element(find.byType(AppFlowyEditor)),
            ),
          );
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final image =
                await (capture.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            await File(
              '../docs/verification/mention-avatar-icons-20261029/${mode.name}.png',
            ).writeAsBytes(png!.buffer.asUint8List());
            image.dispose();
          });
        }
        if (mode == JournalPageMode.edit) {
          final state = tester
              .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
              .editorState;
          await state.apply(
            state.transaction
              ..insertText(state.getNodeAtPath([0, 0])!, 0, '头像测试 '),
          );
          await tester.tap(find.byKey(const ValueKey('journal-save')));
          await tester.pumpAndSettle();
          final saved = await api.fetch(record['id'] as String);
          expect(jsonEncode(saved['bodyContent']), contains('头像测试'));
          expect(
            jsonEncode(saved['bodyContent']),
            isNot(contains('avatarUrl')),
          );
          expect(
            jsonEncode(saved['bodyContent']),
            contains('"mentionType":"task"'),
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets(
    'example service copies explicit avatar URLs and uses first-letter fallback',
    (tester) async {
      final urls = {'u1': 'https://provided.example/avatar.png'};
      final services = createDemoGuidanceHostServices(avatarUrls: urls);
      urls['u1'] = 'https://wrong.example/avatar.png';
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final mapped =
                  services.mentionAvatarBuilder!(
                        context,
                        userId: 'u1',
                        name: '张三',
                        size: 18,
                      )
                      as DemoMentionAvatar;
              expect(mapped.avatarUrl, 'https://provided.example/avatar.png');
              return services.mentionAvatarBuilder!(
                context,
                userId: 'u2',
                name: '李四',
                size: 18,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('李'), findsOneWidget);
      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.radius, 9);
      expect(avatar.foregroundImage, isNull);
    },
  );

  testWidgets(
    'legacy user mentions also receive the example avatar injection',
    (tester) async {
      final blank = JournalDraft.blank(DateTime(2026, 10, 29));
      final document = Document.fromJson(
        jsonDecode(blank.documentJson) as Map<String, dynamic>,
      );
      final data = blank.toJson();
      try {
        document.root.children.first.children.first.updateAttributes({
          'delta': guidanceMentionDelta([
            const GuidancePerson(id: 'legacy-user', name: '旧用户'),
          ]).toJson(),
        });
        data['document'] = document.toJson();
      } finally {
        document.dispose();
      }
      await tester.pumpWidget(
        MaterialApp(
          home: LocalJournalPage(
            store: _Store(JournalDraft.fromJson(data)),
            mode: JournalPageMode.preview,
            hostServices: createDemoGuidanceHostServices(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<DemoMentionAvatar>(find.byType(DemoMentionAvatar)).userId,
        'legacy-user',
      );
      expect(find.text('@旧用户'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
