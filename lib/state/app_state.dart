import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../data/api_client.dart';
import '../data/content_repository.dart';
import '../data/payment_config.dart';
import '../data/sonicpesa_payment_service.dart';
import '../models/models.dart';

/// Central app state (MVVM view-model / state management via ChangeNotifier).
///
/// Holds subscription status, favorites, the currently playing source and the
/// active live channel. All content (movies/channels/schedule/pricing) is
/// fetched from the backend on [bootstrap]; the admin panel is the only
/// place that data is ever written. Entitlement (premium/expiry) is likewise
/// server truth, refreshed via [refreshDeviceStatus].
class AppState extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  late final ContentRepository _repo = ContentRepository(_api);
  final SonicpesaPaymentService _sonicPay = SonicpesaPaymentService();

  /// Silent background refresh so admin changes show up without a restart.
  static const _autoRefreshInterval = Duration(seconds: 30);
  Timer? _autoRefreshTimer;
  bool _refreshing = false;

  // ---- Account ----
  bool _subscribed = false; // new users start FREE
  DateTime _subEnd = DateTime(2026, 12, 12, 23, 59, 59);
  String _userName = 'Mtumiaji';
  String _phoneNumber = '';
  String? _deviceId;

  /// Support WhatsApp number (digits with country code). Fetched at boot.
  String _supportWhatsApp = '255712345678';

  List<SubscriptionPackage> _packages = [];
  SubscriptionPackage? _pendingPackage;
  bool _awaitingPaymentConfirmation = false;

  // ---- Content (fetched from the backend; admin is the only writer) ----
  List<Movie> _movies = [];
  List<Channel> _channels = [];
  List<ScheduleItem> _schedule = [];
  List<CarouselBanner> _banners = [];
  bool loadingContent = true;
  String? contentError;

  bool get subscribed {
    if (!_subscribed) return false;
    // Lock again the moment the purchased period ends (server also refreshes this).
    return _subEnd.isAfter(DateTime.now());
  }
  DateTime get subEnd => _subEnd;
  String get userName => _userName;
  String get phoneNumber => _phoneNumber;
  String get supportWhatsApp => _supportWhatsApp;
  List<SubscriptionPackage> get packages => List.unmodifiable(_packages);
  SubscriptionPackage? get pendingPackage => _pendingPackage;
  bool get awaitingPaymentConfirmation => _awaitingPaymentConfirmation;
  String get userInitial =>
      _userName.trim().isEmpty ? 'M' : _userName.trim()[0].toUpperCase();
  /// Stable per-install identifier, generated once and persisted. Empty
  /// until [ensureDeviceRegistered] has run once at boot.
  String get deviceId => _deviceId ?? '';

  List<Movie> get movies => List.unmodifiable(_movies);
  List<Channel> get channels => List.unmodifiable(_channels);
  List<ScheduleItem> get schedule => List.unmodifiable(_schedule);
  List<CarouselBanner> get banners => List.unmodifiable(_banners);

  // ---- Curated home-screen rows from admin-saved API data ----
  List<Channel> get freeChannels =>
      _channels.where((c) => !c.premium).toList();

  List<Channel> channelsByCategory(String category) =>
      _channels.where((c) => c.category == category).toList();

  List<Movie> moviesByCategory(String category) =>
      _movies.where((m) => m.category == category).toList();

  List<Movie> get newlyAdded => List<Movie>.from(_movies).reversed.toList();

  List<Movie> get premiumFilms => _movies.where((m) => m.premium).toList();

  List<Movie> get topRated {
    final sorted = List<Movie>.from(_movies)
      ..sort((a, b) => (double.tryParse(b.rating) ?? 0).compareTo(double.tryParse(a.rating) ?? 0));
    return sorted;
  }

  List<Movie> related(String excludeId) =>
      _movies.where((m) => m.id != excludeId).toList();

  /// Resolve a carousel slide to a playable movie (title match), if any.
  Movie? movieForBanner(CarouselBanner banner) {
    final title = banner.title.trim().toLowerCase();
    for (final m in _movies) {
      if (m.title.trim().toLowerCase() == title) return m;
    }
    return null;
  }

  Duration get remaining {
    final d = _subEnd.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  // ---- Bootstrap ----
  /// Fetches everything the home/search/ratiba/pricing screens show. Called
  /// once from splash_screen.dart before the app navigates in.
  Future<void> bootstrap() async {
    loadingContent = true;
    contentError = null;
    notifyListeners();
    try {
      await _loadContent();
      _startAutoRefresh();
    } on ApiException catch (e) {
      contentError = e.message;
    } finally {
      loadingContent = false;
      notifyListeners();
    }
  }

  /// Pull-to-refresh / auto-poll entry point. Does not flip [loadingContent]
  /// so the UI stays put while data quietly updates.
  Future<void> refreshContent() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      await _loadContent();
      await refreshDeviceStatus();
    } on ApiException {
      // Keep last known content on transient failures.
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  Future<void> _loadContent() async {
    final results = await Future.wait([
      _repo.fetchChannelsAndMovies(),
      _repo.fetchCarousel(),
      _repo.fetchSchedule(),
      _repo.fetchPackages(),
      _repo.fetchSupportWhatsApp(),
    ]);
    final content = results[0] as ContentResult;
    _channels = content.channels;
    _movies = content.movies;
    _banners = results[1] as List<CarouselBanner>;
    _schedule = results[2] as List<ScheduleItem>;
    final pkgs = results[3] as List<SubscriptionPackage>;
    if (pkgs.isNotEmpty) _packages = pkgs;
    _supportWhatsApp = results[4] as String;
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      refreshContent();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  /// Generates (once) and persists a stable per-install device id, then
  /// registers/refreshes it with the backend. Safe to call every boot.
  Future<void> ensureDeviceRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('device_id');
    if (id == null) {
      id = 'LT-${const Uuid().v4()}';
      await prefs.setString('device_id', id);
    }
    _deviceId = id;
    notifyListeners();
    try {
      final res = await _repo.registerDevice(id, name: _userName, phone: _phoneNumber);
      _applyDeviceStatus(res);
    } catch (_) {
      // Offline/first-run failure is non-fatal — stays on local FREE state.
    }
    unawaited(_registerForPush(id));
  }

  /// Requests notification permission and registers this device's FCM token
  /// with the backend so admin broadcasts (see leoadmin's "Arifa") reach it.
  /// Best-effort: permission denial or a token fetch failure is non-fatal.
  Future<void> _registerForPush(String id) async {
    try {
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _repo.updateFcmToken(id, token);
      FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        _repo.updateFcmToken(id, t).catchError((_) {});
      });
    } catch (_) {
      // No Google Play services, permission denied, etc. — notifications
      // just won't arrive; the rest of the app is unaffected.
    }
  }

  /// Re-fetches this device's status from the server. Called at boot,
  /// whenever the account screen opens, and on each content auto-refresh.
  Future<void> refreshDeviceStatus() async {
    final id = _deviceId;
    if (id == null) return;
    try {
      final res = await _repo.fetchDeviceStatus(id);
      _applyDeviceStatus(res);
    } catch (_) {
      // Transient failure — keep last known state.
    }
  }

  void _applyDeviceStatus(Map<String, dynamic> json) {
    final access = json['hasPremiumAccess'] as bool?;
    if (access != null) _subscribed = access;
    final premiumUntil = json['premiumUntil'] as String?;
    if (premiumUntil != null) {
      final until = DateTime.tryParse(premiumUntil);
      if (until != null) _subEnd = until;
    }
    // Expired entitlement must not keep channels unlocked.
    if (_subscribed && !_subEnd.isAfter(DateTime.now())) {
      _subscribed = false;
    }
    if (_subscribed) _awaitingPaymentConfirmation = false;
    final name = json['name'] as String?;
    final phone = json['phone'] as String?;
    if (name != null && name.isNotEmpty) _userName = name;
    if (phone != null && phone.isNotEmpty) _phoneNumber = phone;
    notifyListeners();
  }

  /// Unlocks all premium channels/movies for [until] (or [fallbackDays] from now/existing).
  void _unlockPremium({DateTime? until, int? fallbackDays}) {
    _subscribed = true;
    final now = DateTime.now();
    if (until != null && until.isAfter(now)) {
      _subEnd = until;
    } else if (fallbackDays != null && fallbackDays > 0) {
      final base = _subEnd.isAfter(now) ? _subEnd : now;
      _subEnd = base.add(Duration(days: fallbackDays));
    } else if (!_subEnd.isAfter(now)) {
      _subEnd = now.add(const Duration(days: 30));
    }
    _awaitingPaymentConfirmation = false;
    notifyListeners();
  }

  void setProfile({required String name, required String phone}) {
    _userName = name.trim().isEmpty ? 'Mtumiaji' : name.trim();
    _phoneNumber = phone.trim();
    notifyListeners();
    final id = _deviceId;
    if (id != null) {
      // Fire-and-forget: non-blocking UX, failure just means the admin
      // panel's Devices list won't see the new name/phone until next sync.
      _pushProfileUpdate(id);
    }
  }

  Future<void> _pushProfileUpdate(String id) async {
    try {
      await _repo.updateDeviceProfile(id, name: _userName, phone: _phoneNumber);
    } catch (_) {
      // non-blocking — ignore transient failures
    }
  }

  void submitPaymentPending(SubscriptionPackage pkg) {
    _pendingPackage = pkg;
    _awaitingPaymentConfirmation = true;
    notifyListeners();
  }

  /// Mock/manual-confirmation fallback (kept for admin-grant refresh paths).
  /// Real checkout uses [initiateSonicPayment] + [pollSonicPayment].
  void confirmPayment() {
    final pkg = _pendingPackage;
    if (pkg == null) return;
    _unlockPremium(fallbackDays: pkg.days);
  }

  void activatePackage(SubscriptionPackage pkg, {required String name, required String phone}) {
    _userName = name.trim().isEmpty ? 'Mtumiaji' : name.trim();
    _phoneNumber = phone.trim();
    _pendingPackage = pkg;
    _unlockPremium(fallbackDays: pkg.days);
  }

  /// Starts SonicPesa USSD push for [pkg]. Does not unlock premium until
  /// [pollSonicPayment] (or webhook) reports completion.
  Future<SonicpesaInitiateResult> initiateSonicPayment({
    required SubscriptionPackage pkg,
    required String name,
    required String phone,
  }) async {
    final id = _deviceId;
    if (id == null || id.isEmpty) {
      throw SonicpesaPaymentException('Kitambulisho cha kifaa hakipo. Anza upya programu.');
    }
    final trimmedName = name.trim().isEmpty ? 'Mtumiaji' : name.trim();
    final localPhone = PaymentConfig.normalizeTzLocalPhone(phone);
    if (localPhone == null) {
      throw SonicpesaPaymentException(
        'Weka namba ya simu sahihi: 07…, 06… (Halotel 061/062/063/069), au 255…',
      );
    }
    if (!PaymentConfig.isValidFullName(trimmedName)) {
      throw SonicpesaPaymentException('Tafadhali jaza jina kamili (angalau majina mawili).');
    }

    setProfile(name: trimmedName, phone: localPhone);
    submitPaymentPending(pkg);

    final init = await _sonicPay.initiate(
      deviceId: id,
      userName: trimmedName,
      phone: localPhone,
      planId: pkg.id,
    );

    // Local TSh 0 path completes in the initiate response — unlock immediately.
    if (init.completed) {
      DateTime? until = init.premiumUntil;
      if (init.deviceJson != null) {
        _applyDeviceStatus(init.deviceJson!);
        final rawUntil = init.deviceJson!['premiumUntil'] as String?;
        until ??= rawUntil != null ? DateTime.tryParse(rawUntil) : null;
      }
      _unlockPremium(until: until, fallbackDays: pkg.days);
      try {
        await refreshDeviceStatus();
      } catch (_) {}
      if (!subscribed) _unlockPremium(until: until, fallbackDays: pkg.days);
    }

    return init;
  }

  /// One status poll. On success, upgrades the account to premium for the
  /// purchased period and unlocks all premium channels/movies immediately.
  Future<SonicpesaStatusResult> pollSonicPayment({
    required String orderId,
    String? userName,
    String? phone,
  }) async {
    final id = _deviceId;
    if (id == null || id.isEmpty) {
      throw SonicpesaPaymentException('Kitambulisho cha kifaa hakipo. Anza upya programu.');
    }
    final status = await _sonicPay.checkStatus(
      deviceId: id,
      orderId: orderId,
      userName: userName ?? _userName,
      phone: phone ?? _phoneNumber,
    );
    if (status.completed) {
      DateTime? until = status.premiumUntil;
      if (status.deviceJson != null) {
        _applyDeviceStatus(status.deviceJson!);
        final rawUntil = status.deviceJson!['premiumUntil'] as String?;
        until ??= rawUntil != null ? DateTime.tryParse(rawUntil) : null;
      }
      // Always force local unlock so channel locks clear immediately, even if
      // a transient status payload omitted hasPremiumAccess.
      _unlockPremium(until: until, fallbackDays: _pendingPackage?.days);
      // Re-fetch server truth so countdown / admin panel stay in sync.
      try {
        await refreshDeviceStatus();
      } catch (_) {}
      if (!subscribed) {
        _unlockPremium(until: until, fallbackDays: _pendingPackage?.days);
      }
    }
    return status;
  }

  // ---- Favorites ----
  final Set<String> _favorites = {};
  bool isFavorite(String id) => _favorites.contains(id);
  void toggleFavorite(String id) {
    if (!_favorites.add(id)) _favorites.remove(id);
    notifyListeners();
  }

  // ---- Playback ----
  PlaybackSource? _nowPlaying;
  PlaybackSource? get nowPlaying => _nowPlaying;
  String? get nowChannelId => _nowPlaying?.channelId;

  void play(PlaybackSource source) {
    _nowPlaying = source;
    notifyListeners();
  }

  void stop() {
    _nowPlaying = null;
    notifyListeners();
  }

  /// Switch live channel from inside the player. Returns false if the
  /// channel is premium and the user is not subscribed (caller should then
  /// route to the payment screen).
  bool switchChannel(Channel c) {
    if (c.premium && !subscribed) return false;
    _nowPlaying = PlaybackSource.fromChannel(c);
    notifyListeners();
    return true;
  }

  bool channelLocked(Channel c) => c.premium && !subscribed;

  bool movieLocked(Movie m) => m.premium && !subscribed;

  Channel? get currentChannel {
    final id = nowChannelId;
    if (id == null) return null;
    for (final c in _channels) {
      if (c.id == id) return c;
    }
    return null;
  }
}
