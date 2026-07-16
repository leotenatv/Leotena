import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../data/api_client.dart';
import '../data/content_repository.dart';
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
  bool loadingContent = true;
  String? contentError;

  bool get subscribed => _subscribed;
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

  // ---- Curated home-screen rows, computed over live [movies] ----
  List<Movie> get banners => _movies.take(3).toList();
  List<Movie> get newlyAdded => _movies.reversed.take(4).toList();
  List<Movie> get premiumFilms => _movies.where((m) => m.premium).take(4).toList();
  List<Movie> get topRated {
    final sorted = List<Movie>.from(_movies)
      ..sort((a, b) => (double.tryParse(b.rating) ?? 0).compareTo(double.tryParse(a.rating) ?? 0));
    return sorted.take(4).toList();
  }

  List<Movie> get comedy =>
      _movies.where((m) => m.genre.toLowerCase().contains('vichekesho')).take(4).toList();
  List<Movie> get continueWatching => _movies.take(3).toList();
  List<Movie> related(String excludeId) =>
      _movies.where((m) => m.id != excludeId).take(5).toList();

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
      final content = await _repo.fetchChannelsAndMovies();
      _channels = content.channels;
      _movies = content.movies;
      _schedule = await _repo.fetchSchedule();
      final pkgs = await _repo.fetchPackages();
      if (pkgs.isNotEmpty) _packages = pkgs;
      _supportWhatsApp = await _repo.fetchSupportWhatsApp();
    } on ApiException catch (e) {
      contentError = e.message;
    } finally {
      loadingContent = false;
      notifyListeners();
    }
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
  }

  /// Re-fetches this device's status from the server. This is the explicit
  /// point through which an admin-granted premium becomes visible here (no
  /// background polling) — called at boot and whenever the account screen
  /// opens.
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
    _subscribed = json['hasPremiumAccess'] as bool? ?? _subscribed;
    final premiumUntil = json['premiumUntil'] as String?;
    if (premiumUntil != null) _subEnd = DateTime.parse(premiumUntil);
    final name = json['name'] as String?;
    final phone = json['phone'] as String?;
    if (name != null && name.isNotEmpty) _userName = name;
    if (phone != null && phone.isNotEmpty) _phoneNumber = phone;
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

  /// Mock/manual-confirmation flow (no real payment gateway — see project
  /// non-goals). Sets local optimistic state; real entitlement truth always
  /// comes from [refreshDeviceStatus] once admin grants access server-side.
  void confirmPayment() {
    final pkg = _pendingPackage;
    if (pkg == null) return;
    _subscribed = true;
    _subEnd = DateTime.now().add(Duration(days: pkg.days));
    _awaitingPaymentConfirmation = false;
    notifyListeners();
  }

  void activatePackage(SubscriptionPackage pkg, {required String name, required String phone}) {
    _subscribed = true;
    _subEnd = DateTime.now().add(Duration(days: pkg.days));
    _userName = name.trim().isEmpty ? 'Mtumiaji' : name.trim();
    _phoneNumber = phone.trim();
    _pendingPackage = pkg;
    _awaitingPaymentConfirmation = false;
    notifyListeners();
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
    if (c.premium && !_subscribed) return false;
    _nowPlaying = PlaybackSource.fromChannel(c);
    notifyListeners();
    return true;
  }

  bool channelLocked(Channel c) => c.premium && !_subscribed;

  Channel? get currentChannel {
    final id = nowChannelId;
    if (id == null) return null;
    for (final c in _channels) {
      if (c.id == id) return c;
    }
    return null;
  }
}
