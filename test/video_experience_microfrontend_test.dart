import 'package:flutter_test/flutter_test.dart';
import 'package:video_experience_microfrontend/video_experience_microfrontend.dart';

void main() {
  test('video session model parses from json', () {
    final session = VideoSession.fromJson(const {
      'id': 'session-1',
      'tenant': 'edtec-dev',
      'sourceApp': 'edtec',
      'sessionType': 'class',
      'contextType': 'course',
      'contextId': '2',
      'title': 'Fractions Live Class',
      'status': 'scheduled',
      'scheduledAt': '2026-04-11T10:00:00Z',
      'durationMinutes': 45,
      'hostUserId': 'teacher-1',
      'roomMode': 'lecture',
      'roomName': 'edtec-class-1',
      'recordingPolicy': 'auto_start',
      'createdAt': '2026-04-11T09:00:00Z',
      'updatedAt': '2026-04-11T09:00:00Z',
    });

    expect(session.title, 'Fractions Live Class');
    expect(session.roomMode, 'lecture');
  });

  test('video access grant parses self-hosted livekit fields', () {
    final grant = VideoAccessGrant.fromJson(const {
      'allowed': true,
      'sessionId': 'session-1',
      'role': 'host',
      'serverUrl': 'ws://localhost:7880',
      'token': 'a.b.c',
      'capabilities': {
        'publishAudio': true,
        'publishVideo': true,
        'publishScreenShare': false,
        'subscribe': true,
        'manageRecording': true,
      },
    });

    expect(grant.serverUrl, 'ws://localhost:7880');
    expect(grant.token, 'a.b.c');
  });
}
