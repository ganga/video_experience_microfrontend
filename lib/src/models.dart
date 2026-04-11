class VideoCapabilitySet {
  const VideoCapabilitySet({
    required this.publishAudio,
    required this.publishVideo,
    required this.publishScreenShare,
    required this.subscribe,
    required this.manageRecording,
  });

  final bool publishAudio;
  final bool publishVideo;
  final bool publishScreenShare;
  final bool subscribe;
  final bool manageRecording;

  factory VideoCapabilitySet.fromJson(Map<String, dynamic> json) {
    return VideoCapabilitySet(
      publishAudio: json['publishAudio'] == true,
      publishVideo: json['publishVideo'] == true,
      publishScreenShare: json['publishScreenShare'] == true,
      subscribe: json['subscribe'] == true,
      manageRecording: json['manageRecording'] == true,
    );
  }
}

class VideoSession {
  const VideoSession({
    required this.id,
    required this.tenant,
    required this.sourceApp,
    required this.sessionType,
    required this.contextType,
    required this.contextId,
    required this.title,
    required this.status,
    required this.scheduledAt,
    required this.durationMinutes,
    required this.hostUserId,
    required this.roomMode,
    required this.roomName,
    required this.recordingPolicy,
    required this.createdAt,
    required this.updatedAt,
    this.description,
  });

  final String id;
  final String tenant;
  final String sourceApp;
  final String sessionType;
  final String contextType;
  final String contextId;
  final String title;
  final String? description;
  final String status;
  final String scheduledAt;
  final int durationMinutes;
  final String hostUserId;
  final String roomMode;
  final String roomName;
  final String recordingPolicy;
  final String createdAt;
  final String updatedAt;

  factory VideoSession.fromJson(Map<String, dynamic> json) {
    return VideoSession(
      id: json['id'] as String,
      tenant: json['tenant'] as String,
      sourceApp: json['sourceApp'] as String,
      sessionType: json['sessionType'] as String,
      contextType: json['contextType'] as String,
      contextId: json['contextId'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: json['status'] as String,
      scheduledAt: json['scheduledAt'] as String,
      durationMinutes: (json['durationMinutes'] as num).toInt(),
      hostUserId: json['hostUserId'] as String,
      roomMode: json['roomMode'] as String,
      roomName: json['roomName'] as String,
      recordingPolicy: json['recordingPolicy'] as String,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }
}

class VideoReplay {
  const VideoReplay({
    required this.replayId,
    required this.sessionId,
    required this.status,
    this.playbackUrl,
    this.downloadUrl,
    this.durationSeconds,
    this.availableAt,
    this.retentionExpiresAt,
  });

  final String replayId;
  final String sessionId;
  final String status;
  final String? playbackUrl;
  final String? downloadUrl;
  final int? durationSeconds;
  final String? availableAt;
  final String? retentionExpiresAt;

  factory VideoReplay.fromJson(Map<String, dynamic> json) {
    return VideoReplay(
      replayId: json['replayId'] as String,
      sessionId: json['sessionId'] as String,
      status: json['status'] as String,
      playbackUrl: json['playbackUrl'] as String?,
      downloadUrl: json['downloadUrl'] as String?,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      availableAt: json['availableAt'] as String?,
      retentionExpiresAt: json['retentionExpiresAt'] as String?,
    );
  }
}

class VideoAccessGrant {
  const VideoAccessGrant({
    required this.allowed,
    required this.sessionId,
    required this.role,
    required this.capabilities,
    this.token,
    this.expiresAt,
    this.denialReason,
  });

  final bool allowed;
  final String sessionId;
  final String role;
  final VideoCapabilitySet capabilities;
  final String? token;
  final String? expiresAt;
  final String? denialReason;

  factory VideoAccessGrant.fromJson(Map<String, dynamic> json) {
    return VideoAccessGrant(
      allowed: json['allowed'] == true,
      sessionId: json['sessionId'] as String,
      role: json['role'] as String,
      capabilities: VideoCapabilitySet.fromJson(
        json['capabilities'] as Map<String, dynamic>,
      ),
      token: json['token'] as String?,
      expiresAt: json['expiresAt'] as String?,
      denialReason: json['denialReason'] as String?,
    );
  }
}
