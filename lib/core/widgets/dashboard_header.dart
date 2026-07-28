import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The shared hero header used at the top of the student dashboard screens
/// (Active events, My events, Wallet, Profile).
///
/// It renders a big title — optionally two-tone, with [titleAccent] shown in
/// the brand accent colour — a supporting [subtitle], an optional [trailing]
/// action (e.g. a notification bell or logout button) pinned top-right, and a
/// [mascot] slot on the right. Until a real mascot asset is supplied, a soft
/// placeholder is shown; drop an `Image.asset(...)` into [mascot] to replace it.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    required this.title,
    required this.subtitle,
    this.titleAccent,
    this.trailing,
    this.mascot,
    super.key,
  });

  /// The leading (dark) part of the title, e.g. "Active".
  final String title;

  /// The accent-coloured trailing word of the title, e.g. "events". `null` for a
  /// single-tone title (Wallet, Profile).
  final String? titleAccent;

  /// The supporting line under the title.
  final String subtitle;

  /// An optional top-right action (notification bell, logout, …).
  final Widget? trailing;

  /// The mascot artwork slot; a placeholder is shown when `null`.
  final Widget? mascot;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[AppColors.accentSoft, Color(0x00EDEBFB)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    RichText(
                      text: TextSpan(
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: AppColors.textPrimary,
                          fontSize: 30,
                        ),
                        children: <InlineSpan>[
                          TextSpan(text: title),
                          if (titleAccent != null)
                            TextSpan(
                              text: ' $titleAccent',
                              style: const TextStyle(color: AppColors.accent),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  ?trailing,
                  const SizedBox(height: 4),
                  mascot ?? const _MascotPlaceholder(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A soft stand-in shown in the mascot slot until the real artwork is added.
class _MascotPlaceholder extends StatelessWidget {
  const _MascotPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      width: 76,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      child: const Text('👋', style: TextStyle(fontSize: 34)),
    );
  }
}

/// A small circular icon button (e.g. the header notification bell) styled to
/// sit on the header's light background.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    required this.icon,
    required this.onPressed,
    this.showDot = false,
    this.tooltip,
    super.key,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool showDot;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 2,
          shadowColor: const Color(0x14101828),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Icon(icon, size: 20, color: AppColors.textPrimary),
            ),
          ),
        ),
        if (showDot)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              height: 9,
              width: 9,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}
