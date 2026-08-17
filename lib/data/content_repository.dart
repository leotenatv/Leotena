import '../models/models.dart';
import 'api_client.dart';

class ContentResult {
  final List<Channel> channels;
  final List<Movie> movies;
  const ContentResult({required this.channels, required this.movies});
}

/// True when the admin row is on-demand content (filamu) rather than a live
/// TV channel. Movies category always counts as VOD; also `/vod/` in the
/// stream URL, or legacy VOD metadata on older rows.
bool isVodChannelJson(Map<String, dynamic> json) {
  final category = (json['category'] as String? ?? '').toLowerCase();
  if (category == 'movies') return true;
  final url = (json['url'] as String? ?? '').toLowerCase();
  if (url.contains('/vod/')) return true;
  final genre = json['genre'] as String?;
  final description = json['description'] as String?;
  final year = json['year'] as String?;
  final duration = json['duration'] as String?;
  return (genre != null && genre.isNotEmpty) ||
      (description != null && description.isNotEmpty) ||
      (year != null && year.isNotEmpty) ||
      (duration != null && duration.isNotEmpty);
}

/// All the read-only calls the consumer app needs, plus device
/// registration/status (the only writes this app ever makes).
class ContentRepository {
  final ApiClient client;
  ContentRepository(this.client);

  /// Single `/channels` fetch, split client-side into live [Channel]s and
  /// on-demand [Movie]s (admin saves both in the same table).
  Future<ContentResult> fetchChannelsAndMovies() async {
    final raw = await client.get('/channels') as List<dynamic>;
    final channels = <Channel>[];
    final movies = <Movie>[];
    for (final item in raw) {
      final json = item as Map<String, dynamic>;
      if (isVodChannelJson(json)) {
        movies.add(Movie.fromJson(json));
      } else {
        channels.add(Channel.fromJson(json));
      }
    }
    return ContentResult(channels: channels, movies: movies);
  }

  Future<List<CarouselBanner>> fetchCarousel() async {
    final raw = await client.get('/carousel') as List<dynamic>;
    return raw.map((e) => CarouselBanner.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<ScheduleItem>> fetchSchedule() async {
    final raw = await client.get('/schedule') as List<dynamic>;
    return raw.map((e) => ScheduleItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<SubscriptionPackage>> fetchPackages() async {
    final raw = await client.get('/pricing') as List<dynamic>;
    return raw.map((e) => SubscriptionPackage.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AppSettings> fetchSettings() async {
    final res = await client.get('/settings');
    return AppSettings.fromJson(res as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> registerDevice(String deviceId, {String? name, String? phone}) async {
    final res = await client.post('/devices/register', body: {
      'deviceId': deviceId,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
    });
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchDeviceStatus(String deviceId) async {
    final res = await client.get('/devices/$deviceId');
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateDeviceProfile(String deviceId, {String? name, String? phone}) async {
    final res = await client.put('/devices/$deviceId/profile', body: {
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
    });
    return res as Map<String, dynamic>;
  }

  Future<void> updateFcmToken(String deviceId, String fcmToken) async {
    await client.put('/devices/$deviceId/fcm-token', body: {'fcmToken': fcmToken});
  }
}
