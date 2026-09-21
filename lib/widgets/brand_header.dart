import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// En-tête de marque commun aux écrans principaux.
/// Le logo reste le seul titre visuel, comme dans une application automobile.
class BrandSliverHeader extends StatelessWidget {
  final String caption;

  const BrandSliverHeader({
    super.key,
    this.caption = 'ANALYSE AUTOMOBILE  •  ALLEMAGNE → FRANCE',
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SliverAppBar(
      expandedHeight: 178,
      collapsedHeight: 72,
      toolbarHeight: 72,
      floating: true,
      pinned: true,
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: context.appColors.surface,
      title: _LogoMark(compact: true),
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final progress = ((constraints.maxHeight - 72) / 106)
              .clamp(0.0, 1.0)
              .toDouble();
          return ClipRect(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: dark
                      ? const [Color(0xFF080B10), Color(0xFF101A29)]
                      : const [Color(0xFFE0E4E7), Color(0xFFF4F0E8)],
                ),
                border: Border(
                  bottom: BorderSide(color: context.appColors.cardBorder),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -70,
                    top: -105,
                    child: _GlowDisc(
                      size: 250,
                      color: context.appColors.accent,
                      opacity: dark ? .17 : .10,
                    ),
                  ),
                  Positioned(
                    left: -90,
                    bottom: -165,
                    child: _GlowDisc(
                      size: 280,
                      color: context.appColors.accentOrange,
                      opacity: dark ? .09 : .07,
                    ),
                  ),
                  Positioned(
                    right: 20,
                    bottom: 30,
                    child: Opacity(
                      opacity: progress,
                      child: Transform.rotate(
                        angle: -.10,
                        child: Container(
                          width: 92,
                          height: 3,
                          decoration: BoxDecoration(
                            color: context.appColors.accentOrange,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 22,
                    child: Opacity(
                      opacity: progress,
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 2,
                            color: context.appColors.accent,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                color: context.appColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  final bool compact;

  const _LogoMark({required this.compact});

  @override
  Widget build(BuildContext context) {
    final size = compact ? 58.0 : 82.0;
    return Semantics(
      label: 'EuroCar Margin',
      child: SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          'assets/logo2.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, _, _) => Icon(
            Icons.speed_rounded,
            size: compact ? 30 : 42,
            color: context.appColors.accent,
          ),
        ),
      ),
    );
  }
}

class _GlowDisc extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _GlowDisc({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: opacity), Colors.transparent],
        ),
      ),
    );
  }
}

/// Valeur sûre pour les menus déroulants : le texte ne peut jamais pousser la
/// flèche hors du champ, même avec une région ou une finition très longue.
Widget compactDropdownText(
  BuildContext context,
  String value, {
  FontStyle? fontStyle,
}) {
  return Align(
    alignment: Alignment.centerLeft,
    child: Text(
      value,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: context.appColors.textPrimary,
        fontSize: 14,
        fontStyle: fontStyle,
      ),
    ),
  );
}
