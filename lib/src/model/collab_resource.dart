import 'dart:convert';

import 'package:applowy_editor_fork/applowy_editor_fork.dart';

const collabResourceTypes = {
  'attachment',
  'audio',
  'bookmark',
  'embed',
  'juejin-embed',
  'figma-embed',
};
const collabResourceAttribute = 'cses_resource';
const collabResourceTargetAttribute = 'cses_resource_target';
const collabResourceKindAttribute = 'cses_resource_kind';
const collabResourceKeys = {
  'name',
  'type',
  'size',
  'icon',
  'sourceType',
  'title',
  'description',
  'image',
  'poster',
  'wr',
  'ar',
  'width',
  'height',
};
String resourcePropertyAttribute(String key) => 'cses_resource_$key';

bool isCollabResourceType(String type) => collabResourceTypes.contains(type);

bool isCollabResourceUrl(String kind, String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !{'http', 'https'}.contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      value.length > 8192 ||
      value.contains(RegExp(r'\s'))) {
    return false;
  }
  if (kind == 'figma-embed') {
    return {'figma.com', 'www.figma.com', 'embed.figma.com'}.contains(uri.host);
  }
  if (kind == 'juejin-embed') {
    return {'juejin.cn', 'www.juejin.cn'}.contains(uri.host);
  }
  return true;
}

/// Returns the normalized extension and file family for [name] and [mime].
/// Used by attachment cards and protocol serialization; performs no I/O.
(String, String) attachmentFileType(String name, String mime) {
  final dot = name.lastIndexOf('.');
  final extension = dot > 0 && dot < name.length - 1
      ? name.substring(dot + 1).toLowerCase()
      : '';
  final normalizedMime = mime.split(';').first.trim().toLowerCase();
  final kind = switch (extension) {
    'pdf' => 'pdf',
    'doc' || 'docx' || 'odt' || 'rtf' => 'document',
    'xls' || 'xlsx' || 'csv' || 'ods' => 'spreadsheet',
    'ppt' || 'pptx' || 'odp' => 'presentation',
    'zip' || 'rar' || '7z' || 'tar' || 'gz' => 'archive',
    'png' || 'jpg' || 'jpeg' || 'gif' || 'webp' || 'svg' || 'heic' => 'image',
    'mp3' || 'wav' || 'm4a' || 'aac' || 'ogg' || 'flac' => 'audio',
    'mp4' || 'mov' || 'mkv' || 'avi' || 'webm' => 'video',
    'txt' || 'md' || 'json' || 'xml' || 'log' => 'text',
    _ => switch (normalizedMime) {
      'application/pdf' => 'pdf',
      'application/msword' ||
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document' =>
        'document',
      'application/vnd.ms-excel' ||
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' =>
        'spreadsheet',
      'application/vnd.ms-powerpoint' ||
      'application/vnd.openxmlformats-officedocument.presentationml.presentation' =>
        'presentation',
      'application/zip' ||
      'application/x-zip-compressed' ||
      'application/x-rar-compressed' ||
      'application/x-7z-compressed' => 'archive',
      _ when normalizedMime.startsWith('image/') => 'image',
      _ when normalizedMime.startsWith('audio/') => 'audio',
      _ when normalizedMime.startsWith('video/') => 'video',
      _ when normalizedMime.startsWith('text/') => 'text',
      _ => 'file',
    },
  };
  return (extension, kind);
}

/// Returns the BlockCraft attachment icon for [name] and MIME type [mime].
/// Unknown files use the protocol's generic icon.
String attachmentProtocolIcon(String name, String mime) =>
    'bc_file-${switch (attachmentFileType(name, mime).$2) {
      'document' => 'doc',
      'spreadsheet' => 'xlsx',
      'presentation' => 'ppt',
      'archive' => 'zip',
      'image' => 'img',
      'audio' => 'mp3',
      'text' => 'txt',
      'pdf' => 'pdf',
      'video' => 'video',
      _ => 'unknown',
    }}';

