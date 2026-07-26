import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../screens/trails_screen.dart';

class TrailUnlockToast {
  static final List<Map<String, String>> _queue = [];
  static bool _isShowing = false;
  static OverlayEntry? _currentEntry;

  static void show(BuildContext context, String name, String emoji, String styleId) {
    _queue.add({'name': name, 'emoji': emoji, 'styleId': styleId});
    _checkQueue(context);
  }

  static void _checkQueue(BuildContext context) {
    if (_isShowing || _queue.isEmpty) return;

    _isShowing = true;
    final trail = _queue.removeAt(0);

    final overlayState = Navigator.of(context).overlay;
    if (overlayState == null) {
      _isShowing = false;
      return;
    }
    
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _TrailUnlockToastWidget(
        name: trail['name']!,
        emoji: trail['emoji']!,
        styleId: trail['styleId']!,
        onDismiss: () {
          try {
            overlayEntry.remove();
          } catch (_) {}
          if (_currentEntry == overlayEntry) {
            _currentEntry = null;
          }
          _isShowing = false;
          Future.delayed(const Duration(milliseconds: 150), () {
            if (context.mounted) {
              _checkQueue(context);
            }
          });
        },
      ),
    );

    _currentEntry = overlayEntry;
    overlayState.insert(overlayEntry);
  }
}

class _TrailUnlockToastWidget extends StatefulWidget {
  final String name;
  final String emoji;
  final String styleId;
  final VoidCallback onDismiss;

  const _TrailUnlockToastWidget({
    required this.name,
    required this.emoji,
    required this.styleId,
    required this.onDismiss,
  });

  @override
  State<_TrailUnlockToastWidget> createState() => _TrailUnlockToastWidgetState();
}

class _TrailUnlockToastWidgetState extends State<_TrailUnlockToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppTheme.zenCurve,
    ));

    _controller.forward();

    // Auto dismiss after 2.2 seconds (matches achievement toast)
    _dismissTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Positioned(
      top: 50,
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Align(
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () {
              _dismissTimer?.cancel();
              widget.onDismiss();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TrailsScreen(highlightId: widget.styleId),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  constraints: const BoxConstraints(maxWidth: 400),
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF252320) : Colors.white).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12,
                      width: 0.5,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.softSage.withAlpha(30),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            widget.emoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Swipe Trail Unlocked!',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.softSage,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.name} is now available.',
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'Tap to view ',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.softSage,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 10,
                                    color: AppTheme.softSage,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
