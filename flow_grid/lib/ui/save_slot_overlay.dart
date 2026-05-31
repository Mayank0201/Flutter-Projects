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
                    'RESUME EXPEDITION',
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
                      'BACK TO MISSION CONTROL',
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
      height: 100,
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEmpty ? null : () => widget.game.startGame(resume: true, slotIndex: index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // Slot Number
                Text(
                  '0${index + 1}',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w200,
                    color: Colors.white.withValues(alpha: isEmpty ? 0.2 : 0.6),
                  ),
                ),
                const SizedBox(width: 32),
                
                // Content
                Expanded(
                  child: isEmpty 
                    ? Text(
                        'VACANT STORAGE SLOT',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 4,
                          color: Colors.white.withValues(alpha: 0.15),
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
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'WEEK ${data['week']} • SCORE ${data['score']}',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Colors.blueAccent.withValues(alpha: 0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('yyyy-MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(data['saveTime'])),
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w300,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                ),
                
                if (!isEmpty)
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.white.withValues(alpha: 0.3)),
                    onPressed: () async {
                      await SaveManager.clearSave(slotIndex: index);
                      final activeSession = await SaveManager.getActiveSession();
                      if (activeSession != null && activeSession['slotIndex'] == index) {
                        await SaveManager.setActiveSession(index, false);
                      }
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
