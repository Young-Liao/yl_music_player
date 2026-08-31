import 'package:flutter/material.dart';
import '../../../themes/theme_provider.dart';

class UploadingDialog extends StatelessWidget {
  final String title;
  final String message;

  const UploadingDialog({
    super.key,
    this.title = 'Uploading & Importing...',
    this.message = 'Please wait while files and folders are processed.',
  });

  /// Helper static method to easily show this non-dismissible dialog
  static Future<T> show<T>(BuildContext context, {Future<T> Function()? luego, String? title, String? message}) async {
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false, // Prevent users from clicking away
        builder: (BuildContext dialogContext) {
          return UploadingDialog(
            title: title ?? 'Uploading & Importing...',
            message: message ??
                'Please wait while files and folders are processed.',
          );
        },
      );
    }

    // If a task future is supplied, automatically pop the dialog when done
    try {
      final result = await luego?.call();
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      return result as T;
    } catch (e) {
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = CustomThemeProvider.of(context);

    return PopScope(
      canPop: false, // Blocks back-button dismissal during import
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 32.0,
                height: 32.0,
                child: CircularProgressIndicator(
                  strokeWidth: 3.0,
                  valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                ),
              ),
              const SizedBox(width: 24.0),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 13.0,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}