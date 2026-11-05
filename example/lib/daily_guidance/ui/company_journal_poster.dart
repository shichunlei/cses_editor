import 'package:cses_offline_example/daily_guidance/ui/ctfs_v2_poster.dart';
import 'package:cses_offline_example/daily_guidance/ui/hfys_v2_poster.dart';
import 'package:cses_offline_example/daily_guidance/ui/zqyl_poster.dart';
import 'package:flutter/material.dart';

/// 公司海报的本地展示样式，编辑、预览与分享共用。
///
/// ```dart
/// CompanyJournalPoster.ctfsV2.header(date: '2026-11-05');
/// ```
enum CompanyJournalPoster {
  /// 汇丰永盛倾斜相框与撕纸。
  hfysV2(
    HfysV2Poster.canvas,
    HfysV2Poster.paper,
    HfysV2Poster.ink,
    HfysV2Poster.paperInset,
    'hfys-v2',
  ),

  /// 成塔服饰暖橙圆顶与白卡。
  ctfsV2(
    CtfsV2Poster.canvas,
    CtfsV2Poster.paper,
    CtfsV2Poster.ink,
    CtfsV2Poster.paperInset,
    'ctfs-v2',
  ),

  /// 中企云链品牌绿与不对称白卡。
  zqyl(
    ZqylPoster.canvas,
    Colors.white,
    Color(0xff333333),
    ZqylPoster.paperInset,
    'zqyl',
  );

  /// [canvas] 是画布底色，[paper] 是正文卡底色，[ink] 是正文色。
  /// [paperInset] 是卡片水平边距，[id] 用于宿主的本地分区。
  const CompanyJournalPoster(
    this.canvas,
    this.paper,
    this.ink,
    this.paperInset,
    this.id,
  );

  /// 海报底色。
  final Color canvas;

  /// 正文卡颜色。
  final Color paper;

  /// 正文文字色。
  final Color ink;

  /// 正文卡水平边距。
  final double paperInset;

  /// 稳定模板标识。
  final String id;

  /// 生成共享封面。[date] 是文档日期，[author] 由宿主注入。
  /// [now] 和 [avatar] 用于时段问候及作者头像。
  Widget header({
    required String date,
    String? author,
    DateTime? now,
    Widget? avatar,
  }) {
    final openedAt = now ?? DateTime.now();
    final recordDate = DateTime.tryParse(date) ?? openedAt;
    final minutes = openedAt.hour * 60 + openedAt.minute;
    final (greeting, english) = switch (minutes) {
      < 180 || >= 1110 => ('晚安', 'GOOD NIGHT'),
      < 510 => ('早安', 'GOOD MORNING'),
      < 690 => ('上午好', 'GOOD MORNING'),
      < 810 => ('午安', 'GOOD NOON'),
      _ => ('下午好', 'GOOD AFTERNOON'),
    };
    return switch (this) {
      hfysV2 => HfysV2Poster.header(
        date: recordDate,
        greeting: greeting,
        author: author,
        avatar: avatar,
      ),
      ctfsV2 => CtfsV2Poster.header(
        date: recordDate,
        greeting: greeting,
        english: english,
        author: author,
        avatar: avatar,
      ),
      zqyl => ZqylPoster.header(
        date: date,
        now: openedAt,
        author: author,
        avatar: avatar,
      ),
    };
  }

  /// 构建正文卡收边和铺满画布宽度的离线品牌图。
  /// [showLogo] 仅在预览与分享时绘制品牌图。
  Widget footer({required bool showLogo}) {
    if (this == hfysV2) return HfysV2Poster.footer(showLogo: showLogo);
    if (this == zqyl) return ZqylPoster.footer(showLogo: showLogo);
    return Column(
      key: const ValueKey('ctfs-v2-footer'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: paperInset),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: paper,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(48),
              ),
            ),
            child: const SizedBox(height: 28),
          ),
        ),
        if (showLogo)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: AspectRatio(
              aspectRatio: 758 / 150,
              child: Image(
                key: ValueKey('journal-company-logo'),
                image: AssetImage('assets/images/chengtafushi_logo.webp'),
                fit: BoxFit.fitWidth,
                semanticLabel: '成塔服饰',
              ),
            ),
          ),
      ],
    );
  }
}
