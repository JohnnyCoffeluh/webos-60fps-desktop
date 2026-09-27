import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../theme/webos_theme.dart';

class SettingsApp extends StatefulWidget {
  final Function(String wallpaper)? onWallpaperChanged;
  const SettingsApp({super.key, this.onWallpaperChanged});

  @override
  State<SettingsApp> createState() => _SettingsAppState();
}

class _SettingsAppState extends State<SettingsApp> {
  bool _speedBoostEnabled = true;
  bool _serviceWorkerIntercept = true;
  bool _aggressiveCache = true;
  String _selectedWallpaper = 'Cyber Obsidian';

  final List<String> _wallpapers = [
    'Cyber Obsidian',
    'Neon Nebula',
    'Deep Aurora',
    'Midnight Slate',
  ];

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;

    return Container(
      color: const Color(0xFF0F172A),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Section 1: Network & Internet Speed Acceleration
          _buildSectionHeader('High-Speed Internet & Gateway Settings', Icons.speed_rounded),
          Card(
            color: const Color(0xFF1E293B),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Ultra-Fast Speed Booster', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Enables in-memory LRU caching on Express gateway for 0ms page loads', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  value: _speedBoostEnabled,
                  activeThumbColor: WebOSTheme.accent,
                  onChanged: (val) => setState(() => _speedBoostEnabled = val),
                ),
                const Divider(height: 1, color: Color(0x22FFFFFF)),
                SwitchListTile(
                  title: const Text('Service Worker Network Interception', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Intercepts internal browser traffic & forwards via Service Worker (sw.js)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  value: _serviceWorkerIntercept,
                  activeThumbColor: WebOSTheme.primary,
                  onChanged: (val) => setState(() => _serviceWorkerIntercept = val),
                ),
                const Divider(height: 1, color: Color(0x22FFFFFF)),
                SwitchListTile(
                  title: const Text('Aggressive Asset Caching', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Stale-While-Revalidate caching strategy for maximum responsiveness', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  value: _aggressiveCache,
                  activeThumbColor: WebOSTheme.secondary,
                  onChanged: (val) => setState(() => _aggressiveCache = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 2: Security & Authentication
          _buildSectionHeader('Authentication & Security', Icons.security_rounded),
          Card(
            color: const Color(0xFF1E293B),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_user_rounded, color: WebOSTheme.accent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Session Tier: ${auth.displayUid}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Firebase Anonymous Authentication is active. Your workspace has full authorized access without requiring email credentials, passwords, or registration hurdles.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await auth.refreshToken();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Firebase session token refreshed.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Refresh Auth Token'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: WebOSTheme.primary,
                      side: const BorderSide(color: WebOSTheme.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Section 3: Appearance & Wallpaper
          _buildSectionHeader('Workspace Appearance', Icons.palette_rounded),
          Card(
            color: const Color(0xFF1E293B),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Desktop Wallpaper:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _wallpapers.map((wp) {
                      final isSelected = _selectedWallpaper == wp;
                      return ChoiceChip(
                        label: Text(wp),
                        selected: isSelected,
                        selectedColor: WebOSTheme.primary.withValues(alpha: 0.25),
                        backgroundColor: const Color(0xFF0F172A),
                        labelStyle: TextStyle(
                          color: isSelected ? WebOSTheme.primary : const Color(0xFF94A3B8),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: isSelected ? WebOSTheme.primary : const Color(0x3338BDF8),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedWallpaper = wp);
                            widget.onWallpaperChanged?.call(wp);
                          }
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: WebOSTheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFCBD5E1)),
          ),
        ],
      ),
    );
  }
}
