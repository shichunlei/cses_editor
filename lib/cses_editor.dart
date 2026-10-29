/// 通用内存编辑器与宿主扩展契约，不包含协同引擎。
library;

export 'src/editor/core/document_editor_controller.dart';
export 'src/editor/core/editor_command_context.dart' show EditorCommandContext;
export 'src/editor/core/editor_view_configuration.dart';
export 'src/editor/core/editor_configuration.dart'
    show
        EditorConfiguration,
        EditorBlock,
        EditorInlineFormat,
        EditorKeyboardToolbarItem;
export 'src/editor/document_editor_view.dart';
export 'src/editor/blockcraft_json_codec.dart' show BlockCraftJsonCodec;
export 'src/editor/blockcraft_snapshot_view.dart'
    show blockCraftSnapshotBuilders, blockCraftSnapshotRootStyle;
export 'src/editor/editor_text_presentation.dart';
export 'src/editor/document_editor_commands.dart'
    show handleDocumentParagraphEnter, applyDocumentBlockShortcut;
export 'src/editor/editor_interaction_shell.dart' show EditorInteractionShell;
export 'src/editor/editor_user_mentions.dart'
    show
        EditorUserMention,
        decorateEditorUserMention,
        showEditorUserMention,
        pickEditorMentionUser,
        handleEditorUserMentionTrigger;
export 'src/editor/local_editor_controller.dart' show LocalEditorController;
export 'src/model/collab_block_lock.dart'
    show CollabBlockLockState, CollabBlockUnlockContext;
export 'src/model/collab_document_feedback.dart';
export 'src/model/collab_host_services.dart';
export 'src/model/collab_kr.dart'
    show CollabKrItem, CollabKrTopic, CollabKrService;
export 'src/model/collab_meeting_card_data.dart'
    show CollabMeetingCardState, CollabMeetingCardData, CollabMeetingCardLoader;
export 'src/model/collab_meeting_reference.dart';
export 'src/model/collab_mention_tap.dart'
    show CollabMentionType, CollabMentionTap, CollabMentionTapCallback;
export 'src/model/collab_mention_ui.dart'
    show CollabMentionAvatarBuilder, CollabMentionUserPicker;
export 'src/model/collab_task_card_data.dart'
    show
        CollabTaskCardData,
        CollabTaskCardTag,
        CollabTaskCardPath,
        CollabTaskCardLoader;
export 'src/model/collab_user_mention.dart'
    show CollabMentionUser, CollabMentionDirectory;
export 'src/model/document_metadata.dart';
export 'src/model/editor_media_upload.dart';
export 'src/model/editor_keyboard_action.dart' show EditorKeyboardAction;
export 'src/model/collab_weather.dart'
    show CollabWeatherData, CollabWeatherLoader;
export 'src/model/collab_person_card.dart' show CollabPersonCardData;
