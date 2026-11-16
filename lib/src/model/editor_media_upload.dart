import 'package:cses_editor/src/model/collab_image.dart';
import 'package:cses_editor/src/model/collab_resource.dart';
import 'package:dio/dio.dart';

/// Stable media reference and optional metadata supplied by the upload host.
///
/// ```dart
/// import 'package:cses_editor/cses_editor.dart';
/// const media = EditorMediaSource('https://example.com/asset.png', aspectRatio: 2);
/// ```
class EditorMediaSource {
  /// [url] is the stable HTTP(S) address. [file] is borrowed metadata from a
  /// successful local upload. [aspectRatio] is source width divided by height;
  /// [poster] is a stable video preview URL. Missing values remain unspecified.
  const EditorMediaSource(this.url, {this.file, this.aspectRatio, this.poster});

  /// Stable remote address written to the media block.
  final String url;

  /// Local upload selection. Only its file metadata can enter the document.
  final EditorLocalFile? file;

  /// Intrinsic width divided by height, for images or video when available.
  final double? aspectRatio;

  /// Preview image URL for video when provided by the upload host.
  final String? poster;
}

/// Builds transaction attributes for the validated [source] of a media [kind].
/// Borrowed [previous] attributes are used only on replacement, to keep
/// layout choices and image captions while refreshing source metadata.
/// A missing source field clears the old value. This does not read or upload files.
Map<String, dynamic> editorMediaSourceAttributes(
  String kind,
  EditorMediaSource source, {
  Map<String, dynamic>? previous,
}) {
  final file = source.file;
  final ratio = source.aspectRatio;
  final aspectRatio = ratio != null && ratio.isFinite && ratio > 0
      ? ratio
      : null;
  final attributes = <String, dynamic>{'url': source.url};
  if (kind == 'image') {
    final old = previous?[collabImageAttribute];
    final image = old is Map
        ? CollabImage.fromJson(Map<String, dynamic>.from(old))
        : const CollabImage();
    return attributes
      ..[collabImageAttribute] = CollabImage(
        widthRatio: image.widthRatio ?? (image.width == null ? 100 : null),
        aspectRatio: aspectRatio,
        width: image.width,
        rotation: image.rotation,
        captions: image.captions,
      ).toJson();
  }
  final name = file?.name ?? Uri.parse(source.url).pathSegments.lastOrNull;
  final poster = source.poster;
  final values = switch (kind) {
    'video' => <String, Object?>{
      'name': file?.name,
      'type': file?.mimeType ?? '',
      'size': file?.size,
      'sourceType': file == null ? 'link' : 'local',
      'poster': poster != null && isCollabResourceUrl('image', poster)
          ? poster
          : null,
      'ar': aspectRatio,
      if (previous == null) 'wr': 100,
    },
    'audio' => <String, Object?>{
      'name': file?.name,
      'size': file?.size,
      'sourceType': file == null ? 'link' : 'local',
    },
    'attachment' => <String, Object?>{
      'name': name == null || name.isEmpty ? '附件' : name,
      'type': file?.mimeType ?? '',
      'size': file?.size,
      'icon': attachmentProtocolIcon(name ?? '', file?.mimeType ?? ''),
    },
    _ => const <String, Object?>{},
  };
  final resource = CollabResource.fromValues({
    for (final entry in values.entries)
      if (entry.value != null) entry.key: entry.value,
  });
  return attributes..addAll({
    for (final key in values.keys)
      resourcePropertyAttribute(key): resource.field(key),
    if (kind == 'video' && previous != null)
      resourcePropertyAttribute('height'): resource.field('height'),
  });
}

/// Local selection metadata stays in the sheet until upload succeeds.
class EditorLocalFile {
  const EditorLocalFile({
    required this.path,
    required this.name,
    required this.size,
    required this.mimeType,
  });
  final String path;
  final String name;
  final int size;
  final String mimeType;
}

/// 返回资源 [kind] 是否支持本地文件上传；仅判断类型，实际入口还需宿主注入服务。
bool editorMediaSupportsUpload(String kind) => {
  'image',
  'video',
  'audio',
  'attachment',
  'document_banner',
  'document_icon',
}.contains(kind);

/// 返回资源 [kind] 的字节上限：图片/封面/图标60MiB、音频50MiB，其他100MiB。
int editorMediaMaxBytes(String kind) => switch (kind) {
  'image' || 'document_banner' || 'document_icon' => 60 * 1024 * 1024,
  'audio' => 50 * 1024 * 1024,
  _ => 100 * 1024 * 1024,
};

/// Validate before requesting upload credentials or reading the selected file.
/// 校验借用的 [file] 是否满足资源 [kind] 的路径、大小与MIME要求；通过返回null，否则返回提示。
/// 不读取磁盘或上传；SVG仅图标允许，实际文件是否变化由宿主上传端口再次核对。
String? validateEditorMediaFile(String kind, EditorLocalFile file) {
  if (!editorMediaSupportsUpload(kind)) return '此内容仅支持通过链接添加';
  if (file.size <= 0) return '请选择非空文件';
  if (file.size > editorMediaMaxBytes(kind)) {
    return '文件过大，不能超过 ${editorMediaMaxBytes(kind) ~/ (1024 * 1024)} MB';
  }
  final valid = switch (kind) {
    'image' || 'document_banner' || 'document_icon' => {
      'image/png',
      'image/jpeg',
      'image/gif',
      'image/webp',
      if (kind == 'document_icon') 'image/svg+xml',
    }.contains(file.mimeType),
    'video' => file.mimeType.startsWith('video/'),
    'audio' => file.mimeType.startsWith('audio/'),
    _ => true,
  };
  return valid ? null : '所选文件格式不支持，请重新选择';
}

/// Injectable boundary for the native picker and authenticated CSES upload.
abstract class EditorMediaUploadService {
  Future<EditorLocalFile?> pickFile(String kind);
  Future<EditorMediaSource> upload(
    EditorLocalFile file,
    String kind, {
    required CancelToken cancelToken,
    required void Function(double progress) onProgress,
  });
}
