import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/game_info.dart';
import '../theme/app_theme.dart';
import '../theme/settings_manager.dart';
import '../theme/theme_manager.dart';
import '../utils/ad_manager.dart';
import '../utils/hint_manager.dart';
import '../utils/purchase_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        backgroundColor: context.bgDark,
        foregroundColor: context.textPrimary,
        title: Text('Settings', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.textPrimary)),
        centerTitle: true,
      ),
      body: ListenableBuilder(
        listenable: settingsNotifier,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              // Appearance Section
              _SectionHeader(title:'Appearance'),
              const SizedBox(height: 8),
              _SettingsCard(
                children: [
                  ListenableBuilder(
                    listenable: themeNotifier,
                    builder: (ctx, _) {
                      return _SettingsTile(
                        icon: themeNotifier.isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                        title:'Dark Mode',
                        trailing: Switch.adaptive(
                          value: themeNotifier.isDarkMode,
                          onChanged: (_) => themeNotifier.toggleTheme(),
                          activeColor: AppTheme.wordleGreen,
                        ),
                      );
                    },
                  ),
                  _Divider(),
                  _SettingsTile(
                    icon: Icons.text_fields,
                    title:'Font Size',
                    subtitle: settingsNotifier.fontScale == 0.85
                        ?'Small'
                        : settingsNotifier.fontScale == 1.0
                            ?'Normal'
                            :'Large',
                    trailing: SizedBox(
                      width: 160,
                      child: Slider(
                        value: settingsNotifier.fontScale,
                        min: 0.85,
                        max: 1.15,
                        divisions: 2,
                        activeColor: AppTheme.wordleGreen,
                        onChanged: (val) {
                          settingsNotifier.setFontScale(val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Sound & Gameplay Section
              _SectionHeader(title:'Sound & Gameplay'),
              const SizedBox(height: 8),
              _SettingsCard(
                children: [
                  // Removed Mute All and Sound Level
                  _SettingsTile(
                    icon: Icons.volume_up_outlined,
                    title: 'SFX (loss, win, and tile tapping)',
                    subtitle:'Tap and win sounds',
                    trailing: Switch.adaptive(
                      value: settingsNotifier.soundEnabled,
                      onChanged: (val) => settingsNotifier.setSound(val),
                      activeColor: AppTheme.wordleGreen,
                    ),
                  ),
                   _Divider(),
                  _SettingsTile(
                    icon: Icons.music_note_outlined,
                    title: 'Bg music',
                    subtitle:'Looping ambient background pads',
                    trailing: Switch.adaptive(
                      value: settingsNotifier.musicEnabled,
                      onChanged: (val) => settingsNotifier.setMusic(val),
                      activeColor: AppTheme.wordleGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Premium & Ads Section
              _SectionHeader(title: 'Premium & Ads'),
              const SizedBox(height: 8),
              _SettingsCard(
                children: [
                  _SettingsTile(
                    icon: Icons.star_border_outlined,
                    title: 'Go Premium',
                    subtitle: settingsNotifier.adsRemoved
                        ? 'Premium ad-free is active!'
                        : 'Unlock lifetime ad-free experience',
                    onTap: settingsNotifier.adsRemoved
                        ? null
                        : () {
                            final messenger = ScaffoldMessenger.of(context);
                            PurchaseManager.buyAdFree(
                              onStoreUnavailable: () {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('App Store/Play Store is currently unavailable.', style: GoogleFonts.outfit()),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              },
                              onProductNotFound: () {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Premium product ID not found. Verify console configuration.', style: GoogleFonts.outfit()),
                                    backgroundColor: Colors.amber[800],
                                  ),
                                );
                              },
                            );
                          },
                  ),
                  _Divider(),
                  _SettingsTile(
                    icon: Icons.restore_outlined,
                    title: 'Restore Purchase',
                    subtitle: 'Restore premium status from App/Play store',
                    onTap: () {
                      final messenger = ScaffoldMessenger.of(context);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Restoring purchases...', style: GoogleFonts.outfit()),
                          backgroundColor: Colors.grey[800],
                          duration: const Duration(seconds: 1),
                        ),
                      );
                      PurchaseManager.restorePurchases(
                        onRestoreFinished: (success) {
                          if (success) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Restore process finished.', style: GoogleFonts.outfit()),
                                backgroundColor: AppTheme.wordleGreen,
                              ),
                            );
                          } else {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Restore failed or store unavailable.', style: GoogleFonts.outfit()),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                  _Divider(),
                  _SettingsTile(
                    icon: Icons.play_circle_outline,
                    title: 'Earn Free Hints',
                    subtitle: AdManager.isRewardedAdReady()
                        ? 'Rewarded video ready'
                        : 'Watch video to get +2 hints',
                    onTap: () => _showEarnHintsDialog(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Data Section
              _SectionHeader(title:'Data'),
              const SizedBox(height: 8),
              _SettingsCard(
                children: [
                  _SettingsTile(
                    icon: Icons.delete_outline,
                    title:'Reset All Progress',
                    subtitle:'Clear all level data and streaks',
                    titleColor: Colors.redAccent,
                    onTap: () => _showResetDialog(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // About Section
              _SectionHeader(title:'About'),
              const SizedBox(height: 8),
              _SettingsCard(
                children: [
                  _SettingsTile(
                    icon: Icons.info_outline,
                    title:'CogniQ',
                    subtitle:'Version 1.0.0 • Play. Think. Win.',
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
'Reset Progress?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.textPrimary),
        ),
        content: Text(
'This will clear all your game progress, levels, and streaks. This action cannot be undone.',
          style: GoogleFonts.outfit(color: context.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.outfit(color: context.textMuted, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await settingsNotifier.resetAllProgress();
              if (ctx.mounted) Navigator.pop(ctx);
              messenger.showSnackBar(
                SnackBar(
                  content: Text('All progress has been reset', style: GoogleFonts.outfit()),
                  backgroundColor: Colors.redAccent,
                ),
              );
            },
            child: Text('Reset', style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showEarnHintsDialog(BuildContext context) {
    String selectedGameId = kAllGames.firstWhere((g) => !g.isStashed).id;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: context.bgCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Earn Free Hints',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.textPrimary),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select the game you want to add 2 hints to:',
                    style: GoogleFonts.outfit(color: context.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: context.bgDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.textMuted.withAlpha(50)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedGameId,
                        isExpanded: true,
                        dropdownColor: context.bgCard,
                        icon: Icon(Icons.arrow_drop_down, color: context.textSecondary),
                        items: kAllGames.where((g) => !g.isStashed).map((game) {
                          return DropdownMenuItem<String>(
                            value: game.id,
                            child: Text(
                              game.name,
                              style: GoogleFonts.outfit(color: context.textPrimary, fontSize: 14),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedGameId = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.outfit(color: context.textMuted, fontWeight: FontWeight.w600),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.wordleGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                   onPressed: () {
                    Navigator.pop(ctx);
                    final messenger = ScaffoldMessenger.of(context);
                    AdManager.showRewardedAd(
                      onRewardGranted: (amount) async {
                        await HintManager.addHints(selectedGameId, amount);
                        final gameName = kAllGames.firstWhere((g) => g.id == selectedGameId).name;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Earned $amount hints for $gameName!',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: AppTheme.wordleGreen,
                          ),
                        );
                      },
                      onAdNotReady: () {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Rewarded ad is loading. Please try again in a moment.',
                              style: GoogleFonts.outfit(),
                            ),
                            backgroundColor: Colors.amber[800],
                          ),
                        );
                      },
                    );
                  },
                  child: Text(
                    'Watch Video',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.outfit(
        color: context.textMuted,
        fontSize: context.scale(11),
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color? titleColor;
  final VoidCallback? onTap;
  const _SettingsTile({required this.icon, required this.title, this.subtitle, this.trailing, this.titleColor, this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: titleColor ?? context.textSecondary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(
                    color: titleColor ?? context.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: context.scale(14),
                  )),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: GoogleFonts.outfit(
                      color: context.textMuted,
                      fontSize: context.scale(11),
                    )),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: context.textMuted.withAlpha(30)),
    );
  }
}
