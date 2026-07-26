import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/achievement_manager.dart';
import '../theme/app_theme.dart';
import '../screens/achievements_screen.dart';

class AchievementToast {
  static final List<Achievement> _queue = [];
  static bool _isShowing = false;
  static OverlayEntry? _currentEntry;

  static void show(BuildContext context, Achievement achievement) {
    _queue.add(achievement);
    _checkQueue(context);
  }

  static void _checkQueue(BuildContext context) {
    if (_isShowing || _queue.isEmpty) return;

    _isShowing = true;
    final achievement = _queue.removeAt(0);

    final overlayState = Navigator.of(context).overlay!;
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _AchievementToastWidget(
        achievement: achievement,
        onDismiss: () {
          overlayEntry.remove();
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

class _AchievementToastWidget extends StatefulWidget {
  final Achievement achievement;
  final VoidCallback onDismiss;

  const _AchievementToastWidget({
    required this.achievement,
    required this.onDismiss,
  });

  @override
  State<_AchievementToastWidget> createState() => _AchievementToastWidgetState();
}

class _AchievementToastWidgetState extends State<_AchievementToastWidget>
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

    // Auto dismiss after 2.7 seconds
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
                  builder: (_) => AchievementsScreen(highlightId: widget.achievement.id),
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
                            color: AppTheme.dustyMauve.withAlpha(30),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            widget.achievement.icon,
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
                                'Achievement Unlocked!',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.dustyMauve,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.achievement.name,
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                widget.achievement.description,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: context.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'Tap to claim ',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.dustyMauve,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 10,
                                    color: AppTheme.dustyMauve,
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
