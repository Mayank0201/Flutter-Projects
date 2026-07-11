import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/game_info.dart';
import '../utils/point_manager.dart';
import '../utils/hint_manager.dart';
import '../utils/ad_manager.dart';

class BuyHintsDialog extends StatefulWidget {
  final String initialGameId;
  final VoidCallback? onPurchaseComplete;
  final bool isFromGameScreen;

  const BuyHintsDialog({
    super.key,
    required this.initialGameId,
    this.onPurchaseComplete,
    this.isFromGameScreen = false,
  });

  static Future<void> show(
    BuildContext context, {
    required String initialGameId,
    VoidCallback? onPurchaseComplete,
    bool isFromGameScreen = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: BuyHintsDialog(
          initialGameId: initialGameId,
          onPurchaseComplete: onPurchaseComplete,
          isFromGameScreen: isFromGameScreen,
        ),
      ),
    );
  }

  @override
  State<BuyHintsDialog> createState() => _BuyHintsDialogState();
}

class _BuyHintsDialogState extends State<BuyHintsDialog> {
  late String _selectedGameId;
  int _hintQuantity = 1;
  int _pointBalance = 0;
  bool _loading = true;
  bool _adWatching = false;
  late TextEditingController _qtyController;

  @override
  void initState() {
    super.initState();
    _selectedGameId = widget.initialGameId;
    _qtyController = TextEditingController(text: '$_hintQuantity');
    _loadBalance();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    final balance = await PointManager.getPoints();
    if (mounted) {
      setState(() {
        _pointBalance = balance;
        _loading = false;
      });
    }
  }

  Future<void> _buyHints() async {
    if (_hintQuantity < 1) return;
    final cost = _hintQuantity * 100;
    if (_pointBalance < cost) return;

    setState(() {
      _loading = true;
    });

    final success = await PointManager.consumePoints(cost);
    if (success) {
      await HintManager.addHints(_selectedGameId, _hintQuantity);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully purchased $_hintQuantity Hint(s)!',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppTheme.softSage,
          ),
        );
        Navigator.pop(context);
        widget.onPurchaseComplete?.call();
      }
    } else {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _watchAd() {
    if (_adWatching) return;
    setState(() {
      _adWatching = true;
    });

    AdManager.showRewardedAd(
      onRewardGranted: (amount) async {
        await PointManager.addPoints(80);
        await _loadBalance();
        if (mounted) {
          setState(() {
            _adWatching = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '+80 IQ Points awarded!',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              backgroundColor: AppTheme.softSage,
            ),
          );
        }
      },
      onAdNotReady: () {
        if (mounted) {
          setState(() {
            _adWatching = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Ad is not ready yet. Please try again in a moment.',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cost = _hintQuantity * 100;
    final canAfford = _pointBalance >= cost;
    final availableGames = kAllGames.where((g) => !g.isStashed).toList();

    // In case initialGameId is stashed or invalid, fallback to first active game
    if (!availableGames.any((g) => g.id == _selectedGameId)) {
      if (availableGames.isNotEmpty) {
        _selectedGameId = availableGames.first.id;
      }
    }

    final currentGameName = availableGames.firstWhere((g) => g.id == _selectedGameId, orElse: () => availableGames.first).name;

    return Container(
      decoration: BoxDecoration(
        color: context.bgDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: _loading
          ? const SizedBox(
              height: 250,
              child: Center(child: CircularProgressIndicator(color: AppTheme.dustyMauve)),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.textMuted.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title and balance
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Buy Hints',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.warmAmber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.warmAmber.withOpacity(0.2), width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.psychology, color: AppTheme.warmAmber, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            '$_pointBalance IQ',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.warmAmber,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '1 Hint = 100 IQ Points. Select game and quantity below.',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // Dropdown/Static selector
                Text(
                  widget.isFromGameScreen ? 'Exercise' : 'Select Exercise',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: context.bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.textMuted.withOpacity(0.15)),
                  ),
                  child: widget.isFromGameScreen
                      ? Text(
                          currentGameName,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                        )
                      : DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedGameId,
                            dropdownColor: context.bgCard,
                            icon: Icon(Icons.keyboard_arrow_down_rounded, color: context.textSecondary),
                            isExpanded: true,
                            items: availableGames.map((game) {
                              return DropdownMenuItem<String>(
                                value: game.id,
                                child: Text(
                                  game.name,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    color: context.textPrimary,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedGameId = val;
                                });
                              }
                            },
                          ),
                        ),
                ),
                const SizedBox(height: 20),

                // Quantity selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Quantity',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                    Row(
                      children: [
                        _buildQtyButton(
                          icon: Icons.remove_rounded,
                          onPressed: _hintQuantity > 1
                              ? () {
                                  setState(() {
                                    _hintQuantity--;
                                    _qtyController.text = '$_hintQuantity';
                                  });
                                }
                              : null,
                        ),
                        SizedBox(
                          width: 60,
                          child: TextField(
                            controller: _qtyController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 4),
                              border: InputBorder.none,
                            ),
                            onChanged: (val) {
                              final parsed = int.tryParse(val);
                              if (parsed != null && parsed >= 1) {
                                setState(() {
                                  _hintQuantity = parsed;
                                });
                              }
                            },
                            onSubmitted: (val) {
                              final parsed = int.tryParse(val);
                              if (parsed == null || parsed < 1) {
                                _qtyController.text = '$_hintQuantity';
                              }
                            },
                          ),
                        ),
                        _buildQtyButton(
                          icon: Icons.add_rounded,
                          onPressed: () {
                            setState(() {
                              _hintQuantity++;
                              _qtyController.text = '$_hintQuantity';
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            final maxQty = _pointBalance ~/ 100;
                            setState(() {
                              _hintQuantity = maxQty > 0 ? maxQty : 1;
                              _qtyController.text = '$_hintQuantity';
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.accentFor(_selectedGameId).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.accentFor(_selectedGameId).withOpacity(0.3),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              'MAX',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.accentFor(_selectedGameId),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Divider line
                Container(
                  height: 0.5,
                  color: context.textMuted.withOpacity(0.2),
                ),
                const SizedBox(height: 20),

                // Purchase Actions
                Row(
                  children: [
                    // Ad Watch Shortcut
                    Expanded(
                      flex: 4,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: AppTheme.dustyMauve.withOpacity(0.4)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _adWatching ? null : _watchAd,
                        icon: _adWatching
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.dustyMauve),
                              )
                            : const Icon(Icons.ondemand_video_rounded, color: AppTheme.dustyMauve, size: 18),
                        label: Text(
                          'Watch Ad\n(+80 IQ)',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: AppTheme.dustyMauve,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Cost purchase button
                    Expanded(
                      flex: 6,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canAfford ? AppTheme.softSage : context.bgSurface,
                          foregroundColor: canAfford ? Colors.white : context.textMuted,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: canAfford ? _buyHints : null,
                        child: Text(
                          canAfford ? 'Buy for $cost IQ' : 'Need $cost IQ',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: canAfford ? Colors.white : context.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildQtyButton({required IconData icon, VoidCallback? onPressed}) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: context.bgCard,
        shape: BoxShape.circle,
        border: Border.all(
          color: context.textMuted.withOpacity(onPressed != null ? 0.25 : 0.1),
        ),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 20),
        color: onPressed != null ? context.textPrimary : context.textMuted.withOpacity(0.3),
        onPressed: onPressed,
      ),
    );
  }
}
