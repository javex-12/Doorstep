import 'package:doorstep_app/config/doorstep_theme.dart';
import 'package:flutter/material.dart';

/// The five empty-state kinds worth designing for.
enum DoorstepEmptyKind {
  /// Nothing has been set up yet (first run).
  firstUse,

  /// A search / discovery returned nothing *yet*.
  searching,

  /// There is genuinely no data (e.g. empty history).
  noData,

  /// The user must do something before this works.
  actionNeeded,

  /// Something went wrong.
  errorState,
}

/// A complete empty state: **visual, title, explanation, and exactly one
/// action**. Renders an illustration-style icon badge so the state is obvious
/// before the text is read, and always offers a way forward rather than
/// dead-ending the user.
class DoorstepEmptyState extends StatelessWidget {
  final DoorstepEmptyKind kind;
  final IconData icon;
  final String title;
  final String message;

  /// The single primary action. Keep to one where possible.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Optional secondary (text-only) escape hatch, e.g. "Connect manually".
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Renders compactly inside an existing card instead of as a standalone block.
  final bool inline;

  const DoorstepEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.kind = DoorstepEmptyKind.noData,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.inline = false,
    super.key,
  });

  ({Color color, IconData badgeIcon}) _tone(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (kind) {
      case DoorstepEmptyKind.firstUse:
        return (color: isDark ? DoorstepTheme.primary : const Color(0xFF0F60FF), badgeIcon: icon);
      case DoorstepEmptyKind.searching:
        return (color: isDark ? DoorstepTheme.accent : const Color(0xFF006874), badgeIcon: icon);
      case DoorstepEmptyKind.noData:
        return (color: isDark ? DoorstepTheme.textMuted : const Color(0xFF64748B), badgeIcon: icon);
      case DoorstepEmptyKind.actionNeeded:
        return (color: isDark ? DoorstepTheme.warning : const Color(0xFFA16207), badgeIcon: icon);
      case DoorstepEmptyKind.errorState:
        return (color: isDark ? DoorstepTheme.danger : const Color(0xFFB91C1C), badgeIcon: icon);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = _tone(context);
    final textMain = DoorstepTheme.textMainOf(context);
    final textMuted = DoorstepTheme.textMutedOf(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: inline ? 20 : 28, vertical: inline ? 22 : 34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: inline ? 56 : 74,
            height: inline ? 56 : 74,
            decoration: BoxDecoration(
              color: tone.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: tone.color.withValues(alpha: 0.22), width: 1),
            ),
            child: Icon(tone.badgeIcon, size: inline ? 26 : 34, color: tone.color),
          ),
          SizedBox(height: inline ? 14 : 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textMain,
              fontSize: inline ? 15.5 : 17,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: textMuted, fontSize: 13, height: 1.5),
          ),
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: inline ? 16 : 20),
            SizedBox(
              width: inline ? null : double.infinity,
              child: FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ),
          ],
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: onSecondary,
              style: TextButton.styleFrom(foregroundColor: DoorstepTheme.textMutedOf(context)),
              child: Text(secondaryLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
