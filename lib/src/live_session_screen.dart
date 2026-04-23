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
  static const int _maxVisibleRemoteTiles = 6;
  static const CameraCaptureOptions _studentCameraOptions =
      CameraCaptureOptions(
    maxFrameRate: 15,
    params: VideoParametersPresets.h360_169,
  );
  static const CameraCaptureOptions _hostCameraOptions = CameraCaptureOptions(
    maxFrameRate: 24,
    params: VideoParametersPresets.h540_169,
  );

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

    if (serverUrl == null ||
        serverUrl.isEmpty ||
        token == null ||
        token.isEmpty) {
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
        connectOptions: const ConnectOptions(
          autoSubscribe: false,
        ),
        roomOptions: RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultCameraCaptureOptions: _cameraOptionsForRole(),
          defaultVideoPublishOptions: const VideoPublishOptions(
            simulcast: true,
            videoSimulcastLayers: [
              VideoParametersPresets.h180_169,
              VideoParametersPresets.h360_169,
            ],
          ),
        ),
      );

      if (widget.accessGrant.capabilities.publishVideo) {
        await _room.localParticipant?.setCameraEnabled(
          true,
          cameraCaptureOptions: _cameraOptionsForRole(),
        );
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
      unawaited(_applyVideoSubscriptionPolicy());
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
      await _room.localParticipant?.setCameraEnabled(
        nextValue,
        cameraCaptureOptions: _cameraOptionsForRole(),
      );
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

  CameraCaptureOptions _cameraOptionsForRole() {
    return widget.accessGrant.role == 'host'
        ? _hostCameraOptions
        : _studentCameraOptions;
  }

  Future<void> _applyVideoSubscriptionPolicy() async {
    final visibleParticipants = _visibleRemoteParticipants();
    final visibleIds =
        visibleParticipants.map((participant) => participant.sid).toSet();

    for (final participant in _room.remoteParticipants.values) {
      for (final publication in participant.audioTrackPublications) {
        await publication.subscribe();
      }

      final shouldSubscribe = visibleIds.contains(participant.sid);
      for (final publication in participant.videoTrackPublications) {
        if (shouldSubscribe) {
          await publication.subscribe();
        } else {
          await publication.unsubscribe();
        }
      }
    }
  }

  List<RemoteParticipant> _visibleRemoteParticipants() {
    final participants = _room.remoteParticipants.values.toList();
    participants.sort((left, right) {
      final leftRank = _participantPriority(left);
      final rightRank = _participantPriority(right);
      if (leftRank != rightRank) {
        return rightRank.compareTo(leftRank);
      }
      return left.joinedAt.compareTo(right.joinedAt);
    });
    return participants.take(_maxVisibleRemoteTiles).toList();
  }

  int _participantPriority(RemoteParticipant participant) {
    final metadata = participant.metadata?.toLowerCase() ?? '';
    var score = 0;
    if (metadata.contains('"role":"host"')) {
      score += 100;
    }
    if (!participant.isMuted) {
      score += 10;
    }
    if (participant.hasVideo) {
      score += 1;
    }
    return score;
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

  void _openFullscreen({
    required VideoTrack track,
    required String title,
    required String? subtitle,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullscreenVideoView(
          title: title,
          subtitle: subtitle,
          track: track,
        ),
      ),
    );
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
        final visibleRemoteParticipants = _visibleRemoteParticipants();
        unawaited(_applyVideoSubscriptionPolicy());
        final localVideoTrack = _firstVideoTrack(_room.localParticipant);
        final remoteVideoTracks = visibleRemoteParticipants
            .map(
              (participant) => _ParticipantVideoTrack(
                participant: participant,
                subtitle:
                    participant.isMuted ? 'Student video' : 'Active speaker',
                track: _firstVideoTrack(participant),
              ),
            )
            .where((item) => item.track != null)
            .toList();

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.session.title),
            actions: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _recordingBadgeColor(),
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ControlButton(
                          key: const Key('video.toggleMic'),
                          icon: _microphoneEnabled ? Icons.mic : Icons.mic_off,
                          label: _microphoneEnabled ? 'Mute' : 'Unmute',
                          onPressed:
                              widget.accessGrant.capabilities.publishAudio
                                  ? _toggleMicrophone
                                  : null,
                        ),
                        const SizedBox(width: 16),
                        _ControlButton(
                          key: const Key('video.toggleCamera'),
                          icon: _cameraEnabled
                              ? Icons.videocam
                              : Icons.videocam_off,
                          label: _cameraEnabled ? 'Camera Off' : 'Camera On',
                          onPressed:
                              widget.accessGrant.capabilities.publishVideo
                                  ? _toggleCamera
                                  : null,
                        ),
                        const SizedBox(width: 16),
                        _ControlButton(
                          key: const Key('video.leave'),
                          icon: Icons.call_end,
                          label: 'Leave',
                          danger: true,
                          onPressed: _leaveSession,
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
    required List<_ParticipantVideoTrack> remoteVideoTracks,
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
              const Icon(Icons.error_outline,
                  size: 32, color: VideoExperienceTheme.danger),
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

    final primaryTrack = remoteVideoTracks.isNotEmpty
        ? remoteVideoTracks.first
        : localVideoTrack == null
            ? null
            : _ParticipantVideoTrack(
                title: 'You',
                subtitle: widget.accessGrant.role,
                track: localVideoTrack,
              );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _SessionSummaryCard(
            role: widget.accessGrant.role,
            connectionState: _room.connectionState.name,
            roomName: widget.session.roomName,
            participantCount: remoteParticipants.length + (_connected ? 1 : 0),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: primaryTrack == null || primaryTrack.track == null
                ? const _EmptyVideoStage()
                : _VideoStage(
                    title: primaryTrack.title,
                    subtitle: primaryTrack.subtitle,
                    track: primaryTrack.track!,
                    onFullscreen: () => _openFullscreen(
                      title: primaryTrack.title,
                      subtitle: primaryTrack.subtitle,
                      track: primaryTrack.track!,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 104,
            child: _ThumbnailStrip(
              localVideoTrack: localVideoTrack,
              remoteVideoTracks: remoteVideoTracks,
              currentTrack: primaryTrack?.track,
              localRole: widget.accessGrant.role,
              onOpenFullscreen: _openFullscreen,
            ),
          ),
        ],
      ),
    );
  }

  String _recordingBadgeText() {
    if (widget.session.recordingPolicy == 'off') {
      return 'Not Recording';
    }
    switch (widget.session.status) {
      case 'live':
        return 'Recording Active';
      case 'recording_processing':
        return 'Recording Processing';
      case 'recording_available':
      case 'ended':
        return 'Recording Available';
      default:
        return 'Recording Enabled';
    }
  }

  Color _recordingBadgeColor() {
    if (widget.session.recordingPolicy == 'off') {
      return VideoExperienceTheme.muted;
    }
    switch (widget.session.status) {
      case 'live':
        return VideoExperienceTheme.danger;
      case 'recording_processing':
        return const Color(0xFFB54708);
      case 'recording_available':
      case 'ended':
        return VideoExperienceTheme.primary;
      default:
        return VideoExperienceTheme.muted;
    }
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

class _ParticipantVideoTrack {
  const _ParticipantVideoTrack({
    required this.track,
    this.participant,
    this.title = 'Remote participant',
    this.subtitle,
  });

  final RemoteParticipant? participant;
  final VideoTrack? track;

  final String title;
  final String? subtitle;
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final background = danger
        ? VideoExperienceTheme.danger
        : Theme.of(context).colorScheme.secondaryContainer;
    final foreground = danger
        ? Colors.white
        : Theme.of(context).colorScheme.onSecondaryContainer;

    return Tooltip(
      message: label,
      child: IconButton.filled(
        icon: Icon(icon),
        color: foreground,
        style: IconButton.styleFrom(
          backgroundColor: background,
          disabledBackgroundColor: VideoExperienceTheme.border,
          disabledForegroundColor: VideoExperienceTheme.muted,
          fixedSize: const Size.square(52),
        ),
        onPressed: onPressed,
      ),
    );
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Role: $role',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Connection: $connectionState',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Text('Participants: $participantCount'),
          ],
        ),
      ),
    );
  }
}

