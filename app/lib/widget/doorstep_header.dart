import 'package:doorstep_app/config/doorstep_theme.dart';
import 'package:flutter/material.dart';

class DoorstepHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const DoorstepHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: DoorstepTheme.textMainOf(context),
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.0,
                  height: 1.1,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  color: DoorstepTheme.textMutedOf(context),
                  fontSize: 13.5,
                  height: 1.4,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 3,
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 16),
          Align(
            alignment: Alignment.topRight,
            child: trailing!,
          ),
        ],
      ],
    );
  }
}
