import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/motion.dart';

/// Shows a themed floating snackbar. Errors get a red icon.
void showAppSnack(BuildContext context, String message, {bool error = false, SnackBarAction? action}) {
  final c = context.colors;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: AppMotion.snackbar,
        action: action,
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: error ? c.danger : c.success,
              size: AppSizes.iconMd,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}
