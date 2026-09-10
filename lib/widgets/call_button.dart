import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class CallButton extends StatelessWidget {
  const CallButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.enabled = true,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AppColors.primary;
    return Tooltip(
      message: tooltip,
      child: IconButton.filled(
        onPressed: enabled ? onPressed : null,
        style: IconButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: Colors.white,
          disabledBackgroundColor: bg.withValues(alpha: 0.35),
        ),
        icon: Icon(icon),
      ),
    );
  }
}
