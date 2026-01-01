import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';

class SuccessAnimationDialog extends StatefulWidget {
  final String animationPath;
  final String message;
  final String subMessage;
  final VoidCallback? onDismissed;
  final bool autoDismiss;

  const SuccessAnimationDialog({
    Key? key,
    required this.animationPath,
    required this.message,
    this.subMessage = '',
    this.onDismissed,
    this.autoDismiss = true,
  }) : super(key: key);

  @override
  State<SuccessAnimationDialog> createState() => _SuccessAnimationDialogState();
}

class _SuccessAnimationDialogState extends State<SuccessAnimationDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    
    // Auto dismiss after animation completion + delay if enabled
    if (widget.autoDismiss) {
      _controller.addStatusListener((status) async {
        if (status == AnimationStatus.completed) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            Navigator.of(context).pop();
            widget.onDismissed?.call();
          }
        }
      });

      // Valid safety fallback
      // If animation doesn't load or complete within 4 seconds, force dismiss
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted && _controller.status != AnimationStatus.completed) {
          Navigator.of(context).pop();
          widget.onDismissed?.call();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 180,
              width: 180,
              child: Lottie.asset(
                widget.animationPath,
                controller: _controller,
                onLoaded: (composition) {
                  _controller
                    ..duration = composition.duration
                    ..forward();
                },
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Lottie Animation Error: $error');
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline, 
                        color: Colors.red,
                        size: 60,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Error loading animation:\n$error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10, color: Colors.red),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.message,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF374151),
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.subMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                widget.subMessage,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (!widget.autoDismiss) ...[
               const SizedBox(height: 24),
               ElevatedButton(
                 onPressed: () {
                   Navigator.of(context).pop();
                   widget.onDismissed?.call();
                 },
                 style: ElevatedButton.styleFrom(
                   backgroundColor: const Color(0xFF10B981), // Green color
                   shape: RoundedRectangleBorder(
                     borderRadius: BorderRadius.circular(12),
                   ),
                   padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                 ),
                 child: Text(
                   'Done',
                   style: GoogleFonts.poppins(
                     color: Colors.white,
                     fontWeight: FontWeight.w600,
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
