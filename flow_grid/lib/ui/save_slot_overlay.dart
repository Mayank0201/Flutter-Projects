import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../game/flow_grid_game.dart';
import '../game/save_manager.dart';
import '../models/game_constants.dart';
import '../game/map_generator.dart';

class SaveSlotOverlay extends StatefulWidget {
  final FlowGridGame game;

  const SaveSlotOverlay({super.key, required this.game});

  @override
  State<SaveSlotOverlay> createState() => _SaveSlotOverlayState();
}

class _SaveSlotOverlayState extends State<SaveSlotOverlay> {
  final List<Map<String, dynamic>?> _slots = List.filled(3, null);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    for (int i = 0; i < 3; i++) {
      _slots[i] = await SaveManager.getSaveMetadata(i);
    }
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameConstants.backgroundColor.withValues(alpha: 0.95),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'SAVED GAMES',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.w200,
                      letterSpacing: 8,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                if (_loading)
                  const CircularProgressIndicator(color: Colors.white)
                else
                  ...List.generate(3, (index) => _buildSlotCard(index)),
                const SizedBox(height: 48),
                TextButton(
                  onPressed: () {
                    widget.game.overlays.remove('saveSlot');
                    widget.game.overlays.add('mainMenu');
                  },
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'BACK',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 2,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
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

  Widget _buildSlotCard(int index) {
    final data = _slots[index];
    final isEmpty = data == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      width: double.infinity,
      height: 96,
      decoration: BoxDecoration(
        color: const Color(0xFF10191C),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isEmpty
              ? const Color(0xFF1F2F33)
              : const Color(0xFFBF945C).withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: isEmpty ? null : () => widget.game.startGame(resume: true, slotIndex: index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // Status LED
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isEmpty ? const Color(0xFF223035) : const Color(0xFF5AC878),
                  ),
                ),
                const SizedBox(width: 16),
                // Slot Number
                Text(
                  'SLOT ${index + 1}',
                  style: GoogleFonts.shareTechMono(
                    fontSize: 14,
                    letterSpacing: 2,
                    color: Colors.white.withValues(alpha: isEmpty ? 0.2 : 0.6),
                  ),
                ),
                const SizedBox(width: 24),
                
                // Content
                Expanded(
                  child: isEmpty 
                    ? Text(
                        'EMPTY SLOT',
                        style: GoogleFonts.shareTechMono(
                          fontSize: 12,
                          letterSpacing: 2,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        overflow: TextOverflow.ellipsis,
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              MapType.values[data['mapType']].name.toUpperCase(),
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'WEEK ${data['week']}  ·  SCORE ${data['score']}',
                            style: GoogleFonts.shareTechMono(
                              fontSize: 11,
                              letterSpacing: 1,
                              color: const Color(0xFFE5A96A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('yyyy-MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(data['saveTime'])),
                            style: GoogleFonts.shareTechMono(
                              fontSize: 10,
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                ),
                
                if (!isEmpty)
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.white.withValues(alpha: 0.3), size: 20),
                    onPressed: () async {
                      await SaveManager.clearSave(slotIndex: index);
                      _loadSlots();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
