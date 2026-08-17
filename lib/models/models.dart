import 'package:flutter/material.dart';
import '../utils/color_hex.dart';
import '../utils/icon_map.dart';

/// Domain models for Leotena.

/// DRM protection applied to a channel/movie's stream (data-only for now —
/// see PlaybackSource; the actual player is still a follow-up project).
enum ChannelDrm { none, widevine, clearkey }

/// Swahili labels for the category chips already defined inline in
/// home_screen.dart — kept here too so fetched Channel/Movie data can derive
/// a sensible `program` subtitle without touching that screen's layout.
const kCategoryLabels = <String, String>{
  'movies': 'Movies',
  'tamthilia': 'Tamthilia',
  'football': 'Football',
  'wanyama': 'Wanyama',
  'katuni': 'Katuni',
  'burudani': 'Burudani',
};

const kDefaultPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=com.ghettodevelopers.leotena';

const kDefaultMaintenanceMessage =
    'Programu iko katika matengenezo. Tafadhali rudi baadaye.';

const kDefaultForceUpdateMessage =
    'Toleo jipya la Leotena lipo. Tafadhali sasisha ili uendelee kutumia programu.';

/// Compare dotted version names like "11.5.6" vs "11.6.0". Negative if [a] < [b].
int compareAppVersions(String a, String b) {
  int part(String s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  final pa = a.split('.').map(part).toList();
  final pb = b.split('.').map(part).toList();
  final len = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < len; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

bool jsonBool(dynamic v, [bool fallback = false]) {
  if (v == true || v == 1 || v == 'true' || v == '1') return true;
  if (v == false || v == 0 || v == 'false' || v == '0') return false;
  return fallback;
}

class AppSettings {
  final String supportWhatsApp;
  final bool maintenanceMode;
  final String maintenanceMessage;
  final bool forceUpdateEnabled;
  final int minCodeVersion;
  final String minAppVersion;
  final String forceUpdateMessage;
  final String playStoreUrl;

  const AppSettings({
    this.supportWhatsApp = '255712345678',
    this.maintenanceMode = false,
    this.maintenanceMessage = '',
    this.forceUpdateEnabled = false,
    this.minCodeVersion = 0,
    this.minAppVersion = '',
    this.forceUpdateMessage = '',
    this.playStoreUrl = kDefaultPlayStoreUrl,
  });

  String get displayMaintenanceMessage =>
      maintenanceMessage.trim().isEmpty ? kDefaultMaintenanceMessage : maintenanceMessage.trim();

  String get displayForceUpdateMessage =>
      forceUpdateMessage.trim().isEmpty ? kDefaultForceUpdateMessage : forceUpdateMessage.trim();

  String get storeUrl => playStoreUrl.trim().isEmpty ? kDefaultPlayStoreUrl : playStoreUrl.trim();

  bool updateRequired({required String currentVersion, required int currentBuild}) {
    if (!forceUpdateEnabled) return false;
    final hasCodeFloor = minCodeVersion > 0;
    final hasNameFloor = minAppVersion.trim().isNotEmpty;
    if (!hasCodeFloor && !hasNameFloor) return false;
    var tooOld = false;
    if (hasCodeFloor) {
      // Unknown build while a floor is set → block (cannot prove this install is current).
      tooOld = currentBuild <= 0 || currentBuild < minCodeVersion;
    }
    if (hasNameFloor) {
      final name = currentVersion.trim();
      if (name.isEmpty || compareAppVersions(name, minAppVersion.trim()) < 0) tooOld = true;
    }
    return tooOld;
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        supportWhatsApp: json['supportWhatsApp'] as String? ?? '255712345678',
        maintenanceMode: jsonBool(json['maintenanceMode']),
        maintenanceMessage: json['maintenanceMessage'] as String? ?? '',
        forceUpdateEnabled: jsonBool(json['forceUpdateEnabled']),
        minCodeVersion: (json['minCodeVersion'] as num?)?.toInt() ??
            int.tryParse('${json['minCodeVersion'] ?? ''}') ??
            0,
        minAppVersion: json['minAppVersion'] as String? ?? '',
        forceUpdateMessage: json['forceUpdateMessage'] as String? ?? '',
        playStoreUrl: json['playStoreUrl'] as String? ?? kDefaultPlayStoreUrl,
      );
}

String initialsOf(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) return words.first.substring(0, words.first.length.clamp(0, 2)).toUpperCase();
  return (words[0][0] + words[1][0]).toUpperCase();
}

ChannelDrm _drmFromJson(String? value) => ChannelDrm.values.firstWhere(
      (d) => d.name.toUpperCase() == (value ?? 'NONE'),
      orElse: () => ChannelDrm.none,
    );

class Movie {
  final String id;
  final String title;
  final String category;
  final String genre;
  final String year;
  final String rating;
  final bool premium;
  final String duration;
  final String resolution;
  final String language;
  final String director;
  final List<String> genres;
  final String description;
  final List<Color> gradient;
  final String imageUrl;
  final String url;
  final ChannelDrm drm;
  final String clearKey;

  const Movie({
    required this.id,
    required this.title,
    required this.category,
    required this.genre,
    required this.year,
    required this.rating,
    required this.premium,
    required this.duration,
    required this.resolution,
    required this.language,
    required this.director,
    required this.genres,
    required this.description,
    required this.gradient,
    required this.imageUrl,
    this.url = '',
    this.drm = ChannelDrm.none,
    this.clearKey = '',
  });

  factory Movie.fromJson(Map<String, dynamic> json) => Movie(
        id: json['id'] as String,
        title: json['name'] as String? ?? '',
        category: json['category'] as String? ?? 'movies',
        genre: json['genre'] as String? ?? '',
        year: json['year'] as String? ?? '',
        rating: json['rating'] as String? ?? '',
        premium: json['premium'] as bool? ?? true,
        duration: json['duration'] as String? ?? '',
        resolution: json['resolution'] as String? ?? '',
        language: json['language'] as String? ?? '',
        director: json['director'] as String? ?? '',
        genres: (json['genres'] as List<dynamic>? ?? const []).map((e) => e as String).toList(),
        description: json['description'] as String? ?? '',
        gradient: gradientFromJson(json['gradient'] as List<dynamic>? ?? const []),
        imageUrl: json['imageUrl'] as String? ?? '',
        url: json['url'] as String? ?? '',
        drm: _drmFromJson(json['drm'] as String?),
        clearKey: json['clearKey'] as String? ?? '',
      );
}

/// Home hero slide curated in LeoAdmin (`GET /carousel`).
class CarouselBanner {
  final String id;
  final String title;
  final String imageUrl;
  final List<Color> gradient;
  final int order;

  const CarouselBanner({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.gradient,
    required this.order,
  });

  factory CarouselBanner.fromJson(Map<String, dynamic> json) => CarouselBanner(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        imageUrl: json['imageUrl'] as String? ?? '',
        gradient: gradientFromJson(json['gradient'] as List<dynamic>? ?? const []),
        order: json['order'] as int? ?? 0,
      );
}

class Channel {
  final String id;
  final String name;
  final String logo;
  final String program;
  final bool premium; // premium == requires "Malipo" (paid) subscription
  final String category; // zote / movies / tamthilia / football / wanyama / katuni / burudani
  final List<Color> gradient;
  final String imageUrl;
  final String url;
  final ChannelDrm drm;
  final String clearKey;

  const Channel({
    required this.id,
    required this.name,
    required this.logo,
    required this.program,
    required this.premium,
    required this.category,
    required this.gradient,
    required this.imageUrl,
    this.url = '',
    this.drm = ChannelDrm.none,
    this.clearKey = '',
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? '';
    final category = json['category'] as String? ?? 'burudani';
    return Channel(
      id: json['id'] as String,
      name: name,
      logo: initialsOf(name),
      program: kCategoryLabels[category] ?? category,
      premium: json['premium'] as bool? ?? true,
      category: category,
      gradient: gradientFromJson(json['gradient'] as List<dynamic>? ?? const []),
      imageUrl: json['imageUrl'] as String? ?? '',
      url: json['url'] as String? ?? '',
      drm: _drmFromJson(json['drm'] as String?),
      clearKey: json['clearKey'] as String? ?? '',
    );
  }
}

class SubscriptionPackage {
  final String id;
  final String name;
  final String price; // e.g. "2,000"
  final int days;
  final String note;
  final bool popular;

  const SubscriptionPackage({
    required this.id,
    required this.name,
    required this.price,
    required this.days,
    required this.note,
    this.popular = false,
  });

  factory SubscriptionPackage.fromJson(Map<String, dynamic> json) => SubscriptionPackage(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        price: json['price'] as String? ?? '0',
        days: json['days'] as int? ?? 7,
        note: json['note'] as String? ?? '',
        popular: json['popular'] as bool? ?? false,
      );
}

class ScheduleItem {
  final String time;
  final String ampm;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool live;
  final List<Color> gradient;
  /// Channel hosting this programme/match, set by admin (Vituo). Optional —
  /// display layout is unchanged; this is data plumbing only.
  final String? channel;
  /// Team names for a match entry. Both non-null/non-empty means it's a
  /// match rather than a plain programme or movie.
  final String? team1;
  final String? team2;
  /// Calendar date, in Tanzania (EAT) wall-clock time, set by admin.
  final DateTime? date;

  const ScheduleItem({
    required this.time,
    required this.ampm,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.live,
    required this.gradient,
    this.channel,
    this.team1,
    this.team2,
    this.date,
  });

  bool get isMatch => (team1?.isNotEmpty ?? false) && (team2?.isNotEmpty ?? false);

  /// [dt] is Tanzania (EAT) wall-clock time, encoded on the wire as a
  /// Z-suffixed ISO string WITHOUT real timezone conversion — its year/month/
  /// day/hour/minute fields are used exactly as sent, matching the admin
  /// side's `tzIsoString` convention.
  static String _periodLabel(DateTime dt) {
    final h = dt.hour;
    if (h >= 5 && h < 12) return 'asubuhi';
    if (h >= 12 && h < 16) return 'mchana';
    if (h >= 16 && h < 19) return 'jioni';
    return 'usiku';
  }

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    final dt = DateTime.parse(json['dateTime'] as String);
    return ScheduleItem(
      // Bare hour, no minutes — matches the original mock data's format
      // exactly, which the fixed-width time column in ratiba_screen.dart was
      // sized for (adding minutes risks visual overflow there).
      time: '${dt.hour}',
      ampm: _periodLabel(dt),
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      icon: iconFromKey(json['icon'] as String?),
      live: json['live'] as bool? ?? false,
      gradient: gradientFromJson(json['gradient'] as List<dynamic>? ?? const []),
      channel: json['channel'] as String? ?? '',
      team1: json['team1'] as String? ?? '',
      team2: json['team2'] as String? ?? '',
      date: dt,
    );
  }
}

/// What is currently loaded into the player — either a movie or a channel.
class PlaybackSource {
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final bool isChannel;
  final String? channelId;
  final String? imageUrl;
  /// Real stream data consumed by the Shaka web player.
  final String url;
  final ChannelDrm drm;
  final String clearKey;

  const PlaybackSource({
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.isChannel,
    this.channelId,
    this.imageUrl,
    this.url = '',
    this.drm = ChannelDrm.none,
    this.clearKey = '',
  });

  factory PlaybackSource.fromMovie(Movie m) {
    return PlaybackSource(
      title: m.title,
      subtitle: 'Filamu • ${m.year}',
      gradient: m.gradient,
      isChannel: false,
      imageUrl: m.imageUrl,
      url: m.url,
      drm: m.drm,
      clearKey: m.clearKey,
    );
  }

  factory PlaybackSource.fromChannel(Channel c) => PlaybackSource(
        title: c.name,
        subtitle: c.program,
        gradient: c.gradient,
        isChannel: true,
        channelId: c.id,
        imageUrl: c.imageUrl,
        url: c.url,
        drm: c.drm,
        clearKey: c.clearKey,
      );
}
