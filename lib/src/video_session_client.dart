import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class VideoSessionClient {
  VideoSessionClient({required this.baseUrl, http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _httpClient;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<VideoSession> getSession(String sessionId) async {
    final response =
        await _httpClient.get(_uri('/v1/video/sessions/$sessionId'));
    if (response.statusCode != 200) {
      throw VideoClientException('Failed to load session', response.statusCode);
    }
    return VideoSession.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<VideoAccessGrant> createAccessGrant(
    String sessionId, {
    required Map<String, dynamic> request,
  }) async {
    final response = await _httpClient.post(
      _uri('/v1/video/sessions/$sessionId/access-grants'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode(request),
    );
    if (response.statusCode != 200) {
      throw VideoClientException(
        'Failed to create access grant',
        response.statusCode,
      );
    }
    return VideoAccessGrant.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<VideoReplay> getReplay(String replayId) async {
    final response = await _httpClient.get(_uri('/v1/video/replays/$replayId'));
    if (response.statusCode != 200) {
      throw VideoClientException('Failed to load replay', response.statusCode);
    }
    return VideoReplay.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}

class VideoClientException implements Exception {
  const VideoClientException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => 'VideoClientException($statusCode): $message';
}
