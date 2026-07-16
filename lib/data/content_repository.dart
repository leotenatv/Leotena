import '../models/models.dart';
import 'api_client.dart';

class ContentResult {
  final List<Channel> channels;
  final List<Movie> movies;
  const ContentResult({required this.channels, required this.movies});
}

/// All the read-only calls the consumer app needs, plus device
/// registration/status (the only writes this app ever makes).
class ContentRepository {
  final ApiClient client;
  ContentRepository(this.client);

  /// Single `/channels` fetch, split client-side: `category == 'movies'`
  /// entries become [Movie]s (with VOD metadata), everything else stays a
  /// [Channel] (live TV).
  Future<ContentResult> fetchChannelsAndMovies() async {
    final raw = await client.get('/channels') as List<dynamic>;
    final channels = <Channel>[];
    final movies = <Movie>[];
    for (final item in raw) {
      final json = item as Map<String, dynamic>;
      if (json['category'] == 'movies') {
        movies.add(Movie.fromJson(json));
      } else {
        channels.add(Channel.fromJson(json));
      }
    }
    return ContentResult(channels: channels, movies: movies);
  }

  Future<List<ScheduleItem>> fetchSchedule() async {
    final raw = await client.get('/schedule') as List<dynamic>;
    return raw.map((e) => ScheduleItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<SubscriptionPackage>> fetchPackages() async {
    final raw = await client.get('/pricing') as List<dynamic>;
    return raw.map((e) => SubscriptionPackage.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<String> fetchSupportWhatsApp() async {
    final res = await client.get('/settings');
    return res['supportWhatsApp'] as String;
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
}