class _VideoStage extends StatelessWidget {
  const _VideoStage({
    required this.title,
    required this.subtitle,
    required this.track,
    required this.onFullscreen,
  });

  final String title;
  final String? subtitle;
  final VideoTrack track;
  final VoidCallback onFullscreen;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: VideoTrackRenderer(track),
              ),
            ),
            Positioned(
              left: 12,
              right: 72,
              bottom: 12,
              child: _VideoLabel(title: title, subtitle: subtitle),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: IconButton.filledTonal(
                tooltip: 'Full screen',
                icon: const Icon(Icons.fullscreen),
                onPressed: onFullscreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThumbnailStrip extends StatelessWidget {
  const _ThumbnailStrip({
    required this.localVideoTrack,
    required this.remoteVideoTracks,
    required this.currentTrack,
    required this.localRole,
    required this.onOpenFullscreen,
  });

  final VideoTrack? localVideoTrack;
  final List<_ParticipantVideoTrack> remoteVideoTracks;
  final VideoTrack? currentTrack;
  final String localRole;
  final void Function({
    required VideoTrack track,
    required String title,
    required String? subtitle,
  }) onOpenFullscreen;

  @override
  Widget build(BuildContext context) {
    final tiles = <_ParticipantVideoTrack>[
      if (localVideoTrack != null)
        _ParticipantVideoTrack(
          title: 'You',
          subtitle: localRole,
          track: localVideoTrack,
        ),
      ...remoteVideoTracks,
    ];

    if (tiles.isEmpty) {
      return const _EmptyRemoteState();
    }

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: tiles.length,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (context, index) {
        final tile = tiles[index];
        final track = tile.track;
        if (track == null) {
          return const SizedBox.shrink();
        }
        return _TrackThumbnail(
          title: tile.title,
          subtitle: tile.subtitle,
          track: track,
          selected: identical(track, currentTrack),
          onTap: () => onOpenFullscreen(
            title: tile.title,
            subtitle: tile.subtitle,
            track: track,
          ),
        );
      },
    );
  }
}

class _TrackThumbnail extends StatelessWidget {
  const _TrackThumbnail({
    required this.title,
    required this.subtitle,
    required this.track,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final VideoTrack track;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 168,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? VideoExperienceTheme.primary
                  : VideoExperienceTheme.border,
              width: selected ? 3 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColoredBox(
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  VideoTrackRenderer(track),
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: _VideoLabel(title: title, subtitle: subtitle),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoLabel extends StatelessWidget {
  const _VideoLabel({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.62),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          subtitle == null || subtitle!.isEmpty ? title : '$title • $subtitle',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _FullscreenVideoView extends StatelessWidget {
  const _FullscreenVideoView({
    required this.title,
    required this.subtitle,
    required this.track,
  });

  final String title;
  final String? subtitle;
  final VideoTrack track;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: VideoTrackRenderer(track),
              ),
            ),
            Positioned(
              left: 16,
              right: 80,
              bottom: 16,
              child: _VideoLabel(title: title, subtitle: subtitle),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton.filledTonal(
                tooltip: 'Exit full screen',
                icon: const Icon(Icons.fullscreen_exit),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyVideoStage extends StatelessWidget {
  const _EmptyVideoStage();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(
            'Waiting for video...',
            style: TextStyle(color: Colors.white70),
          ),
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
