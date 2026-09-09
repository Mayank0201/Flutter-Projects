import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/flow_grid_game.dart';

class TutorialOverlay extends StatefulWidget {
  final FlowGridGame game;
  const TutorialOverlay({super.key, required this.game});

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  late final PageController _pageController;
  int _currentStep = 0;

  final List<TutorialStep> _steps = [
    TutorialStep(
      title: "WELCOME TO FLOW GRID",
      description: "A minimalist city-builder where transport is everything. Your goal: connect houses to destinations of the same color.",
      icon: Icons.map_outlined,
    ),
    TutorialStep(
      title: "BUILDING PATHS",
      description: "Select the PATH tool from the HUD. Click and drag to lay a path. Paths consume your limited inventory.",
      icon: Icons.add_road,
    ),
    TutorialStep(
      title: "ROAD UPGRADES",
      description: "Roads automatically upgrade as they carry more traffic. Local roads become Avenues, and busy corridors upgrade to Arteries with higher speeds and capacity.",
      icon: Icons.route,
    ),
    TutorialStep(
      title: "TUNNELS & BRIDGES",
      description: "Mountains block paths. Water stops traffic. Use the TUNNEL or BRIDGE tool to cross them. Extensions in a single drag are free!",
      icon: Icons.terrain,
    ),
    TutorialStep(
      title: "TRAFFIC LIGHTS",
      description: "Drop a Traffic Light on any intersection to manage flow. They automatically cycle every few seconds to prevent gridlock at busy crossings.",
      icon: Icons.traffic,
    ),
    TutorialStep(
      title: "ROUNDABOUTS",
      description: "Need smoother traffic flow? Place a Roundabout hub. Drones flow in a continuous loop, reducing intersection waiting times.",
      icon: Icons.sync,
    ),
    TutorialStep(
      title: "EXPRESS LANES",
      description: "The ultimate tool. Drag an Express Lane between any two path tiles to create a high-speed, direct overpass that bypasses all traffic.",
      icon: Icons.flight_takeoff,
    ),
    TutorialStep(
      title: "RUSH HOUR",
      description: "Watch the clock! Destinations experience sudden surges in demand during morning and evening rush hours. Build redundant routes to handle the spikes.",
      icon: Icons.access_time_filled,
    ),
    TutorialStep(
      title: "DYNAMICS & DEMAND",
      description: "New buildings appear over time. If a house is disconnected for too long, satisfaction drops. Keep the flow moving!",
      icon: Icons.speed,
    ),
    TutorialStep(
      title: "EXPRESSWAYS",
      description: "Build elevated express roads that fly over ground traffic. Use them to connect distant districts directly and avoid busy intersections.",
      icon: Icons.account_tree_outlined,
    ),
    TutorialStep(
      title: "LAYERED ROADS",
      description: "Expressways and tunnels let routes cross each other without colliding. Build multi-layer networks to keep heavy traffic moving smoothly.",
      icon: Icons.layers,
    ),
    TutorialStep(
      title: "ROAD REFUNDS",
      description: "Roads you place cost resources and give them back when removed. Driveways and auto-built connectors are free, but cannot be removed for refunds.",
      icon: Icons.assignment_ind_outlined,
    ),
    TutorialStep(
      title: "WEEKLY UPGRADES",
      description: "Every Sunday, you'll receive new resources. Choose wisely between more paths, tunnels, or advanced junctions to keep up with the city's growing demand.",
      icon: Icons.auto_awesome,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _close() {
    widget.game.overlays.remove('tutorial');
    if (!widget.game.overlays.isActive('hud')) {
      widget.game.overlays.add('mainMenu');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background Scrim
          Positioned.fill(
            child: GestureDetector(
              onTap: _close,
              child: Container(color: Colors.black.withValues(alpha: 0.85)),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
              child: Container(
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF10191C),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFFBF945C).withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                ),
                child: Stack(
                  children: [
                    // Swipeable Pages
                    PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) => setState(() => _currentStep = index),
                      itemCount: _steps.length,
                      itemBuilder: (context, index) {
                        final step = _steps[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 12),
                                // Datasheet Step Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF182428),
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                      color: const Color(0xFFBF945C).withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Text(
                                    'STEP ${index + 1} OF ${_steps.length}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFE5A96A),
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF182428),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: const Color(0xFFBF945C).withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Icon(step.icon, color: const Color(0xFFE5A96A), size: 28),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  step.title,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  step.description,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    height: 1.6,
                                    color: Colors.white.withValues(alpha: 0.65),
                                  ),
                                ),
                                const SizedBox(height: 100), // Space for controls
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    // Close Button
                    Positioned(
                      top: 12,
                      right: 12,
                      child: IconButton(
                        onPressed: _close,
                        icon: const Icon(Icons.close, color: Colors.white30, size: 22),
                      ),
                    ),
                    // Navigation Overlay (Bottom)
                    Positioned(
                      bottom: 24,
                      left: 24,
                      right: 24,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Page Indicators (LED Array)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: AnimatedBuilder(
                              animation: _pageController,
                              builder: (context, _) {
                                final double livePage =
                                    _pageController.hasClients && _pageController.page != null
                                        ? _pageController.page!
                                        : _currentStep.toDouble();
                                final int activeIndex =
                                    livePage.round().clamp(0, _steps.length - 1);
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(_steps.length, (index) {
                                    final isActive = index == activeIndex;
                                    return GestureDetector(
                                      onTap: () => _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        margin: const EdgeInsets.symmetric(horizontal: 3),
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: isActive ? const Color(0xFFBF945C) : const Color(0xFF1F2F33),
                                          borderRadius: BorderRadius.circular(1.5),
                                          border: Border.all(
                                            color: isActive ? const Color(0xFFE5A96A) : const Color(0xFF283B40),
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (_currentStep > 0)
                                TextButton(
                                  onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                                  child: Text("PREVIOUS", style: GoogleFonts.outfit(color: Colors.white54, letterSpacing: 1, fontSize: 11)),
                                )
                              else
                                const SizedBox(width: 80),
                              
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFBF945C),
                                  foregroundColor: const Color(0xFF10191C),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                                onPressed: () {
                                  if (_currentStep < _steps.length - 1) {
                                    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                                  } else {
                                    _close();
                                  }
                                },
                                child: Text(_currentStep == _steps.length - 1 ? "GOT IT" : "NEXT", 
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 11)),
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
        ],
      ),
    );
  }
}

class TutorialStep {
  final String title;
  final String description;
  final IconData icon;

  TutorialStep({required this.title, required this.description, required this.icon});
}
