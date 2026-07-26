import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/swipe_trail_overlay.dart';
import '../utils/prefs_keys.dart';
import '../utils/point_manager.dart';

class TrailStyle {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final List<Color> previewColors;

  const TrailStyle({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.previewColors,
  });
}

const List<TrailStyle> kAllTrails = [
  TrailStyle(
    id: 'none',
    name: 'No Trail',
    description: 'Disables swipe trails entirely.',
    emoji: '🚫',
    previewColors: [Colors.transparent, Colors.transparent, Colors.transparent],
  ),
  TrailStyle(
    id: 'accent',
    name: 'Game Accent',
    description: 'Matches the active game\'s signature color. A clean, single-tone trail.',
    emoji: '🎯',
    previewColors: [Color(0xFFA68B8A), Color(0xFFA68B8A), Color(0xFFA68B8A)],
  ),
  TrailStyle(
    id: 'sparkle',
    name: 'Sparkle Stars',
    description: 'Golden star particles that drift, shrink, and fade with gravity.',
    emoji: '✨',
    previewColors: [Color(0xFFFFD54F), Color(0xFFFFCA28), Color(0xFFFFC107)],
  ),
  TrailStyle(
    id: 'pastel',
    name: 'Pastel Glow',
    description: 'Soft pink, blue, and sky blend. Gentle and calming.',
    emoji: '🌸',
    previewColors: [Color(0xFFF3C6D3), Color(0xFFC6DEF1), Color(0xFFD6E2E9)],
  ),
  TrailStyle(
    id: 'neon_glow',
    name: 'Neon Glow',
    description: 'Electric cyan and neon magenta dual-pass glow trail.',
    emoji: '⚡',
    previewColors: [Color(0xFF00FFFF), Color(0xFFFF00FF)],
  ),
  TrailStyle(
    id: 'rainbow',
    name: 'Rainbow Neon',
    description: 'Vibrant electric rainbow trail with dual-pass neon glow.',
    emoji: '🌈',
    previewColors: [
      Color(0xFFFF003C),
      Color(0xFFFF8A00),
      Color(0xFFFABE00),
      Color(0xFF05FF00),
      Color(0xFF00FFFF),
      Color(0xFFBD00FF),
    ],
  ),
  TrailStyle(
    id: 'fire',
    name: 'Fire Trail',
    description: 'Warm crackling flame with rising ember sparks.',
    emoji: '🔥',
    previewColors: [Color(0xFFFF0000), Color(0xFFFF6600), Color(0xFFFFCC00)],
  ),
];

class TrailsScreen extends StatefulWidget {
  final String? highlightId;
  const TrailsScreen({super.key, this.highlightId});

  @override
  State<TrailsScreen> createState() => _TrailsScreenState();
}

class _TrailsScreenState extends State<TrailsScreen> {
  String _activeStyle = 'none';
  bool _loading = true;
  int _globalClears = 0;
  int _userPoints = 0;
  String? _customColorHex;
  List<String> _claimedStyles = ['none'];
  final ScrollController _scrollController = ScrollController();

  final List<Color> _accentColors = const [
    Color(0xFFA68B8A), // Original Mauve (default)
    Color(0xFF8F9A86), // Sage
    Color(0xFFE57373), // Coral/Red
    Color(0xFF4FC3F7), // Light Blue
    Color(0xFF81C784), // Light Green
    Color(0xFFFFD54F), // Amber
    Color(0xFFBA68C8), // Violet
  ];

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int getRequiredClears(String styleId) {
    switch (styleId) {
      case 'none':       return 0;
      case 'accent':     return 30;
      case 'sparkle':    return 100;
      case 'pastel':     return 250;
      case 'neon_glow':  return 999999; // Points only
      case 'rainbow':    return 999999; // Points only
      case 'fire':       return 999999; // Points only
      default:           return 999999;
    }
  }

