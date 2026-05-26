import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/flow_grid_game.dart';
import '../models/traffic_phase.dart';
import '../models/city_event.dart';
import '../game/map_generator.dart';
import 'analytics_panel.dart';
import '../game/emergency_manager.dart';


class GameHudOverlay extends StatefulWidget {
  final FlowGridGame game;
  const GameHudOverlay({super.key, required this.game});

  @override
  State<GameHudOverlay> createState() => _GameHudOverlayState();
}

class _GameHudOverlayState extends State<GameHudOverlay> {
  bool showAnalytics = false;
  bool showInfoPanel = false;

  @override
  void initState() {
    super.initState();
    widget.game.onStateChanged = () {
      if (mounted) setState(() {});
    };
  }

  FlowGridGame get g => widget.game;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: GoogleFonts.outfit(decoration: TextDecoration.none),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: SafeArea(
              child: RepaintBoundary(
                child: SizedBox(
                  width: g.hudPanelWidth,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14161B).withValues(alpha: 0.85),
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _topSection(),
                                _previewSection(),
                                _toolGrid(),
                                _actionSection(),
                                _speedSection(),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (showAnalytics)
            Center(
              child: AnalyticsPanel(
                game: g,
                onClose: () => setState(() => showAnalytics = false),
              ),
            ),
          if (showInfoPanel)
            _infoPanel(),
        ],
      ),
    );
  }

  bool _shouldShowTool(BuildTool tool) {
    final map = g.selectedMapType;
    switch (tool) {
      case BuildTool.bridge:
        // Show bridge for water-crossing maps
        return map == MapType.nile ||
               map == MapType.delta ||
               map == MapType.arctic;
      case BuildTool.tunnel:
        // Show tunnel for mountain-crossing maps
        return map == MapType.zen ||
               map == MapType.andes ||
               map == MapType.arctic ||
               map == MapType.savanna;
      default:
        return true;
    }
  }

  Widget _topSection() {
    final map = g.selectedMapType;
    String mapLabel = map.name.toUpperCase();
    String mapDesc = '';
    Color themeColor = Colors.blueAccent;
    IconData mapIcon = Icons.map;

    switch (map) {
      case MapType.zen:
        mapDesc = 'BALANCED CLIMATE';
        themeColor = Colors.lightGreenAccent;
        mapIcon = Icons.eco;
        break;
      case MapType.andes:
        mapDesc = 'TERRACOTTA CANYONS';
        themeColor = Colors.orangeAccent;
        mapIcon = Icons.terrain;
        break;
      case MapType.nile:
        mapDesc = 'RIVER BASIN & DOMES';
        themeColor = Colors.amberAccent;
        mapIcon = Icons.water;
        break;
      case MapType.arctic:
        mapDesc = 'ICE ROADS & BLIZZARDS';
        themeColor = Colors.cyanAccent;
        mapIcon = Icons.ac_unit;
        break;
      case MapType.savanna:
        mapDesc = 'GAZELLES & DUST STORMS';
        themeColor = Colors.yellowAccent;
        mapIcon = Icons.wb_sunny;
        break;
      case MapType.delta:
        mapDesc = 'FLOODS & DRAWBRIDGES';
        themeColor = Colors.tealAccent;
        mapIcon = Icons.waves;
        break;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(mapIcon, size: 14, color: themeColor),
              const SizedBox(width: 6),
              Text(
                mapLabel,
                style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            mapDesc,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: themeColor.withValues(alpha: 0.8),
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          _divider(),
          const SizedBox(height: 12),
          ValueListenableBuilder<int>(
            valueListenable: g.weekNotifier,
            builder: (context, week, _) => _miniStat('WEEK $week', Colors.white),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: ValueListenableBuilder<double>(
              valueListenable: g.weekProgressNotifier,
              builder: (context, progress, _) => LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white10,
                color: Colors.blueAccent,
                minHeight: 3,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _trafficPhaseIndicator(),
          const SizedBox(height: 16),
          _divider(),
          const SizedBox(height: 12),
          ValueListenableBuilder<int>(
            valueListenable: g.scoreNotifier,
            builder: (context, score, _) => _animatedStat('$score', Colors.amber),
          ),
          _miniLabel('SCORE'),
          ValueListenableBuilder<double>(
            valueListenable: g.satisfactionNotifier,
            builder: (context, sat, _) => Column(
              children: [
                _animatedStat('${(sat * 100).toInt()}%', 
                    sat < 0.4 ? Colors.redAccent : Colors.lightGreenAccent),
                _miniLabel('SATISFACTION'),
              ],
            ),
          ),
          if (g.eventManager.activeEvents.isNotEmpty || g.emergencyManager.activeEvents.isNotEmpty || g.activeEvent != null) ...[
            const SizedBox(height: 8),
            _divider(),
            const SizedBox(height: 4),
            ...g.eventManager.activeEvents.map((e) => _eventNotification(e)),
            ...g.emergencyManager.activeEvents.map((e) => _emergencyNotification(e)),
            if (g.activeEvent != null) _mapEventNotification(g),
          ]
        ],
      ),
    );
  }

  Widget _toolGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        children: [
          _miniLabel('BUILD TOOLS'),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 0.92,
            children: [
              if (_shouldShowTool(BuildTool.road))
                _toolButton(
                  tool: BuildTool.road,
                  icon: Icons.add_road,
                  label: 'ROAD',
                  notifier: g.roadInventoryNotifier,
                ),
              if (_shouldShowTool(BuildTool.tunnel))
                _toolButton(
                  tool: BuildTool.tunnel,
                  icon: Icons.terrain,
                  label: 'TUNNEL',
                  notifier: g.tunnelInventoryNotifier,
                ),
              if (_shouldShowTool(BuildTool.bridge))
                _toolButton(
                  tool: BuildTool.bridge,
                  icon: Icons.water,
                  label: 'BRIDGE',
                  notifier: g.bridgeInventoryNotifier,
                ),
              if (_shouldShowTool(BuildTool.trafficLight))
                _toolButton(
                  tool: BuildTool.trafficLight, 
                  icon: Icons.traffic, 
                  label: 'SIGNAL', 
                  notifier: g.trafficLightInventoryNotifier,
                ),
              if (_shouldShowTool(BuildTool.smartJunction))
                _toolButton(
                  tool: BuildTool.smartJunction, 
                  icon: Icons.sync, 
                  label: 'SMART', 
                  notifier: g.smartJunctionInventoryNotifier,
                ),
              if (_shouldShowTool(BuildTool.expressLane))
                _toolButton(
                  tool: BuildTool.expressLane, 
                  icon: Icons.flight_takeoff, 
                  label: 'EXPRESS', 
                  notifier: g.expressLaneInventoryNotifier,
                ),
              _toolButton(tool: BuildTool.erase, icon: Icons.auto_fix_normal, label: 'ERASE'),
              _toolButton(
                tool: BuildTool.inspect, 
                icon: Icons.info_outline, 
                label: 'INFO',
                onTapOverride: () => setState(() {
                  g.paused = true;
                  showInfoPanel = true;
                }),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: g.canUndoNotifier,
                builder: (context, canUndo, _) {
                  return _toolButton(
                    tool: BuildTool.inspect,
                    icon: Icons.undo,
                    label: 'UNDO',
                    isSelectedOverride: false,
                    isDisabled: !canUndo,
                    onTapOverride: () {
                      g.undo();
                    },
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      child: Column(
        children: [
          _divider(),
          const SizedBox(height: 12),
          _miniLabel('MISSION'),
          const SizedBox(height: 8),
          Row(
            children: [
              _actionBtn(Icons.save_outlined, 'SAVE', Colors.white70, () {
                g.saveGame();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('State Cached')),
                );
              }),
              _actionBtn(Icons.menu_outlined, 'MENU', Colors.white70, () {
                g.paused = true;
                g.overlays.add('mainMenu');
                g.overlays.remove('hud');
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _trafficPhaseIndicator() {
    return ValueListenableBuilder<TrafficPhase>(
      valueListenable: g.trafficPhaseNotifier,
      builder: (context, currentPhase, _) {
        IconData icon;
        Color color;
        String label;
        switch (currentPhase) {
          case TrafficPhase.morningRush:
            icon = Icons.wb_sunny_outlined;
            color = Colors.orangeAccent;
            label = 'MORNING RUSH';
            break;
          case TrafficPhase.midday:
            icon = Icons.light_mode;
            color = Colors.yellowAccent;
            label = 'MIDDAY';
            break;
          case TrafficPhase.eveningRush:
            icon = Icons.nights_stay_outlined;
            color = Colors.deepOrangeAccent;
            label = 'EVENING RUSH';
            break;
          case TrafficPhase.calm:
            icon = Icons.bedtime;
            color = Colors.blueGrey;
            label = 'CALM HOURS';
            break;
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            );
          },
          child: Row(
            key: ValueKey(currentPhase),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 12),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.outfit(color: color, fontSize: 10, fontWeight: FontWeight.bold, decoration: TextDecoration.none),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _mapEventNotification(FlowGridGame g) {
    final String title;
    final IconData icon;
    final Color color;
    switch (g.activeEvent) {
      case 'blizzard':
        title = "BLIZZARD";
        icon = Icons.ac_unit;
        color = Colors.lightBlueAccent;
        break;
      case 'dustStorm':
        title = "DUST STORM";
        icon = Icons.cloud;
        color = Colors.orange;
        break;
      case 'animalCrossing':
        title = "ANIMAL CROSSING";
        icon = Icons.pets;
        color = Colors.amber;
        break;
      case 'drawbridgeOpen':
        title = "DRAWBRIDGE OPEN";
        icon = Icons.warning;
        color = Colors.redAccent;
        break;
      case 'flashFlood':
        title = "FLASH FLOOD";
        icon = Icons.water;
        color = Colors.blue;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF14161B),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(color: color, fontSize: 9, fontWeight: FontWeight.bold, decoration: TextDecoration.none),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(1),
                  child: LinearProgressIndicator(
                    value: (1.0 - (g.eventTimer / g.eventDuration)).clamp(0.0, 1.0),
                    backgroundColor: Colors.white10,
                    color: color,
                    minHeight: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventNotification(CityEvent event) {
    final tilePos = event.affectedTile;
    return GestureDetector(
      onTap: tilePos != null
          ? () => widget.game.focusCameraOnGridPosition(tilePos)
          : null,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFF14161B),
          border: Border.all(color: event.color.withValues(alpha: 0.25), width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(event.icon, color: event.color, size: 12),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title.toUpperCase(),
                    style: GoogleFonts.outfit(color: event.color, fontSize: 9, fontWeight: FontWeight.bold, decoration: TextDecoration.none),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(1),
                    child: LinearProgressIndicator(
                      value: (1.0 - (event.elapsed / event.duration)).clamp(0.0, 1.0),
                      backgroundColor: Colors.white10,
                      color: event.color,
                      minHeight: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emergencyNotification(EmergencyEvent event) {
    final pct = (event.timeout / 60.0).clamp(0.0, 1.0);
    return GestureDetector(
      onTap: () => widget.game.focusCameraOnGridPosition(event.location),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1215),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.redAccent.withValues(alpha: 0.4),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                value: pct,
                strokeWidth: 2.0,
                backgroundColor: Colors.white10,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    event.description.toUpperCase(),
                    style: GoogleFonts.outfit(
                      color: Colors.redAccent,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _actionBtn(IconData icon, String label, Color col, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: col, size: 16),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: col,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _speedSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Column(
        children: [
          _miniLabel('SPEED'),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _speedDot(0.0, Icons.pause, Colors.redAccent),
              _speedDot(1.0, Icons.play_arrow, Colors.white70),
              _speedDot(2.0, Icons.fast_forward, Colors.blueAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewSection() {
    final active = g.previewMode;
    final color = Colors.tealAccent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      child: Column(
        children: [
          _miniLabel('VIEWPORT'),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () {
              setState(() {
                g.previewMode = !g.previewMode;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: active ? color.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
                border: Border.all(
                  color: active ? color : Colors.white.withValues(alpha: 0.08),
                  width: active ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    active ? Icons.pinch_sharp : Icons.pinch_outlined,
                    color: active ? color : Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    active ? "PREVIEW ON" : "PREVIEW",
                    style: GoogleFonts.outfit(
                      color: active ? color : Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _speedDot(double val, IconData icon, Color col) {
    final active = g.timeScale == val;
    return GestureDetector(
      onTap: () => setState(() => g.timeScale = val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? col.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
          border: Border.all(
            color: active ? col : Colors.white.withValues(alpha: 0.08), 
            width: active ? 1.5 : 1,
          ),
          boxShadow: active ? [
            BoxShadow(
              color: col.withValues(alpha: 0.2),
              blurRadius: 6,
              spreadRadius: 0.5,
            )
          ] : null,
        ),
        child: Icon(icon, color: active ? col : Colors.white.withValues(alpha: 0.4), size: 16),
      ),
    );
  }

  Widget _miniStat(String text, Color col) {
    return Text(
      text,
      style: GoogleFonts.outfit(color: col, fontSize: 16, fontWeight: FontWeight.bold, decoration: TextDecoration.none),
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _miniLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(color: Colors.white24, fontSize: 9, letterSpacing: 1.5, decoration: TextDecoration.none),
    );
  }

  /// Smooth animated counter that crossfades between value changes
  Widget _animatedStat(String text, Color col) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
            child: child,
          ),
        );
      },
      child: Text(
        text,
        key: ValueKey<String>(text),
        style: GoogleFonts.outfit(color: col, fontSize: 16, fontWeight: FontWeight.bold, decoration: TextDecoration.none),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: Colors.white10,
    );
  }

  Widget _badge(int val) {
    final hasStock = val > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: hasStock ? const Color(0xFF27AE60) : const Color(0xFFEB5757),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$val',
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _toolButton({
    required BuildTool tool,
    required IconData icon,
    required String label,
    ValueNotifier<int>? notifier,
    int? count,
    VoidCallback? onTapOverride,
    bool? isSelectedOverride,
    bool isDisabled = false,
  }) {
    final isSelected = isSelectedOverride ?? (g.activeTool == tool);
    return IgnorePointer(
      ignoring: isDisabled,
      child: Opacity(
        opacity: isDisabled ? 0.35 : 1.0,
        child: GestureDetector(
          onTap: onTapOverride ?? () => setState(() => g.activeTool = tool),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF2F80ED).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? const Color(0xFF2F80ED) : Colors.white.withValues(alpha: 0.08),
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: const Color(0xFF2F80ED).withValues(alpha: 0.25),
                  blurRadius: 10,
                  spreadRadius: 0.5,
                )
              ] : null,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon, 
                        color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.5), 
                        size: 20,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: GoogleFonts.outfit(
                          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.5),
                          fontSize: 8.5,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (notifier != null || count != null)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: notifier != null
                      ? ValueListenableBuilder<int>(
                          valueListenable: notifier,
                          builder: (context, val, _) => _badge(val),
                        )
                      : _badge(count ?? 0),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoPanel() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() {
          showInfoPanel = false;
          g.paused = false;
        }),
        child: Container(
          color: Colors.black54,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
                margin: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E24).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white10),
                  boxShadow: [
                    BoxShadow(color: Colors.black45, blurRadius: 40, spreadRadius: 10)
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                g.selectedMapType.name.toUpperCase(),
                                style: GoogleFonts.outfit(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 2),
                              ),
                              Text(
                                'MISSION INTELLIGENCE',
                                style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => setState(() {
                              showInfoPanel = false;
                              g.paused = false;
                            }),
                            icon: const Icon(Icons.close, color: Colors.white38),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _infoSectionTitle('CITY STATISTICS'),
                            _infoStatRow('SCORE', '${g.score}', Colors.amber),
                            _infoStatRow('WEEK', '${g.week}', Colors.white70),
                            _infoStatRow('SATISFACTION', '${(g.gridManager!.regionalSatisfaction * 100).toInt()}%', 
                              g.gridManager!.regionalSatisfaction < 0.4 ? Colors.redAccent : Colors.lightGreenAccent),
                            const SizedBox(height: 16),
                            _infoSectionTitle('RESOURCES'),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _resourceChip(Icons.add_road, 'ROADS: ${g.gridManager!.roads}'),
                                _resourceChip(Icons.terrain, 'TUNNELS: ${g.gridManager!.tunnels}'),
                                _resourceChip(Icons.water, 'BRIDGES: ${g.gridManager!.bridges}'),
                              ],
                            ),
                            const SizedBox(height: 24),
                            _infoSectionTitle('TERRAIN INTEL'),
                            _mapIntelSection(),
                            const SizedBox(height: 24),
                            _infoSectionTitle('GAMEPLAY HANDBOOK'),
                            _helpItem('TRAFFIC SIGNALS', 'Place on intersections to cycle priority. Essential for 4-way junctions.'),
                            _helpItem('SMART JUNCTIONS', 'Circular flow prevents stopping. High throughput for busy districts.'),
                            _helpItem('EXPRESS LANES', 'High-speed overpasses that bypass surface traffic. Connecting long distances.'),
                            _helpItem('EMERGENCY STATE', 'When demand icons flash red, a destination is critical. Prioritize delivery!'),
                            _helpItem('OWNERSHIP', 'Player roads give refunds. System roads (driveways) are free but fixed.'),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => setState(() {
                            showInfoPanel = false;
                            g.paused = false;
                          }),
                          child: Text('RETURN TO MISSION', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: GoogleFonts.outfit(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
    );
  }

  Widget _infoStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14)),
          Text(value, style: GoogleFonts.outfit(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _resourceChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.blueAccent),
          const SizedBox(width: 6),
          Text(text, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _helpItem(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.outfit(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(desc, style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }

  Widget _mapIntelSection() {
    final map = g.selectedMapType;
    List<Widget> items = [];
    switch (map) {
      case MapType.zen:
        items = [
          _helpItem('BALANCED CLIMATE', 'Standard traction and physics. A peaceful sandbox environment without harsh environmental hazards.'),
        ];
        break;
      case MapType.andes:
        items = [
          _helpItem('TERRACOTTA CANYONS', 'Sparse connection corridors. Valley routes are critical.'),
          _helpItem('MOUNTAIN ARCHITECTURE', 'Buildings are decorated with clay slate chimneys.'),
        ];
        break;
      case MapType.nile:
        items = [
          _helpItem('RIVER BASIN', 'Bridges are highly critical to cross the wide central river splitting the map.'),
          _helpItem('OASIS MUD-BRICK', 'Buildings feature flat clay domes representing desert oasis architecture.'),
        ];
        break;
      case MapType.arctic:
        items = [
          _helpItem('SLIPPERY ICE ROADS', 'Build directly over ice lakes without bridges. Note: Vehicles slide and move 40% slower on ice.'),
          _helpItem('BLIZZARD HAZARD', 'Periodic snowy storms reduce all vehicle speeds to 60%.'),
          _helpItem('SNOWY ROOFS', 'Buildings feature thick white snow caps on their roofs.'),
        ];
        break;
      case MapType.savanna:
        items = [
          _helpItem('DIRT ROADS', 'All built roads are unpaved dirt tracks, making vehicles travel 20% slower.'),
          _helpItem('GAZELLE CROSSINGS', 'Wild gazelle herds periodically cross and block road traffic.'),
          _helpItem('DUST STORMS', 'Desert dust storms periodically reduce visibility and slow all traffic.'),
          _helpItem('THATCHED ROOFS', 'Buildings feature gold straw thatch overlays.'),
        ];
        break;
      case MapType.delta:
        items = [
          _helpItem('FLASH FLOODS', 'Periodic wetlands flooding submerges low-elevation roads, temporarily closing them.'),
          _helpItem('DRAWBRIDGES', 'Massive river structures that periodically open to let ships pass, blocking road lanes.'),
          _helpItem('WETLANDS IVY', 'Ivy/moss grows on lower building corners and roof edges.'),
        ];
        break;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items,
    );
  }

}
