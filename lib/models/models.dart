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
  /// Audio language codes (`sw`, `en`). Nullable for hot-reload of older instances.
  final List<String>? languages;
  /// Real stream data, carried through for a future real player — the
  /// current player screen is still simulated and does not read these yet.
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
    this.languages,
    this.url = '',
    this.drm = ChannelDrm.none,
    this.clearKey = '',
  });

  /// Safe list — defaults to Kiswahili + English when missing (e.g. after hot reload).
  List<String> get audioLanguages {
    final langs = languages;
    if (langs == null || langs.isEmpty) return const ['sw', 'en'];
    return langs;
  }

  factory PlaybackSource.fromMovie(Movie m) {
    final langs = <String>{'sw'};
    final lang = m.language.toLowerCase();
    if (lang.contains('eng') || lang.contains('en')) langs.add('en');
    // Most Leotena titles ship with an English track as well.
    if (lang.contains('swahili') || lang.contains('kiswahili')) langs.add('en');
    return PlaybackSource(
      title: m.title,
      subtitle: 'Filamu • ${m.year}',
      gradient: m.gradient,
      isChannel: false,
      imageUrl: m.imageUrl,
      languages: langs.toList(),
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
        languages: const ['sw', 'en'],
        url: c.url,
        drm: c.drm,
        clearKey: c.clearKey,
      );
}
