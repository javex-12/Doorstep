import 'package:doorstep_app/config/doorstep_theme.dart';
import 'package:flutter/material.dart';

/// A single row in a [DoorstepSection] list.
///
/// Structure follows the Android settings guide: an icon that clarifies
/// meaning, a primary label, optional supporting text carrying the current
/// state, and the control on the right. The whole row is tappable when
/// [onTap] is set, and the control sits inside the tap target so there is
/// no dead zone.
class DoorstepListTile extends StatelessWidget {
  final IconData icon;

  /// Overrides the icon badge tint (defaults to the brand primary).
  final Color? iconColor;

  final String title;

  /// Supporting text. Prefer showing the *current state* here
  /// (e.g. "On", "Downloads/Doorstep", "4 devices").
  final String? subtitle;

  /// The control / value shown on the right (switch, chevron, chip, text).
  final Widget? trailing;

  /// When [trailing] is a switch this is called instead of [onTap].
  final VoidCallback? onTap;

  final bool enabled;

  /// Denser row used for pickers nested inside a page.
  final bool dense;

  const DoorstepListTile({
    required this.icon,
    required this.title,
    this.iconColor,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.dense = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tint = iconColor ?? DoorstepTheme.primaryOf(context);
    final textMain = DoorstepTheme.textMainOf(context);
    final textMuted = DoorstepTheme.textMutedOf(context);

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: dense ? 10 : 14),
          child: Row(
            children: [
              Container(
                width: dense ? 30 : 34,
                height: dense ? 30 : 34,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: dense ? 17 : 19, color: tint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textMain,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(color: textMuted, fontSize: 12.5, height: 1.35),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Chevron used as a row's trailing widget to signal "opens a screen".
class DoorstepChevron extends StatelessWidget {
  const DoorstepChevron({super.key});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.chevron_right_rounded,
      size: 22,
      color: DoorstepTheme.textMutedOf(context).withValues(alpha: 0.8),
    );
  }
}

/// Right-aligned non-interactive value text for a row.
class DoorstepTrailingText extends StatelessWidget {
  final String text;

  const DoorstepTrailingText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 150),
      child: Text(
        text,
        textAlign: TextAlign.right,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: DoorstepTheme.textMutedOf(context),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
