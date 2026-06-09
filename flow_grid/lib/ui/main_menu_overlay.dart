import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/flow_grid_game.dart';
import '../game/save_manager.dart';
import '../models/game_constants.dart';

class MainMenuOverlay extends StatefulWidget {
  final FlowGridGame game;

  const MainMenuOverlay({super.key, required this.game});

  @override
  State<MainMenuOverlay> createState() => _MainMenuOverlayState();
}

class _MainMenuOverlayState extends State<MainMenuOverlay> {
  bool _hasSave = false;

  @override
  void initState() {
    super.initState();
    SaveManager.hasSaveGame().then((value) {
      if (mounted) {
        setState(() {
          _hasSave = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameConstants.backgroundColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Minimalist Title
                Text(
                  'FLOW GRID',
                  style: GoogleFonts.outfit(
                    fontSize: 64, // Reduced slightly for landscape
                    fontWeight: FontWeight.w200,
                    letterSpacing: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'SIMULATION ENGINE',
                  style: GoogleFonts.outfit(
                    fontSize: 12, // Reduced slightly
                    fontWeight: FontWeight.w400,
                    letterSpacing: 4,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 40), // Reduced from 80 for landscape
                
                if (_hasSave) ...[
                  _menuButton(
                    label: 'RESUME CITY',
                    onPressed: () {
                      widget.game.overlays.remove('mainMenu');
                      widget.game.overlays.add('saveSlot');
                    },
                    primary: true,
                  ),
                  const SizedBox(height: 16),
                ],
                
                _menuButton(
                  label: _hasSave ? 'NEW EXPEDITION' : 'START SIMULATION',
                  onPressed: () {
                    widget.game.overlays.remove('mainMenu');
                    widget.game.overlays.add('mapSelection');
                  },
                  primary: !_hasSave,
                ),
                const SizedBox(height: 16),
                _menuButton(
                  label: 'LEARN TO FLOW',
                  onPressed: () {
                    widget.game.overlays.remove('mainMenu');
                    widget.game.overlays.add('tutorial');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuButton({
    required String label,
    required VoidCallback onPressed,
    bool primary = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: Colors.white.withValues(alpha: primary ? 0.8 : 0.2),
            width: 1,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
          backgroundColor: primary ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            letterSpacing: 4,
            color: Colors.white.withValues(alpha: primary ? 0.9 : 0.5),
          ),
        ),
      ),
    );
  }
}
