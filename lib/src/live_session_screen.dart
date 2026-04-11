import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import 'models.dart';
import 'video_experience_theme.dart';

class LiveSessionScreen extends StatefulWidget {
  const LiveSessionScreen({
    super.key,
    required this.session,
    required this.accessGrant,
  });

  final VideoSession session;
  final VideoAccessGrant accessGrant;

  @override
  State<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends State<LiveSessionScreen> {
  late final Room _room;
  bool _connecting = true;
  bool _connected = false;
  bool _cameraEnabled = false;
  bool _microphoneEnabled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _room = Room();
    unawaited(_connect());
  }

  @override
  void dispose() {
    unawaited(_room.disconnect());
    _room.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final serverUrl = widget.accessGrant.serverUrl;
    final token = widget.accessGrant.token;

    if (serverUrl == null || serverUrl.isEmpty || token == null || token.isEmpty) {
      setState(() {
        _connecting = false;
        _error = 'Missing LiveKit server URL or access token.';
      });
      return;
    }

    try {
      await _room.connect(
        serverUrl,
        token,
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );

      if (widget.accessGrant.capabilities.publishVideo) {
        await _room.localParticipant?.setCameraEnabled(true);
        _cameraEnabled = true;
      }
      if (widget.accessGrant.capabilities.publishAudio) {
        await _room.localParticipant?.setMicrophoneEnabled(true);
        _microphoneEnabled = true;
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _connecting = false;
        _connected = true;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _connecting = false;
        _connected = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _toggleCamera() async {
    final nextValue = !_cameraEnabled;
    try {
      await _room.localParticipant?.setCameraEnabled(nextValue);
      if (!mounted) {
        return;
      }
      setState(() {
        _cameraEnabled = nextValue;
      });
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _toggleMicrophone() async {
    final nextValue = !_microphoneEnabled;
    try {
      await _room.localParticipant?.setMicrophoneEnabled(nextValue);
      if (!mounted) {
        return;
      }
      setState(() {
        _microphoneEnabled = nextValue;
      });
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _leaveSession() async {
    await _room.disconnect();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _room,
      builder: (context, _) {
        final remoteParticipants = _room.remoteParticipants.values.toList();
        final localVideoTrack = _firstVideoTrack(_room.localParticipant);
        final remoteVideoTracks = remoteParticipants
            .map(_firstVideoTrack)
            .whereType<VideoTrack>()
            .toList();

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.session.title),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: VideoExperienceTheme.danger,
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Text(
                      _recordingBadgeText(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: _buildBody(
            localVideoTrack: localVideoTrack,
            remoteVideoTracks: remoteVideoTracks,
            remoteParticipants: remoteParticipants,
          ),
          bottomNavigationBar: _connected
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonal(
                            key: const Key('video.toggleMic'),
                            onPressed: widget.accessGrant.capabilities.publishAudio
                                ? _toggleMicrophone
                                : null,
                            child: Text(_microphoneEnabled ? 'Mute' : 'Unmute'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.tonal(
                            key: const Key('video.toggleCamera'),
                            onPressed: widget.accessGrant.capabilities.publishVideo
                                ? _toggleCamera
                                : null,
                            child: Text(_cameraEnabled ? 'Camera Off' : 'Camera On'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            key: const Key('video.leave'),
                            style: FilledButton.styleFrom(
                              backgroundColor: VideoExperienceTheme.danger,
                            ),
                            onPressed: _leaveSession,
                            child: const Text('Leave'),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildBody({
    required VideoTrack? localVideoTrack,
    required List<VideoTrack> remoteVideoTracks,
    required List<RemoteParticipant> remoteParticipants,
  }) {
    if (_connecting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 32, color: VideoExperienceTheme.danger),
              const SizedBox(height: 12),
              Text(
                'Live session could not connect',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SessionSummaryCard(
          role: widget.accessGrant.role,
          connectionState: _room.connectionState.name,
          roomName: widget.session.roomName,
          participantCount: remoteParticipants.length + (_connected ? 1 : 0),
        ),
        const SizedBox(height: 16),
        if (localVideoTrack != null) ...[
          const Text('Your camera', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _TrackTile(
            title: 'You',
            subtitle: widget.accessGrant.role,
            track: localVideoTrack,
          ),
          const SizedBox(height: 16),
        ],
        const Text('Participants', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (remoteVideoTracks.isEmpty)
          const _EmptyRemoteState()
        else
          ...remoteVideoTracks.map(
            (track) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TrackTile(
                title: 'Remote participant',
                subtitle: 'Subscribed video',
                track: track,
              ),
            ),
          ),
      ],
    );
  }

  String _recordingBadgeText() {
    return widget.session.recordingPolicy == 'off' ? 'Not Recording' : 'Recording';
  }

  VideoTrack? _firstVideoTrack(Participant? participant) {
    if (participant == null) {
      return null;
    }

    for (final publication in participant.videoTrackPublications) {
      final track = publication.track;
      if (track is VideoTrack) {
        return track;
      }
    }
    return null;
  }
}

class _SessionSummaryCard extends StatelessWidget {
  const _SessionSummaryCard({
    required this.role,
    required this.connectionState,
    required this.roomName,
    required this.participantCount,
  });

  final String role;
  final String connectionState;
  final String roomName;
  final int participantCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Role: $role'),
            const SizedBox(height: 4),
            Text('Connection: $connectionState'),
            const SizedBox(height: 4),
            Text('Room: $roomName'),
            const SizedBox(height: 4),
            Text('Participants: $participantCount'),
          ],
        ),
      ),
    );
  }
}

class _TrackTile extends StatelessWidget {
  const _TrackTile({
    required this.title,
    required this.subtitle,
    required this.track,
  });

  final String title;
  final String subtitle;
  final VideoTrack track;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ColoredBox(
        color: Colors.black,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: VideoTrackRenderer(
                track,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRemoteState extends StatelessWidget {
  const _EmptyRemoteState();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No remote participants are publishing video yet.',
        ),
      ),
    );
  }
}
