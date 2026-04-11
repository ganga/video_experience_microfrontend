import 'package:flutter/material.dart';

import 'models.dart';
import 'video_experience_theme.dart';

class LiveSessionScreen extends StatelessWidget {
  const LiveSessionScreen({
    super.key,
    required this.session,
    required this.accessGrant,
  });

  final VideoSession session;
  final VideoAccessGrant accessGrant;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(session.title),
        actions: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: VideoExperienceTheme.danger,
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Text(
                  'Recording',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Live session scaffold',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Text('Room: ${session.roomName}'),
            Text('Role: ${accessGrant.role}'),
            const SizedBox(height: 16),
            Text('Audio publish: ${accessGrant.capabilities.publishAudio}'),
            Text('Video publish: ${accessGrant.capabilities.publishVideo}'),
            Text(
              'Screen share: ${accessGrant.capabilities.publishScreenShare}',
            ),
          ],
        ),
      ),
    );
  }
}
