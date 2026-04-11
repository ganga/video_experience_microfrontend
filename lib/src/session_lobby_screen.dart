import 'package:flutter/material.dart';

import 'models.dart';
import 'video_experience_theme.dart';

class SessionLobbyScreen extends StatelessWidget {
  const SessionLobbyScreen({
    super.key,
    required this.session,
    this.onJoin,
  });

  final VideoSession session;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Session Lobby')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session.title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: VideoExperienceTheme.text,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              session.description ?? 'Join when you are ready.',
              style: const TextStyle(color: VideoExperienceTheme.muted),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onJoin,
              child: const Text('Join Session'),
            ),
          ],
        ),
      ),
    );
  }
}
