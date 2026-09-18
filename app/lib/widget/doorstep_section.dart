import 'package:doorstep_app/config/doorstep_theme.dart';
import 'package:doorstep_app/widget/doorstep_card.dart';
import 'package:flutter/material.dart';

/// A grouped settings/content section.
///
/// Follows the Android settings guidance: settings live in a **Material list**,
/// grouped into small relevant groups, with the group named by a heading
/// *above* the container rather than by containing every row individually.
class DoorstepSection extends StatelessWidget {
  final String title;

  /// Optional supporting line under the heading (e.g. the current value).
  final String? subtitle;

  final List<Widget> children;

  /// Optional trailing widget on the heading row (e.g. a refresh button).
  final Widget? action;

  final EdgeInsetsGeometry padding;

  const DoorstepSection({
    required this.title,
    required this.children,
    this.subtitle,
    this.action,
    this.padding = const EdgeInsets.only(bottom: 22),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(
          Divider(
            height: 1,
            thickness: 1,
            indent: 62,
            color: DoorstepTheme.borderOf(context).withValues(alpha: 0.6),
          ),
        );
      }
      rows.add(children[i]);
    }

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.toUpperCase(),
                        style: TextStyle(
                          color: DoorstepTheme.textMutedOf(context),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            color: DoorstepTheme.textMutedOf(context).withValues(alpha: 0.85),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ?action,
              ],
            ),
          ),
          DoorstepCard(
            padding: EdgeInsets.zero,
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }
}