  int trailPrice(String styleId) {
    switch (styleId) {
      case 'none':       return 0;
      case 'accent':     return 300;
      case 'sparkle':    return 1500;
      case 'pastel':     return 4000;
      case 'neon_glow':  return 9000;
      case 'rainbow':    return 16000;
      case 'fire':       return 25000;
      default:           return 999999;
    }
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final clears = prefs.getInt(PrefsKeys.globalLevelClearedCount) ?? 0;
    final style = prefs.getString(PrefsKeys.swipeTrailStyle) ?? 'none';
    final hex = prefs.getString(PrefsKeys.swipeTrailCustomColor);
    final claimed = prefs.getStringList(PrefsKeys.claimedTrailStyles) ?? ['none'];
    final points = await PointManager.getPoints();
 
    if (mounted) {
      setState(() {
        _globalClears = clears;
        _activeStyle = style;
        _customColorHex = hex;
        _claimedStyles = claimed;
        _userPoints = points;
        _loading = false;
      });

      if (widget.highlightId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final index = kAllTrails.indexWhere((t) => t.id == widget.highlightId);
          if (index != -1) {
            double offset = 120.0 + index * 95.0; // approximate card heights
            _scrollController.animateTo(
              offset,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOutCubic,
            );
          }
        });
      }
    }
  }

  Future<void> _selectStyle(String styleId) async {
    final reqClears = getRequiredClears(styleId);
    final isClaimed = _claimedStyles.contains(styleId);
    if (_globalClears < reqClears && !isClaimed) return;
 
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsKeys.swipeTrailStyle, styleId);
    await prefs.setBool('swipe_trail_unlocked', true);
    SwipeTrailOverlay.unlockedNotifier.value = true;
 
    if (mounted) {
      setState(() {
        _activeStyle = styleId;
      });
    }
    SwipeTrailOverlay.styleNotifier.value = styleId;
  }

  Future<void> _claimStyle(String styleId) async {
    final prefs = await SharedPreferences.getInstance();
    final claimed = prefs.getStringList(PrefsKeys.claimedTrailStyles) ?? ['none'];
    if (!claimed.contains(styleId)) {
      claimed.add(styleId);
      await prefs.setStringList(PrefsKeys.claimedTrailStyles, claimed);
    }
    if (mounted) {
      setState(() {
        _claimedStyles = claimed;
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Claimed trail style: ${kAllTrails.firstWhere((t) => t.id == styleId).name}!',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.softSage,
      ),
    );
  }

  Future<void> _buyStyle(String styleId) async {
    final price = trailPrice(styleId);
    if (_userPoints < price) return;

    final success = await PointManager.consumePoints(price);
    if (success) {
      final prefs = await SharedPreferences.getInstance();
      final claimed = prefs.getStringList(PrefsKeys.claimedTrailStyles) ?? ['none'];
      if (!claimed.contains(styleId)) {
        claimed.add(styleId);
        await prefs.setStringList(PrefsKeys.claimedTrailStyles, claimed);
      }
      final points = await PointManager.getPoints();
      if (mounted) {
        setState(() {
          _claimedStyles = claimed;
          _userPoints = points;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Purchased trail style: ${kAllTrails.firstWhere((t) => t.id == styleId).name} for $price ✦!',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.softSage,
        ),
      );
    }
  }

  Future<void> _selectCustomColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    final hexString = color.value.toString();
    await prefs.setString(PrefsKeys.swipeTrailCustomColor, hexString);
    if (mounted) {
      setState(() {
        _customColorHex = hexString;
      });
    }
    SwipeTrailOverlay.customColorNotifier.value = hexString;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        backgroundColor: context.bgDark,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Swipe Trails',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: context.scale(18),
            color: context.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: context.textPrimary,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              children: [
                // Progress summary card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.zenCard(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your Progression',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: context.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Clear levels or use points to unlock trails.',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: context.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.softSage.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$_globalClears Cleared',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.softSage,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.warmAmber.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$_userPoints ✦',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.warmAmber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Section title
                Text(
                  'Choose your trail style',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Active trail is shown whenever you drag in-game.',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),

                // Trail cards
                ...kAllTrails.map((trail) => _buildTrailCard(trail)),
              ],
            ),
    );
  }

  Widget _buildTrailCard(TrailStyle trail) {
    final reqClears = getRequiredClears(trail.id);
    final isUnlocked = _globalClears >= reqClears;
    final isClaimed = _claimedStyles.contains(trail.id);
    final isActive = isClaimed && _activeStyle == trail.id;
    final price = trailPrice(trail.id);
    final canAfford = _userPoints >= price;
    final isHighlight = widget.highlightId == trail.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: isClaimed ? () => _selectStyle(trail.id) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHighlight
                  ? Colors.amber
                  : (isActive 
                      ? AppTheme.softSage 
                      : (isUnlocked ? context.textMuted.withAlpha(30) : context.textMuted.withAlpha(15))),
              width: (isHighlight || isActive) ? 2.0 : 0.5,
            ),
          ),
          child: Opacity(
            opacity: (isUnlocked || isClaimed || (!isClaimed && canAfford)) ? 1.0 : 0.55,
            child: Row(
              children: [
                // Preview swatch
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                     borderRadius: BorderRadius.circular(12),
                     gradient: trail.id == 'sparkle'
                        ? null
                        : (trail.id == 'accent' && _customColorHex != null
                            ? null
                            : LinearGradient(
                                colors: trail.previewColors,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )),
                     color: trail.id == 'sparkle'
                        ? const Color(0xFF2A2520)
                        : (trail.id == 'accent' && _customColorHex != null
                            ? Color(int.parse(_customColorHex!))
                            : null),
                  ),
                  child: trail.id == 'sparkle'
                      ? Center(
                          child: Text(
                            trail.emoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            trail.name,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.softSage.withAlpha(40),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'ACTIVE',
                                style: GoogleFonts.outfit(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.softSage,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isUnlocked 
                            ? trail.description 
                            : (reqClears >= 999999 
                                ? 'Exclusive: Buy with points' 
                                : 'Locked: Requires $reqClears levels cleared (Current: $_globalClears)'),
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: isUnlocked ? context.textSecondary : Colors.redAccent.withOpacity(0.8),
                          height: 1.3,
                        ),
                      ),
                      if (trail.id == 'accent' && isActive) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Choose Accent Color:',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 32,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _accentColors.length,
                            separatorBuilder: (ctx, idx) => const SizedBox(width: 8),
                            itemBuilder: (context, cIdx) {
                              final color = _accentColors[cIdx];
                              final isSelected = _customColorHex == color.value.toString() ||
                                  (_customColorHex == null && cIdx == 0);
                              return GestureDetector(
                                onTap: () => _selectCustomColor(color),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? (Theme.of(context).brightness == Brightness.dark
                                              ? Colors.white
                                              : Colors.black)
                                          : Colors.transparent,
                                      width: 2.0,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: color.withOpacity(0.4),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: isSelected
                                      ? Icon(
                                          Icons.done,
                                          color: color.computeLuminance() > 0.6
                                              ? Colors.black87
                                              : Colors.white,
                                          size: 16,
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Action controls
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: isClaimed
                      ? (isActive 
                          ? const Icon(Icons.check_circle_rounded, color: AppTheme.softSage, size: 20)
                          : const SizedBox.shrink())
                      : (isUnlocked
                          ? ElevatedButton(
                              onPressed: () => _claimStyle(trail.id),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.dustyMauve,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'Claim',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : ElevatedButton(
                              onPressed: canAfford ? () => _buyStyle(trail.id) : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: canAfford ? AppTheme.warmAmber : context.textMuted.withAlpha(20),
                                foregroundColor: canAfford ? Colors.white : context.textMuted,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'Buy: $price ✦',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
