import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/color_hex.dart';
import '../utils/icon_map.dart';

/// Builds a Tanzania (EAT) wall-clock timestamp as a Z-suffixed ISO string
/// WITHOUT applying the running device's timezone offset — the numbers
/// travel to/from the server exactly as entered, always.
String tzIsoString(DateTime dt) {
  String p2(int v) => v.toString().padLeft(2, '0');
  return '${dt.year.toString().padLeft(4, '0')}-${p2(dt.month)}-${p2(dt.day)}T${p2(dt.hour)}:${p2(dt.minute)}:00.000Z';
}

enum UserPlan { free, premium }

enum PremiumDurationUnit { minutes, hours, days, weeks }

/// DRM protection applied to a channel's stream.
enum ChannelDrm { none, widevine, clearkey }

const kChannelDrmLabels = <ChannelDrm, String>{
  ChannelDrm.none: 'Hakuna',
  ChannelDrm.widevine: 'Widevine',
  ChannelDrm.clearkey: 'ClearKey',
};

/// Categories used on the Leotena user home chips.
const kChannelCategories = <String>[
  'football',
  'movies',
  'tamthilia',
  'katuni',
  'burudani',
  'wanyama',
];

const kCategoryLabels = <String, String>{
  'football': 'Football',
  'movies': 'Movies',
  'tamthilia': 'Tamthilia',
  'katuni': 'Katuni',
  'burudani': 'Burudani',
  'wanyama': 'Wanyama',
};

class DashboardStats {
  final int totalUsers;
  final int premiumUsers;
  final String revenueTzs;
  final String adRevenueTzs;
  final double userGrowthPct;
  final double premiumGrowthPct;
  final double revenueGrowthPct;

  const DashboardStats({
    required this.totalUsers,
    required this.premiumUsers,
    required this.revenueTzs,
    required this.adRevenueTzs,
    required this.userGrowthPct,
    required this.premiumGrowthPct,
    required this.revenueGrowthPct,
  });
}

class AppUser {
  final String id;
  final String name;
  final String phone;
  final String deviceId;
  final UserPlan plan;
  final String joined;
  final bool active;
  /// When premium access ends. Null = no timed grant (legacy / manual plan only).
  final DateTime? premiumUntil;

  const AppUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.deviceId,
    required this.plan,
    required this.joined,
    this.active = true,
    this.premiumUntil,
  });

  bool get hasPremiumAccess {
    if (premiumUntil != null) return premiumUntil!.isAfter(DateTime.now());
    return plan == UserPlan.premium;
  }

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        deviceId: json['deviceId'] as String? ?? '',
        plan: (json['plan'] as String?) == 'PREMIUM' ? UserPlan.premium : UserPlan.free,
        joined: json['createdAt'] != null
            ? DateFormat('MMM yyyy').format(DateTime.parse(json['createdAt'] as String).toLocal())
            : '',
        active: json['active'] as bool? ?? true,
        premiumUntil: json['premiumUntil'] != null ? DateTime.parse(json['premiumUntil'] as String) : null,
      );

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'name': name,
        'phone': phone,
        'active': active,
      };

  AppUser copyWith({
    String? name,
    String? phone,
    String? deviceId,
    UserPlan? plan,
    String? joined,
    bool? active,
    DateTime? premiumUntil,
    bool clearPremiumUntil = false,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      deviceId: deviceId ?? this.deviceId,
      plan: plan ?? this.plan,
      joined: joined ?? this.joined,
      active: active ?? this.active,
      premiumUntil: clearPremiumUntil ? null : (premiumUntil ?? this.premiumUntil),
    );
  }

  static String formatPremiumRemaining(DateTime? until, {UserPlan plan = UserPlan.free}) {
    if (until == null) {
      return plan == UserPlan.premium ? 'Premium' : 'Bure';
    }
    final diff = until.difference(DateTime.now());
    if (diff.isNegative) return 'Imeisha';
    if (diff.inMinutes < 60) return 'Dakika ${diff.inMinutes}';
    if (diff.inHours < 24) return 'Saa ${diff.inHours}';
    if (diff.inDays < 7) return 'Siku ${diff.inDays}';
    final weeks = diff.inDays ~/ 7;
    final days = diff.inDays % 7;
    if (days == 0) return 'Wiki $weeks';
    return 'Wiki $weeks, siku $days';
  }

  static Duration durationFrom(int amount, PremiumDurationUnit unit) {
    switch (unit) {
      case PremiumDurationUnit.minutes:
        return Duration(minutes: amount);
      case PremiumDurationUnit.hours:
        return Duration(hours: amount);
      case PremiumDurationUnit.days:
        return Duration(days: amount);
      case PremiumDurationUnit.weeks:
        return Duration(days: amount * 7);
    }
  }

  static String unitLabel(PremiumDurationUnit unit, {int amount = 1}) {
    switch (unit) {
      case PremiumDurationUnit.minutes:
        return amount == 1 ? 'Dakika' : 'Dakika';
      case PremiumDurationUnit.hours:
        return amount == 1 ? 'Saa' : 'Masaa';
      case PremiumDurationUnit.days:
        return amount == 1 ? 'Siku' : 'Siku';
      case PremiumDurationUnit.weeks:
        return amount == 1 ? 'Wiki' : 'Wiki';
    }
  }
}