/// Whitelisted display props plus an explicit, field-only mutation intent.
final class CollabResource {
  const CollabResource({this.properties = '{}', this.propertyEdits});
  final String properties;
  final String? propertyEdits;
  Map<String, dynamic> get values =>
      Map<String, dynamic>.from(jsonDecode(properties) as Map);
  String string(String key) =>
      values[key] is String ? values[key] as String : '';
  double? number(String key) =>
      values[key] is num ? (values[key] as num).toDouble() : null;
  factory CollabResource.fromValues(
    Map<String, dynamic> values, {
    String? edits,
  }) => CollabResource(
    properties: jsonEncode({
      for (final key in values.keys.toList()..sort()) key: values[key],
    }),
    propertyEdits: edits,
  );
  factory CollabResource.fromJson(Map<String, dynamic> values) =>
      CollabResource(properties: values['properties'] as String? ?? '{}');
  Map<String, dynamic> toJson() => {'properties': properties};
  String field(String key) =>
      jsonEncode(values.containsKey(key) ? {'value': values[key]} : {});
  Map<String, dynamic> get nodeAttributes => {
    collabResourceAttribute: toJson(),
    for (final key in collabResourceKeys)
      resourcePropertyAttribute(key): field(key),
  };
  factory CollabResource.fromAttributes(
    Map<String, dynamic> attributes, {
    Set<String> edited = const {},
  }) {
    final base = attributes[collabResourceAttribute];
    final resource = base is Map
        ? CollabResource.fromJson(Map<String, dynamic>.from(base))
        : const CollabResource();
    final values = resource.values;
    final edits = <String, dynamic>{};
    for (final key in collabResourceKeys) {
      final field = attributes[resourcePropertyAttribute(key)];
      if (field is! String) continue;
      final wrapper = jsonDecode(field) as Map;
      if (wrapper.containsKey('value')) {
        values[key] = wrapper['value'];
      } else {
        values.remove(key);
      }
      if (edited.contains(key)) edits[key] = wrapper;
    }
    if (edited.contains('url')) edits['url'] = {'value': attributes['url']};
    return CollabResource.fromValues(
      values,
      edits: edits.isEmpty ? null : jsonEncode(edits),
    );
  }
  @override
  bool operator ==(Object other) =>
      other is CollabResource &&
      other.properties == properties &&
      other.propertyEdits == propertyEdits;
  @override
  int get hashCode => Object.hash(properties, propertyEdits);
}

/// Edits one property, preserving other fields and resolving undo by stable identity.
Future<bool> changeCollabResourceProperty(
  EditorState state,
  String id,
  String property,
  Object? value,
) async {
  if (state.isDisposed ||
      !state.editable ||
      (property != 'url' && !collabResourceKeys.contains(property))) {
    return false;
  }
  Node? visit(Node node) {
    if ((node.attributes['cses_collab_block_id'] ?? node.id) == id &&
        isCollabResourceType(node.type)) {
      return node;
    }
    for (final child in node.children) {
      final found = visit(child);
      if (found != null) return found;
    }
    return null;
  }

  final node = visit(state.document.root);
  if (node == null) return false;
  if (property == 'url' &&
      (value is! String || !isCollabResourceUrl(node.type, value))) {
    return false;
  }
  final key = property == 'url' ? 'url' : resourcePropertyAttribute(property);
  final next = property == 'url'
      ? value
      : jsonEncode(value == null ? {} : {'value': value});
  if (node.attributes[key] == next) return false;
  if (state.undoManager.undoStack.isNonEmpty) {
    state.undoManager.undoStack.last.seal();
  }
  await state.apply(
    state.transaction..add(
      UpdateOperation(
        node.path,
        {
          key: next,
          collabResourceTargetAttribute: id,
          collabResourceKindAttribute: node.type,
        },
        {
          key: node.attributes[key],
          collabResourceTargetAttribute: id,
          collabResourceKindAttribute: node.type,
        },
      ),
    ),
    withUpdateSelection: false,
    skipHistoryDebounce: true,
  );
  return true;
}
