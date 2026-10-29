import 'package:cses_editor/cses_editor.dart';
import 'package:flutter_test/flutter_test.dart';

/// 验证多个纯内存会话的服务、历史与关闭互不影响。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'services and documents stay isolated without a global runtime',
    () async {
      const firstServices = CollabHostServices(createId: _firstId);
      const secondServices = CollabHostServices(createId: _secondId);
      final first = LocalEditorController(
        initialText: '第一份',
        services: firstServices,
      );
      final second = LocalEditorController(
        initialText: '第二份',
        services: secondServices,
      );
      try {
        expect(identical(first.commandContext.services, firstServices), isTrue);
        expect(
          identical(second.commandContext.services, secondServices),
          isTrue,
        );
        await first.close();
        expect(second.closed, isFalse);
        expect(
          second.editorState.document.root.children.single.delta!.toPlainText(),
          '第二份',
        );
        expect(second.commandContext.services.createId!(), 'second');
      } finally {
        await first.close();
        await second.close();
      }
    },
  );

  test('replacing the picker preserves borrowed business ports', () {
    const original = CollabHostServices(createId: _firstId);
    final adapted = original.withMentionUserPicker(
      (context, {required keyword, required canEdit}) async => null,
    );
    expect(adapted.createId!(), 'first');
    expect(original.pickMentionUser, isNull);
    expect(adapted.pickMentionUser, isNotNull);
  });
}

/// 返回第一会话的虚构业务身份，不持有资源。
String _firstId() => 'first';

/// 返回第二会话的虚构业务身份，不持有资源。
String _secondId() => 'second';
