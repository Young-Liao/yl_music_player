import 'package:flutter/material.dart';

class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool showLabel;
  final VoidCallback onPressed;
  final dynamic theme;

  const ActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.showLabel = true,
    required this.onPressed,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (!showLabel) {
      return Container(
        height: 42,
        width: 42,
        decoration: BoxDecoration(
          border: Border.all(color: theme.textMuted.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: IconButton(
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(icon, size: 16.0, color: theme.textPrimary),
        ),
      );
    }

    return SizedBox(
      height: 42,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 14.0, color: theme.textPrimary),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 13.0,
            fontWeight: FontWeight.w600,
            color: theme.textPrimary,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: theme.textMuted.withValues(alpha: 0.2)),
          padding: const EdgeInsets.symmetric(horizontal: 14.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
      ),
    );
  }
}