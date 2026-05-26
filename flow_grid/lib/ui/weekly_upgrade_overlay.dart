import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/flow_grid_game.dart';

class WeeklyUpgradeOverlay extends StatefulWidget {
  final FlowGridGame game;
  const WeeklyUpgradeOverlay({super.key, required this.game});

  @override
  State<WeeklyUpgradeOverlay> createState() => _WeeklyUpgradeOverlayState();
}

class _WeeklyUpgradeOverlayState extends State<WeeklyUpgradeOverlay>
    with TickerProviderStateMixin {
  // ── Gamble state ──────────────────────────────────────────────────────────
  bool _gambleRolling = false;
  bool _gambleRevealed = false;
  String? _gambleResult;

  late AnimationController _spinCtrl;
  late AnimationController _revealCtrl;
  late Animation<double> _revealScale;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat();
    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _revealScale = CurvedAnimation(parent: _revealCtrl, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _revealCtrl.dispose();
    super.dispose();
  }

  void _onGambleTap() {
    if (_gambleRolling || _gambleRevealed) return;
    setState(() => _gambleRolling = true);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      final result = widget.game.rollGamble();
      setState(() {
        _gambleRolling = false;
        _gambleRevealed = true;
        _gambleResult = result;
      });
      _spinCtrl.stop();
      _revealCtrl.forward();
    });
  }

  void _onClaimGamble() => widget.game.applyUpgrade('gamble_${_gambleResult!}');

  // ── Gamble result metadata ────────────────────────────────────────────────
  Color _resultColor() {
    switch (_gambleResult) {
      case 'jackpot':  return const Color(0xFFFFD700);
      case 'bigwin':   return const Color(0xFF69F0AE);
      case 'win':      return const Color(0xFF64B5F6);
      case 'bust':     return const Color(0xFFFFB74D);
      case 'disaster': return const Color(0xFFEF5350);
      default:         return Colors.white;
    }
  }

  String _resultEmoji() {
    switch (_gambleResult) {
      case 'jackpot':  return '🎰';
      case 'bigwin':   return '🎉';
      case 'win':      return '✅';
      case 'bust':     return '💨';
      case 'disaster': return '💀';
      default:         return '?';
    }
  }

  String _resultTitle() {
    switch (_gambleResult) {
      case 'jackpot':  return 'JACKPOT!';
      case 'bigwin':   return 'BIG WIN!';
      case 'win':      return 'WIN';
      case 'bust':     return 'BUST';
      case 'disaster': return 'DISASTER';
      default:         return '?';
    }
  }

  String _resultDesc() {
    final b = widget.game.weeklyBaseRoads;
    switch (_gambleResult) {
      case 'jackpot':  return '+50 ROADS  ·  +1 TUNNEL  ·  +1 EXPRESS LANE';
      case 'bigwin':   return '+${b + 15} ROADS  ·  +1 SMART JUNCTION';
      case 'win':      return '+$b ROADS  ·  +1 TRAFFIC LIGHT';
      case 'bust':     return '+5 ROADS ONLY';
      case 'disaster': return '-10 ROADS  ·  +1 EXPRESS LANE (consolation)';
      default:         return '';
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final base = game.weeklyBaseRoads;

    return Material(
      color: Colors.transparent,
      child: Container(
        color: Colors.black87,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header ─────────────────────────────────────────────
                  Text(
                    'WEEK ${game.week}',
                    style: GoogleFonts.outfit(
                      color: Colors.white30,
                      fontSize: 12,
                      letterSpacing: 4,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'CHOOSE YOUR REWARD',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'roads scale with week  ·  $base base roads this week',
                    style: GoogleFonts.outfit(
                      color: Colors.white24,
                      fontSize: 10,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Cards ──────────────────────────────────────────────
                  ...game.weeklyOptions.map((opt) {
                    if (opt == 'gamble') return _buildGambleCard();
                    return _buildRewardCard(opt, base);
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Normal reward card ────────────────────────────────────────────────────
  Widget _buildRewardCard(String opt, int base) {
    late String title, sub;
    late IconData icon;
    late Color color;

    switch (opt) {
      case 'tunnels':
        title = '+$base ROADS  +  1 TUNNEL';
        sub   = 'cross mountains without a gap';
        icon  = Icons.terrain;
        color = const Color(0xFF78909C);
      case 'bridges':
        title = '+$base ROADS  +  1 BRIDGE';
        sub   = 'span rivers in a single move';
        icon  = Icons.waves;
        color = const Color(0xFF4DD0E1);
      case 'trafficLights':
        title = '+$base ROADS  +  1 TRAFFIC LIGHT';
        sub   = 'regulate high-load intersections';
        icon  = Icons.traffic;
        color = const Color(0xFF66BB6A);
      case 'smartJunction':
        title = '+$base ROADS  +  1 SMART JUNCTION';
        sub   = 'auto-balances multi-way crossings';
        icon  = Icons.hub;
        color = const Color(0xFFAB47BC);
      case 'expressLane':
        title = '+${(base * 0.6).round()} ROADS  +  1 EXPRESS LANE';
        sub   = 'double-speed corridor, fewer roads';
        icon  = Icons.bolt;
        color = const Color(0xFFFFCA28);
      default: // doubleRoads
        title = '+${base + 10} ROADS';
        sub   = 'pure pavement, no tools';
        icon  = Icons.add_road;
        color = const Color(0xFF42A5F5);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => widget.game.applyUpgrade(opt),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none)),
                    Text(sub,
                        style: GoogleFonts.outfit(
                            color: Colors.white38,
                            fontSize: 10,
                            decoration: TextDecoration.none)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: color.withValues(alpha: 0.45), size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ── Gamble card (pre-reveal) ──────────────────────────────────────────────
  Widget _buildGambleCard() {
    if (_gambleRevealed && _gambleResult != null) return _buildRevealCard();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: _gambleRolling ? null : _onGambleTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2A1F00), Color(0xFF130F00)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _gambleRolling
                  ? Colors.amber.withValues(alpha: 0.9)
                  : const Color(0xFFFFD700).withValues(alpha: 0.55),
              width: _gambleRolling ? 2.0 : 1.5,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 40, height: 40,
                child: _gambleRolling
                    ? AnimatedBuilder(
                        animation: _spinCtrl,
                        builder: (context2, child2) => Transform.rotate(
                          angle: _spinCtrl.value * 2 * pi,
                          child: const Icon(Icons.casino, color: Colors.amber, size: 28),
                        ),
                      )
                    : const Icon(Icons.casino,
                        color: Color(0xFFFFD700), size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _gambleRolling ? 'ROLLING...' : '??? GAMBLE',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFFFD700),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    Text(
                      _gambleRolling
                          ? 'fate is deciding your future...'
                          : 'jackpot or disaster — do you dare?',
                      style: GoogleFonts.outfit(
                        color: Colors.amber.withValues(alpha: 0.5),
                        fontSize: 10,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_gambleRolling)
                Icon(Icons.chevron_right_rounded,
                    color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                    size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ── Gamble card (post-reveal) ─────────────────────────────────────────────
  Widget _buildRevealCard() {
    final col   = _resultColor();
    final emoji = _resultEmoji();
    final title = _resultTitle();
    final desc  = _resultDesc();

    return ScaleTransition(
      scale: _revealScale,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GestureDetector(
          onTap: _onClaimGamble,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                col.withValues(alpha: 0.18),
                col.withValues(alpha: 0.05),
              ]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: col.withValues(alpha: 0.75), width: 2),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(emoji,
                        style: const TextStyle(
                            fontSize: 28, decoration: TextDecoration.none)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: GoogleFonts.outfit(
                                  color: col,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.none)),
                          const SizedBox(height: 2),
                          Text(desc,
                              style: GoogleFonts.outfit(
                                  color: col.withValues(alpha: 0.7),
                                  fontSize: 10,
                                  decoration: TextDecoration.none)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: col.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: col.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'TAP TO COLLECT',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: col,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
