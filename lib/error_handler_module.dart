import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'dart:async';

class ErrorHandler {
  // Display error with retry option
  static void showErrorDialog({
    required BuildContext context,
    required String title,
    required String message,
    VoidCallback? onRetry,
    VoidCallback? onCancel,
    bool barrierDismissible = true,
  }) {
    showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red[700],
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          actions: [
            if (onCancel != null)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onCancel();
                },
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            if (onRetry != null)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onRetry();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  'Retry',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              )
            else
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  'OK',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // Display network error with retry
  static void showNetworkError({
    required BuildContext context,
    required VoidCallback onRetry,
    VoidCallback? onCancel,
  }) {
    showErrorDialog(
      context: context,
      title: 'Network Error',
      message: 'Unable to connect to the server. Please check your internet connection and try again.',
      onRetry: onRetry,
      onCancel: onCancel,
    );
  }

  // Display timeout error
  static void showTimeoutError({
    required BuildContext context,
    required VoidCallback onRetry,
    VoidCallback? onCancel,
  }) {
    showErrorDialog(
      context: context,
      title: 'Request Timeout',
      message: 'The request took too long to complete. Please try again.',
      onRetry: onRetry,
      onCancel: onCancel,
    );
  }

  // Display permission error
  static void showPermissionError({
    required BuildContext context,
    required String message,
    VoidCallback? onRetry,
  }) {
    showErrorDialog(
      context: context,
      title: 'Permission Denied',
      message: message,
      onRetry: onRetry,
    );
  }

  // Display Firebase error
  static void showFirebaseError({
    required BuildContext context,
    required String operation,
    required dynamic error,
    VoidCallback? onRetry,
  }) {
    String message = _parseFirebaseError(error);
    showErrorDialog(
      context: context,
      title: 'Operation Failed',
      message: 'Failed to $operation: $message',
      onRetry: onRetry,
    );
  }

  // Parse Firebase error to user-friendly message
  static String _parseFirebaseError(dynamic error) {
    String errorMessage = error.toString().toLowerCase();

    if (errorMessage.contains('network')) {
      return 'Network connection issue. Please check your internet.';
    } else if (errorMessage.contains('permission') || errorMessage.contains('denied')) {
      return 'Permission denied. Please check Firebase Database rules or contact support.';
    } else if (errorMessage.contains('not found')) {
      return 'The requested data was not found.';
    } else if (errorMessage.contains('timeout')) {
      return 'Request timed out. Please try again.';
    } else if (errorMessage.contains('auth')) {
      return 'Authentication error. Please log in again.';
    } else {
      // Return the actual error message for debugging
      return 'An unexpected error occurred: ${error.toString()}';
    }
  }

  // Show error snackbar
  static void showErrorSnackBar({
    required BuildContext context,
    required String message,
    VoidCallback? onRetry,
    Duration duration = const Duration(seconds: 4),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[700],
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  // Show success snackbar
  static void showSuccessSnackBar({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[700],
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  // Wrap async operation with error handling
  static Future<T?> handleAsyncOperation<T>({
    required BuildContext context,
    required Future<T> Function() operation,
    required String operationName,
    VoidCallback? onRetry,
    bool showLoadingDialog = false,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (showLoadingDialog) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Please wait...',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    try {
      final result = await operation().timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException('Operation timed out');
        },
      );
      
      if (showLoadingDialog && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      return result;
    } on SocketException catch (e) {
      if (showLoadingDialog && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      if (context.mounted) {
        showNetworkError(
          context: context,
          onRetry: onRetry ?? () => handleAsyncOperation(
            context: context,
            operation: operation,
            operationName: operationName,
            onRetry: onRetry,
            showLoadingDialog: showLoadingDialog,
            timeout: timeout,
          ),
        );
      }
      return null;
    } on TimeoutException catch (e) {
      if (showLoadingDialog && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      if (context.mounted) {
        showTimeoutError(
          context: context,
          onRetry: onRetry ?? () => handleAsyncOperation(
            context: context,
            operation: operation,
            operationName: operationName,
            onRetry: onRetry,
            showLoadingDialog: showLoadingDialog,
            timeout: timeout,
          ),
        );
      }
      return null;
    } catch (e) {
      if (showLoadingDialog && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      if (context.mounted) {
        showFirebaseError(
          context: context,
          operation: operationName,
          error: e,
          onRetry: onRetry ?? () => handleAsyncOperation(
            context: context,
            operation: operation,
            operationName: operationName,
            onRetry: onRetry,
            showLoadingDialog: showLoadingDialog,
            timeout: timeout,
          ),
        );
      }
      return null;
    }
  }

  // Show error state widget
  static Widget buildErrorWidget({
    required String message,
    VoidCallback? onRetry,
    IconData icon = Icons.error_outline,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: Text(
                  'Try Again',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Show network error widget
  static Widget buildNetworkErrorWidget({
    required VoidCallback onRetry,
  }) {
    return buildErrorWidget(
      message: 'No internet connection.\nPlease check your network settings.',
      icon: Icons.wifi_off,
      onRetry: onRetry,
    );
  }

  // Show empty state widget
  static Widget buildEmptyWidget({
    required String message,
    IconData icon = Icons.inbox_outlined,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  actionLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
