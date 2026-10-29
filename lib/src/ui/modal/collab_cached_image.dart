import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'collab_image_cache.dart';

/// 正文图片、封面与图标共用的HTTP(S)文件缓存渲染；调用方验证来源并持有业务状态。
/// 图片缓存在App私有目录，支持重启后离线读取，不使用数据库。
/// 位图和SVG复用单次下载；换源或销毁后旧请求不会覆盖当前图片。
///
/// ```dart
/// import 'package:cses_editor/src/ui/modal/collab_cached_image.dart';
/// import 'package:flutter/widgets.dart';
/// const image = CollabCachedImage(
///   url: 'https://example.com/cover.png',
///   loading: SizedBox.shrink(),
///   failure: Text('图片加载失败'),
/// );
/// ```
class CollabCachedImage extends StatelessWidget {
  /// [key]控制组件身份；[url]为已验证的HTTP(S)完整地址，包含缓存键使用的查询参数。
  /// [loading]和[failure]是借用的加载/失败占位，亦用于SVG解析过程。
  /// [fit]默认contain；[alignment]默认居中，控制位图与SVG相同的裁切位置。
  /// [width]和[height]为逻辑像素，null跟随父约束；[semanticsLabel]为可选图片说明。
  const CollabCachedImage({
    super.key,
    required this.url,
    required this.loading,
    required this.failure,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.semanticsLabel,
  });

  /// 必填网络地址；完整字符串用作缓存和异步视图身份。
  final String url;

  /// 必填加载占位；不由本组件释放。
  final Widget loading;

  /// 必填失败占位；无效图片、下载错误及SVG解析失败均使用它。
  final Widget failure;

  /// 画面适配方式，默认contain；封面可指定cover。
  final BoxFit fit;

  /// 画面裁切位置，默认居中。
  final Alignment alignment;

  /// 可选宽度，单位逻辑像素；null使用父约束。
  final double? width;

  /// 可选高度，单位逻辑像素；null使用父约束。
  final double? height;

  /// 可选的辅助功能图片说明。
  final String? semanticsLabel;

  /// 借用[context]构建按源隔离的缓存视图；SVG保持原始颜色。
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      image: true,
      child: _CachedSvgImage(key: ValueKey(url), image: this),
    );
  }
}

/// 保留一次下载Future；换源通过身份与FutureBuilder隔离迟到结果。
class _CachedSvgImage extends StatefulWidget {
  /// [key]控制请求身份；[image]为借用的源和布局参数。
  const _CachedSvgImage({super.key, required this.image});

  /// 借用的源、布局与占位配置，不持有业务对象。
  final CollabCachedImage image;

  /// 创建只持有本地读取Future的状态，不获取全局资源所有权。
  @override
  createState() => _CachedSvgImageState();
}

/// 拥有本视图下载客户端和图片字节，组件退出关闭客户端。
class _CachedSvgImageState extends State<_CachedSvgImage> {
  /// 当前视图拥有的HTTP客户端，销毁时关闭并取消未完成请求。
  final _client = http.Client();

  /// 当前读取Future；其字节仅由此视图保留。
  late Future<Uint8List?> _request;

  /// 启动首次读取，FutureBuilder处理失败结果。
  @override
  void initState() {
    super.initState();
    _request = _read();
  }

  /// [oldWidget]的图片地址变化时替换Future，布局变化无需重新下载。
  @override
  void didUpdateWidget(covariant _CachedSvgImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image.url != widget.image.url) {
      _request = _read();
    }
  }

  /// 读取App独立文件缓存或下载图片；失败由FutureBuilder展示占位。
  Future<Uint8List?> _read() async {
    return CollabImageCache().load(widget.image.url, _client);
  }

  /// 关闭本视图拥有的客户端，阻止未完成请求继续占用连接。
  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  /// 借用[context]渲染当前请求，保留适配/对齐/尺寸并使用调用方占位。
  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: _request,
    builder: (context, snapshot) {
      final image = widget.image;
      if (snapshot.connectionState != ConnectionState.done) {
        return image.loading;
      }
      if (snapshot.hasError || snapshot.data == null) return image.failure;
      if (!_looksLikeSvg(snapshot.data!)) {
        return Image.memory(
          snapshot.data!,
          fit: image.fit,
          alignment: image.alignment,
          width: image.width,
          height: image.height,
          errorBuilder: (_, _, _) => image.failure,
        );
      }
      return SvgPicture.memory(
        snapshot.data!,
        fit: image.fit,
        alignment: image.alignment,
        width: image.width,
        height: image.height,
        placeholderBuilder: (_) => image.loading,
        errorBuilder: (_, _, _) => image.failure,
      );
    },
  );
}

/// 只检查[bytes]的前4096字节，识别XML头、BOM和命名空间前缀后的SVG根元素。
bool _looksLikeSvg(Uint8List bytes) => RegExp(
  r'<(?:[A-Za-z_][\w.-]*:)?svg(?:\s|>)',
).hasMatch(utf8.decode(bytes.take(4096).toList(), allowMalformed: true));
