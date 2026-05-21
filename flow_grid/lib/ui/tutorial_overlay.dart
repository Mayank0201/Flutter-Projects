import 'dart:ui' as ui;
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
      title: "BUILDING ROADS",
      description: "Select the ROAD tool from the HUD. Click and drag to lay pavement. Roads consume your limited inventory.",
      icon: Icons.add_road,
    ),
    TutorialStep(
      title: "ROAD HIERARCHY",
      description: "Roads automatically upgrade as they carry more traffic. Local roads become Avenues, and heavily used routes upgrade to Arteries with higher speeds and capacity.",
      icon: Icons.route,
    ),
    TutorialStep(
      title: "TUNNELS & BRIDGES",
      description: "Mountains block roads. Water stops traffic. Use the TUNNEL or BRIDGE tool to cross them. Extensions in a single drag are free!",
      icon: Icons.terrain,
    ),
    TutorialStep(
      title: "TRAFFIC LIGHTS",
      description: "Drop a Traffic Light on any intersection to manage flow. They automatically cycle every few seconds to prevent gridlock at busy crossings.",
      icon: Icons.traffic,
    ),
    TutorialStep(
      title: "SMART JUNCTIONS",
      description: "Need higher throughput? Place a Smart Junction (Roundabout). Cars flow continuously in a clockwise direction, greatly reducing wait times.",
      icon: Icons.sync,
    ),
    TutorialStep(
      title: "EXPRESS LANES",
      description: "The ultimate tool. Drag an Express Lane between any two road tiles to create a high-speed, direct overpass that bypasses all traffic.",
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
      title: "TRANSPORT LAYERS",
      description: "Efficiency is key. Surface roads (Grey) handle local 'last-mile' trips. Highways (Green) and Metros (Purple) are high-speed, high-capacity layers that bypass local intersections. They only connect to the surface at specific interchanges to maintain high velocity.",
      icon: Icons.account_tree_outlined,
    ),
    TutorialStep(
      title: "MULTI-LAYER NETWORKS",
      description: "Manage a complex ecosystem. Use Highways for long-distance car travel and Metros for massive passenger throughput. Since these layers can overlap, you can build dense networks without creating surface-level gridlock.",
      icon: Icons.layers,
    ),
    TutorialStep(
      title: "INFRASTRUCTURE OWNERSHIP",
      description: "Not all roads are equal. Player roads cost resources and can be refunded. System driveways and auto-generated stubs are free but do not provide refunds when deleted.",
      icon: Icons.assignment_ind_outlined,
    ),
    TutorialStep(
      title: "WEEKLY UPGRADES",
      description: "Every Sunday, you'll receive new resources. Choose wisely between more roads, tunnels, or advanced junctions to keep up with the city's growing demand.",
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
          // Glass Background
          Positioned.fill(
            child: GestureDetector(
               onTap: _close,
               child: BackdropFilter(
                 filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                 child: Container(color: Colors.black.withValues(alpha: 0.6)),
               ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
              child: Container(
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E24).withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 60,
                      spreadRadius: 10,
                    )
                  ],
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
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(step.icon, color: Colors.blueAccent, size: 56),
                                ),
                                const SizedBox(height: 32),
                                Text(
                                  step.title,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  step.description,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    height: 1.6,
                                    color: Colors.white.withValues(alpha: 0.7),
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
                        icon: const Icon(Icons.close, color: Colors.white30, size: 28),
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
                          // Page Indicators
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(_steps.length, (index) {
                                final isActive = index == _currentStep;
                                return GestureDetector(
                                  onTap: () => _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    width: isActive ? 24 : 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: isActive ? Colors.blueAccent : Colors.white24,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (_currentStep > 0)
                                TextButton(
                                  onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                                  child: Text("PREVIOUS", style: GoogleFonts.outfit(color: Colors.white30, letterSpacing: 1)),
                                )
                              else
                                const SizedBox(width: 80),
                              
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: () {
                                  if (_currentStep < _steps.length - 1) {
                                    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                                  } else {
                                    _close();
                                  }
                                },
                                child: Text(_currentStep == _steps.length - 1 ? "FINISH" : "NEXT", 
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, letterSpacing: 1)),
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