class AdminChannel {
  final String id;
  final String name;
  final String category;
  final String url;
  final ChannelDrm drm;
  final String clearKey;
  final bool premium;
  final int viewers;
  final bool live;
  final bool active;
  final String imageUrl;
  final List<Color> gradient;

  // Legacy VOD metadata (kept on the model / API for older rows).
  // The channel editor no longer collects these — movies use the same
  // fields as tamthilia.
  final String? genre;
  final String? year;
  final String? rating;
  final String? duration;
  final String? resolution;
  final String? language;
  final String? director;
  final String? description;
  final List<String> genres;

  const AdminChannel({
    required this.id,
    required this.name,
    required this.category,
    this.url = '',
    this.drm = ChannelDrm.none,
    this.clearKey = '',
    required this.premium,
    required this.viewers,
    required this.live,
    this.active = true,
    this.imageUrl = '',
    this.gradient = const [Color(0xFF1D4A82), Color(0xFF2C6DB5)],
    this.genre,
    this.year,
    this.rating,
    this.duration,
    this.resolution,
    this.language,
    this.director,
    this.description,
    this.genres = const [],
  });

  factory AdminChannel.fromJson(Map<String, dynamic> json) => AdminChannel(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? 'football',
        url: json['url'] as String? ?? '',
        drm: ChannelDrm.values.firstWhere(
          (d) => d.name.toUpperCase() == (json['drm'] as String? ?? 'NONE'),
          orElse: () => ChannelDrm.none,
        ),
        clearKey: json['clearKey'] as String? ?? '',
        premium: json['premium'] as bool? ?? true,
        viewers: json['viewers'] as int? ?? 0,
        live: json['live'] as bool? ?? false,
        active: json['active'] as bool? ?? true,
        imageUrl: json['imageUrl'] as String? ?? '',
        gradient: gradientFromJson(json['gradient'] as List<dynamic>? ?? const []),
        genre: json['genre'] as String?,
        year: json['year'] as String?,
        rating: json['rating'] as String?,
        duration: json['duration'] as String?,
        resolution: json['resolution'] as String?,
        language: json['language'] as String?,
        director: json['director'] as String?,
        description: json['description'] as String?,
        genres: (json['genres'] as List<dynamic>? ?? const []).map((e) => e as String).toList(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        'url': url,
        'drm': drm.name.toUpperCase(),
        'clearKey': clearKey,
        'premium': premium,
        'viewers': viewers,
        'live': live,
        'active': active,
        'imageUrl': imageUrl,
        'gradient': gradientToJson(gradient),
        'genre': genre,
        'year': year,
        'rating': rating,
        'duration': duration,
        'resolution': resolution,
        'language': language,
        'director': director,
        'description': description,
        'genres': genres,
      };

  /// Up to two uppercase initials derived from [name], used for the avatar
  /// tile where an editable logo field would otherwise go.
  String get initials {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first.substring(0, words.first.length.clamp(0, 2)).toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  AdminChannel copyWith({
    String? name,
    String? category,
    String? url,
    ChannelDrm? drm,
    String? clearKey,
    bool? premium,
    int? viewers,
    bool? live,
    bool? active,
    String? imageUrl,
    List<Color>? gradient,
    String? genre,
    String? year,
    String? rating,
    String? duration,
    String? resolution,
    String? language,
    String? director,
    String? description,
    List<String>? genres,
  }) {
    return AdminChannel(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      url: url ?? this.url,
      drm: drm ?? this.drm,
      clearKey: clearKey ?? this.clearKey,
      premium: premium ?? this.premium,
      viewers: viewers ?? this.viewers,
      live: live ?? this.live,
      active: active ?? this.active,
      imageUrl: imageUrl ?? this.imageUrl,
      gradient: gradient ?? this.gradient,
      genre: genre ?? this.genre,
      year: year ?? this.year,
      rating: rating ?? this.rating,
      duration: duration ?? this.duration,
      resolution: resolution ?? this.resolution,
      language: language ?? this.language,
      director: director ?? this.director,
      description: description ?? this.description,
      genres: genres ?? this.genres,
    );
  }
}

/// A schedule entry ("kipindi"). If [team1] and [team2] are both set it's a
/// match ([isMatch]) and renders as team-vs-team; otherwise it's a plain
/// programme/movie shown by [title]. [dateTime] is always Tanzania (EAT)
/// wall-clock time — the app only ever targets that one timezone.
class AdminScheduleItem {
  final String id;
  final DateTime dateTime;
  final String title;
  final String subtitle;
  final String channel;
  final String team1;
  final String team2;
  final IconData icon;
  final bool live;
  final bool active;
  final List<Color> gradient;

  const AdminScheduleItem({
    required this.id,
    required this.dateTime,
    required this.title,
    this.subtitle = '',
    this.channel = '',
    this.team1 = '',
    this.team2 = '',
    required this.icon,
    this.live = false,
    this.active = true,
    this.gradient = const [Color(0xFF1D4A82), Color(0xFF2C6DB5)],
  });

  bool get isMatch => team1.isNotEmpty && team2.isNotEmpty;

  factory AdminScheduleItem.fromJson(Map<String, dynamic> json) => AdminScheduleItem(
        id: json['id'] as String,
        dateTime: DateTime.parse(json['dateTime'] as String),
        title: json['title'] as String? ?? '',
        subtitle: json['subtitle'] as String? ?? '',
        channel: json['channel'] as String? ?? '',
        team1: json['team1'] as String? ?? '',
        team2: json['team2'] as String? ?? '',
        icon: iconFromKey(json['icon'] as String?),
        live: json['live'] as bool? ?? false,
        active: json['active'] as bool? ?? true,
        gradient: gradientFromJson(json['gradient'] as List<dynamic>? ?? const []),
      );

  Map<String, dynamic> toJson() => {
        'dateTime': tzIsoString(dateTime),
        'title': title,
        'subtitle': subtitle,
        'channel': channel,
        'team1': team1,
        'team2': team2,
        'icon': keyFromIcon(icon),
        'live': live,
        'active': active,
        'gradient': gradientToJson(gradient),
      };

  AdminScheduleItem copyWith({
    DateTime? dateTime,
    String? title,
    String? subtitle,
    String? channel,
    String? team1,
    String? team2,
    IconData? icon,
    bool? live,
    bool? active,
    List<Color>? gradient,
  }) {
    return AdminScheduleItem(
      id: id,
      dateTime: dateTime ?? this.dateTime,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      channel: channel ?? this.channel,
      team1: team1 ?? this.team1,
      team2: team2 ?? this.team2,
      icon: icon ?? this.icon,
      live: live ?? this.live,
      active: active ?? this.active,
      gradient: gradient ?? this.gradient,
    );
  }

  /// Swahili day-period bucket for the leading time tile (asubuhi/mchana/…).
  static String periodLabel(DateTime dt) {
    final h = dt.hour;
    if (h >= 5 && h < 12) return 'asubuhi';
    if (h >= 12 && h < 16) return 'mchana';
    if (h >= 16 && h < 19) return 'jioni';
    return 'usiku';
  }

  static String timeLabel(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String dateLabel(DateTime dt) => '${dt.day} ${_months[dt.month - 1]}';
}

class AdminCarouselSlide {
  final String id;
  final String title;
  final String imageUrl;
  final int order;
  final bool active;
  final List<Color> gradient;

  const AdminCarouselSlide({
    required this.id,
    required this.title,
    this.imageUrl = '',
    required this.order,
    this.active = true,
    this.gradient = const [Color(0xFF0F2748), Color(0xFF19B26B)],
  });

  factory AdminCarouselSlide.fromJson(Map<String, dynamic> json) => AdminCarouselSlide(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        imageUrl: json['imageUrl'] as String? ?? '',
        order: json['order'] as int? ?? 0,
        active: json['active'] as bool? ?? true,
        gradient: gradientFromJson(json['gradient'] as List<dynamic>? ?? const []),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'imageUrl': imageUrl,
        'active': active,
        'gradient': gradientToJson(gradient),
      };

  AdminCarouselSlide copyWith({
    String? title,
    String? imageUrl,
    bool? active,
    int? order,
    List<Color>? gradient,
  }) {
    return AdminCarouselSlide(
      id: id,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      order: order ?? this.order,
      active: active ?? this.active,
      gradient: gradient ?? this.gradient,
    );
  }
}

class SubscriptionRecord {
  final String id;
  final String user;
  final String packageName;
  final String amount;
  final String date;
  final bool success;

  const SubscriptionRecord({
    required this.id,
    required this.user,
    required this.packageName,
    required this.amount,
    required this.date,
    required this.success,
  });

  factory SubscriptionRecord.fromJson(Map<String, dynamic> json) => SubscriptionRecord(
        id: json['id'] as String,
        user: json['user'] as String? ?? '',
        packageName: json['packageName'] as String? ?? '',
        amount: json['amount'] as String? ?? '',
        date: json['date'] != null
            ? DateFormat('MMM d, yyyy').format(DateTime.parse(json['date'] as String).toLocal())
            : '',
        success: json['success'] as bool? ?? true,
      );
}

class ActivityItem {
  final String title;
  final String subtitle;
  final String time;
  final Color color;

  const ActivityItem({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.color,
  });
}

class TopContentItem {
  final String title;
  final String subtitle;
  final String views;
  final double growthPct;
  final IconData icon;
  final List<Color> gradient;

  const TopContentItem({
    required this.title,
    required this.subtitle,
    required this.views,
    required this.growthPct,
    required this.icon,
    required this.gradient,
  });
}

class AdminNavItem {
  final String id;
  final String label;
  final IconData icon;

  const AdminNavItem(this.id, this.label, this.icon);
}

class PricingPlan {
  final String id;
  final String name;
  final String price;
  final int days;
  final String note;
  final bool popular;
  final bool active;
  final int subscribers;

  const PricingPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.days,
    required this.note,
    this.popular = false,
    this.active = true,
    this.subscribers = 0,
  });

  String get priceLabel => 'TSh $price';

  factory PricingPlan.fromJson(Map<String, dynamic> json) => PricingPlan(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        price: json['price'] as String? ?? '0',
        days: json['days'] as int? ?? 7,
        note: json['note'] as String? ?? '',
        popular: json['popular'] as bool? ?? false,
        active: json['active'] as bool? ?? true,
        subscribers: json['subscribers'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'price': price,
        'days': days,
        'note': note,
        'popular': popular,
        'active': active,
      };

  PricingPlan copyWith({
    String? name,
    String? price,
    int? days,
    String? note,
    bool? popular,
    bool? active,
    int? subscribers,
  }) {
    return PricingPlan(
      id: id,
      name: name ?? this.name,
      price: price ?? this.price,
      days: days ?? this.days,
      note: note ?? this.note,
      popular: popular ?? this.popular,
      active: active ?? this.active,
      subscribers: subscribers ?? this.subscribers,
    );
  }
}
