import 'dart:convert';

import 'package:applowy_editor_fork/applowy_editor_fork.dart';
import 'package:cses_editor/cses_editor.dart';
import 'package:cses_offline_example/daily_guidance/journal_draft.dart';
import 'package:cses_offline_example/daily_guidance/journal_exchange_keys.dart';
import 'package:cses_offline_example/daily_guidance/journal_store.dart';
import 'package:cses_offline_example/daily_guidance/local_journal_page.dart';
import 'package:cses_offline_example/daily_guidance/ui/company_journal_poster.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// 使用实际预览入口和播放器控件验证两种预览模式。
void main() {
  for (final mode in JournalPageMode.values) {
    testWidgets('$mode preview opens media without editing the journal', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(720, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final originalPlatform = VideoPlayerPlatform.instance;
      final platform = _MediaPlatform();
      VideoPlayerPlatform.instance = platform;
      addTearDown(() => VideoPlayerPlatform.instance = originalPlatform);
      final store = _Store();
      final opened = <(String, String, String?)>[];

      await tester.pumpWidget(
        MaterialApp(
          home: LocalJournalPage(
            store: store,
            mode: mode,
            poster: mode == JournalPageMode.edit
                ? CompanyJournalPoster.hfysV2
                : null,
            hostServices: CollabHostServices(
              openMedia: (context, kind, url, name) async {
                opened.add((kind, url, name));
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = tester
          .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
          .editorState;
      if (mode == JournalPageMode.edit) {
        expect(find.byTooltip('更多操作'), findsWidgets);
        await state.apply(
          state.transaction..insertText(state.getNodeAtPath([0, 0])!, 0, '已保存'),
        );
        await tester.tap(find.byKey(const ValueKey('journal-save')));
        await tester.pumpAndSettle();
      }
      final writes = mode == JournalPageMode.edit ? 1 : 0;
      expect(store.writes, writes);
      expect(state.editable, isFalse);
      expect(find.byTooltip('更多操作'), findsNothing);
      final before = jsonEncode(state.document.toJson());

      final picture = find.byKey(const ValueKey('collab-image-tap-image'));
      // 等待后台解码与 Flutter 图像帧，取得真实的图片点击面积。
      for (var frame = 0; frame < 10; frame++) {
        if (find
                .descendant(of: picture, matching: find.byType(Image))
                .evaluate()
                .isNotEmpty &&
            tester.getSize(picture).height > 0) {
          break;
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 75)),
        );
        await tester.pump();
      }
      await _showControl(tester, picture);
      await tester.tap(picture);
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(
        tester
            .widget<Image>(
              find.descendant(
                of: find.byType(InteractiveViewer),
                matching: find.byType(Image),
              ),
            )
            .fit,
        BoxFit.contain,
      );
      await tester.tap(find.byTooltip('关闭大图'));
      await tester.pumpAndSettle();

      for (final (kind, playKey, extension) in const [
        ('video', 'collab-video-block-play', 'mp4'),
        ('audio', 'resource-audio-play', 'mp3'),
      ]) {
        final play = find.byKey(ValueKey(playKey));
        await _showControl(tester, play);
        final player = platform.playerFor(
          'https://example.test/$kind.$extension',
        );
        await tester.tap(play);
        await tester.pump();
        expect(platform.playing, contains(player));

        final slider = find.byKey(ValueKey('collab-$kind-progress'));
        await _showControl(tester, slider);
        final track = tester.getRect(slider);
        await tester.dragFrom(
          Offset(track.left + 12, track.center.dy),
          Offset(track.width * .6, 0),
        );
        await tester.pump();
        expect(
          platform.positions[player],
          greaterThan(const Duration(seconds: 30)),
        );

        await _showControl(tester, play);
        await tester.tap(play);
        await tester.pumpAndSettle();
        expect(platform.playing, isNot(contains(player)));
      }

      final filename = find.text('周报.pdf');
      await _showControl(tester, filename);
      await tester.tap(filename);
      await tester.pumpAndSettle();
      expect(opened, [('attachment', _attachment, '周报.pdf')]);
      expect(find.byTooltip('更多操作'), findsNothing);
      expect(state.selection, isNull);
      expect(jsonEncode(state.document.toJson()), before);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(platform.positions, isEmpty);
      expect(store.writes, writes);
      expect(tester.takeException(), isNull);
    });
  }
}

/// 将 [control] 移到 [tester] 的正文视口内，等待实际布局完成后再派发手势。
Future<void> _showControl(WidgetTester tester, Finder control) async {
  if (control.hitTestable().evaluate().isEmpty) {
    await Scrollable.ensureVisible(tester.element(control), alignment: .35);
    await tester.pumpAndSettle();
  }
  expect(
    control.hitTestable(),
    findsOneWidget,
    reason: '媒体控件应处于正文视口内（${tester.getRect(control)}）',
  );
}

/// 本地 PNG 图片，不依赖网络或设备资源。
const _image =
    'data:image/png;base64,'
    'iVBORw0KGgoAAAANSUhEUgAAACAAAAASCAIAAAC1qksFAAAAHklEQVR4nGNgaGCg'
    'LRq1YNSCUQtGLRi1YNQCelgAAGBcIBAjUUCjAAAAAElFTkSuQmCC';

/// 附件链接保留原始查询参数，验证宿主收到完整地址。
const _attachment = 'https://example.test/report.pdf?signature=abc';

/// 测试独占的文档存储，同时记录正文写入次数。
class _Store implements JournalStore {
  /// 构建包含图片和嵌套资源的已导入日记，经相同正文编解码和存储入口加载。
  _Store() {
    final base = JournalDraft.blank(DateTime(2026, 11, 18));
    final document = Document(
      root: pageNode(
        attributes: {journalDesktopImportAttribute: true},
        children: [
          Node(
            type: journalSectionType,
            attributes: {'section': 'record'},
            children: [
              paragraphNode(text: '媒体预览'),
              _block('image', 'block', {'src': _image}),
              _block('video', 'void', {
                'url': 'https://example.test/video.mp4',
              }),
              Node(
                type: 'callout',
                children: [
                  _block('audio', 'void', {
                    'url': 'https://example.test/audio.mp3',
                  }),
                  _block('attachment', 'void', {
                    'url': _attachment,
                    'name': '周报.pdf',
                  }),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    _draft = JournalDraft.fromJson({
      ...base.toJson(),
      'document': document.toJson(),
    });
    document.dispose();
  }

  /// 从 [flavour]、[nodeType] 和 [props] 构建测试媒体块，交给测试文档持有。
  Node _block(String flavour, String nodeType, Map<String, Object> props) =>
      BlockCraftJsonCodec.decodeBlock({
        'id': flavour,
        'flavour': flavour,
        'nodeType': nodeType,
        'props': props,
        'meta': <String, Object>{},
        'children': <Object>[],
      });

  /// 测试持有的持久化快照。
  late JournalDraft _draft;

  /// 实际保存次数。
  int writes = 0;

  /// 异步返回当前测试快照，不读取文件。
  @override
  Future<JournalDraft?> read() async => _draft;

  /// 保存 [draft] 并记录请求；测试快照无额外资源。
  @override
  Future<void> write(JournalDraft draft) async {
    writes++;
    _draft = draft;
  }
}

/// 只替换原生播放器，保留 Flutter 播放控制器和进度条真实逻辑。
class _MediaPlatform extends VideoPlayerPlatform {
  /// 当前存在的播放器进度，释放后移除。
  final positions = <int, Duration>{};

  /// 当前收到播放指令的播放器。
  final playing = <int>{};

  /// 每个 URL 最近创建的播放器身份，用于断言事件。
  final _players = <String, int>{};

  /// 手工分配独立身份，避免组件重挂载复用已关闭播放器。
  int _next = 0;

  /// 通过 [url] 查找最近创建的播放器。
  int playerFor(String url) => _players[url]!;

  /// 测试平台无全局资源需要初始化。
  @override
  Future<void> init() async {}

  /// 按 [options] 的网络地址分配播放器身份，异步模拟原生创建。
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = ++_next;
    _players[options.dataSource.uri!] = id;
    positions[id] = Duration.zero;
    return id;
  }

  /// 为 [playerId] 发出一次初始化成功事件，流由真实控制器订阅和取消。
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => Stream.value(
    VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 90),
      size: const Size(640, 360),
    ),
  );

  /// 用 [options] 模拟已创建的纹理视图，不接管控制器资源。
  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const SizedBox.expand();

  /// 模拟原生异步设置 [playerId] 的循环状态 [looping]。
  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  /// 模拟原生异步设置 [playerId] 的 [volume]。
  @override
  Future<void> setVolume(int playerId, double volume) async {}

  /// 模拟原生异步设置 [playerId] 的播放 [speed]。
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  /// 记录 [playerId] 开始播放。
  @override
  Future<void> play(int playerId) async => playing.add(playerId);

  /// 记录 [playerId] 暂停。
  @override
  Future<void> pause(int playerId) async => playing.remove(playerId);

  /// 记录 [playerId] 跳至指定 [position]。
  @override
  Future<void> seekTo(int playerId, Duration position) async {
    positions[playerId] = position;
  }

  /// 返回 [playerId] 的当前模拟位置，供真实控制器轮询。
  @override
  Future<Duration> getPosition(int playerId) async => positions[playerId]!;

  /// 异步释放 [playerId] 的模拟资源。
  @override
  Future<void> dispose(int playerId) async {
    positions.remove(playerId);
    playing.remove(playerId);
  }
}
