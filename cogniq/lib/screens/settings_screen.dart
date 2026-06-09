import'package:flutter/material.dart';
import'package:google_fonts/google_fonts.dart';
import'package:shared_preferences/shared_preferences.dart';
import'../theme/app_theme.dart';
import'../theme/settings_manager.dart';
import'../theme/theme_manager.dart';

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
              // Feedback Section
              _SectionHeader(title:'Feedback'),
              const SizedBox(height: 8),
              _SettingsCard(
                children: [
                  _SettingsTile(
                    icon: Icons.vibration,
                    title:'Haptic Feedback',
                    subtitle:'Vibrate on interactions',
                    trailing: Switch.adaptive(
                      value: settingsNotifier.hapticEnabled,
                      onChanged: (val) => settingsNotifier.setHaptic(val),
                      activeColor: AppTheme.wordleGreen,
                    ),
                  ),
                  _Divider(),
                  _SettingsTile(
                    icon: Icons.volume_up_outlined,
                    title:'Sound Effects',
                    subtitle:'Tap and win sounds',
                    trailing: Switch.adaptive(
                      value: settingsNotifier.soundEnabled,
                      onChanged: (val) => settingsNotifier.setSound(val),
                      activeColor: AppTheme.wordleGreen,
                    ),
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
              await settingsNotifier.resetAllProgress();
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('All progress has been reset', style: GoogleFonts.outfit()),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: Text('Reset', style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
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
