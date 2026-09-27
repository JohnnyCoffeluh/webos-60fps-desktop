import 'package:flutter/material.dart';
import '../../theme/webos_theme.dart';
import '../../services/auth_service.dart';

class NotesApp extends StatefulWidget {
  const NotesApp({super.key});

  @override
  State<NotesApp> createState() => _NotesAppState();
}

class _NotesAppState extends State<NotesApp> {
  final TextEditingController _titleController = TextEditingController(text: 'Virtual Workspace Initialized');
  final TextEditingController _contentController = TextEditingController(
    text: 'WebOS Virtual Desktop Environment running with:\n'
        '- Material 3 Glassmorphism UI\n'
        '- Authenticated Network Gateway client (Node.js + Express)\n'
        '- Service Worker network interception (sw.js)\n'
        '- Firebase Anonymous Authentication (Instant access, no sign-in friction)\n'
        '- In-memory RAM speed cache (0ms latency hits)\n',
  );

  bool _isSaved = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _titleController,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Note Title...',
                    hintStyle: TextStyle(color: Color(0xFF64748B)),
                  ),
                  onChanged: (_) => setState(() => _isSaved = false),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isSaved ? const Color(0x2210B981) : const Color(0x22F59E0B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isSaved ? Icons.cloud_done_rounded : Icons.cloud_upload_rounded,
                      size: 14,
                      color: _isSaved ? WebOSTheme.accent : WebOSTheme.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isSaved ? 'Synced: ${AuthService.instance.displayUid}' : 'Unsaved changes',
                      style: TextStyle(
                        fontSize: 11,
                        color: _isSaved ? WebOSTheme.accent : WebOSTheme.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _isSaved = true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Note saved to virtual session storage.')),
                  );
                },
                icon: const Icon(Icons.save_rounded, size: 14),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WebOSTheme.primary,
                  foregroundColor: const Color(0xFF0F172A),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const Divider(color: Color(0x2238BDF8)),
          Expanded(
            child: TextField(
              controller: _contentController,
              maxLines: null,
              expands: true,
              style: const TextStyle(fontSize: 14, color: Color(0xFFE2E8F0), height: 1.5),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Start typing workspace notes...',
                hintStyle: TextStyle(color: Color(0xFF64748B)),
              ),
              onChanged: (_) => setState(() => _isSaved = false),
            ),
          ),
        ],
      ),
    );
  }
}
