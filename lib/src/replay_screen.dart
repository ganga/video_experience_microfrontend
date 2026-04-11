import 'package:flutter/material.dart';

import 'models.dart';

class ReplayScreen extends StatelessWidget {
  const ReplayScreen({
    super.key,
    required this.replay,
  });

  final VideoReplay replay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Replay')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Replay status: ${replay.status}'),
            const SizedBox(height: 8),
            Text('Playback URL: ${replay.playbackUrl ?? 'Unavailable'}'),
          ],
        ),
      ),
    );
  }
}
