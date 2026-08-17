import 'package:flutter/material.dart';
import '../data/admin_api_repository.dart';
import '../data/api_client.dart';
import '../models/admin_models.dart';

class AdminState extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  late final AdminApiRepository _repo = AdminApiRepository(_api);

  bool _loggedIn = false;
  bool _booting = true;
  String? _authError;
  String _section = 'dashboard';
  String _userQuery = '';
  String _channelQuery = '';
  AdminSettings _settings = const AdminSettings();

  List<PricingPlan> _pricingPlans = [];
  List<AdminChannel> _channels = [];
  List<AdminScheduleItem> _schedule = [];
  List<AdminCarouselSlide> _slides = [];
  List<AppUser> _users = [];
  List<SubscriptionRecord> _subscriptions = [];
  List<NotificationLog> _notifications = [];

  bool loadingChannels = false;
  bool loadingSchedule = false;
  bool loadingSlides = false;
  bool loadingPlans = false;
  bool loadingUsers = false;
  bool loadingSubscriptions = false;
  bool loadingNotifications = false;

  String? channelsError;
  String? scheduleError;
  String? slidesError;
  String? plansError;
  String? usersError;
  String? subscriptionsError;
  String? notificationsError;

  bool get loggedIn => _loggedIn;
  bool get booting => _booting;
  String? get authError => _authError;
  String get section => _section;
  String get userQuery => _userQuery;
  String get channelQuery => _channelQuery;
  String get supportWhatsApp => _settings.supportWhatsApp;
  AdminSettings get settings => _settings;
  List<PricingPlan> get pricingPlans => List.unmodifiable(_pricingPlans);
  List<AdminChannel> get channels => List.unmodifiable(_channels);
  List<AdminScheduleItem> get schedule => List.unmodifiable(_schedule);
  List<AppUser> get users => List.unmodifiable(_users);
  List<SubscriptionRecord> get subscriptions => List.unmodifiable(_subscriptions);
  List<NotificationLog> get notifications => List.unmodifiable(_notifications);

  List<AdminCarouselSlide> get slides {
    final list = List<AdminCarouselSlide>.from(_slides);
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  int get activePlansCount => _pricingPlans.where((p) => p.active).length;
  int get premiumUserCount => _users.where((u) => u.hasPremiumAccess).length;
  int get liveChannelCount => _channels.where((c) => c.live && c.active).length;
  int get successfulPaymentsCount => _subscriptions.where((s) => s.success).length;

  /// Tanzania (EAT, UTC+3) has no DST — daily revenue resets at local 00:00.
  static const Duration _eatOffset = Duration(hours: 3);

  DateTime get _eatNow => DateTime.now().toUtc().add(_eatOffset);

  bool _isTodayEat(DateTime? dt) {
    if (dt == null) return false;
    final eat = dt.toUtc().add(_eatOffset);
    final now = _eatNow;
    return eat.year == now.year && eat.month == now.month && eat.day == now.day;
  }

  /// Successful payment amounts for today only (EAT). Resets at 00:00.
  int get revenueTzs {
    var total = 0;
    for (final s in _subscriptions.where((s) => s.success && _isTodayEat(s.createdAt))) {
      total += int.tryParse(s.amount.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }
    return total;
  }

  String get revenueLabel {
    final total = revenueTzs;
    if (total >= 1000000) return 'TZS ${(total / 1000000).toStringAsFixed(1)}M';
    if (total >= 1000) return 'TZS ${(total / 1000).toStringAsFixed(1)}K';
    return 'TZS $total';
  }

  /// Recent successful payments for the dashboard feed (newest first, max 8).
  List<SubscriptionRecord> get recentPayments =>
      _subscriptions.where((s) => s.success).take(8).toList();

  /// Channels ranked by viewer count for analytics.
  List<AdminChannel> get topChannelsByViewers {
    final list = List<AdminChannel>.from(_channels)..sort((a, b) => b.viewers.compareTo(a.viewers));
    return list.take(8).toList();
  }

  // ── Auth / session ───────────────────────────────────────────
  Future<void> tryRestoreSession() async {
    _booting = true;
    notifyListeners();
    await _api.loadPersistedToken();
    if (_api.hasToken) {
      try {
        await _repo.me();
        _loggedIn = true;
        await bootstrap();
      } catch (_) {
        await _api.setToken(null);
        _loggedIn = false;
      }
    }
    _booting = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _authError = null;
    try {
      final token = await _repo.login(email.trim(), password);
      await _api.setToken(token);
      _loggedIn = true;
      await bootstrap();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _loggedIn = false;
      await _api.setToken(null);
      _authError = e.isAuthError ? 'Barua pepe au nenosiri sio sahihi' : 'Imeshindwa kuunganisha na seva: ${e.message}';
      notifyListeners();
      return false;
    } catch (e) {
      _loggedIn = false;
      await _api.setToken(null);
      _authError = 'Imeshindwa kuunganisha na seva (${ApiClient.baseUrl}): $e';
      notifyListeners();
      return false;
    }
  }

  void logout() {
    _api.setToken(null);
    _loggedIn = false;
    _section = 'dashboard';
    _pricingPlans = [];
    _channels = [];
    _schedule = [];
    _slides = [];
    _users = [];
    _subscriptions = [];
    _notifications = [];
    notifyListeners();
  }

  Future<void> bootstrap() async {
    await Future.wait([
      _loadSettings(),
      _loadChannels(),
      _loadSchedule(),
      _loadSlides(),
      _loadPlans(),
      _loadUsers(),
      _loadSubscriptions(),
      _loadNotifications(),
    ]);
  }

  Future<void> _loadSettings() async {
    try {
      _settings = await _repo.getSettings();
    } catch (_) {
      // keep the previous/default value
    }
  }

  Future<void> _loadChannels() async {
    loadingChannels = true;
    notifyListeners();
    try {
      _channels = await _repo.getChannels();
      channelsError = null;
    } on ApiException catch (e) {
      channelsError = e.message;
    } finally {
      loadingChannels = false;
      notifyListeners();
    }
  }

  Future<void> _loadSchedule() async {
    loadingSchedule = true;
    notifyListeners();
    try {
      _schedule = await _repo.getSchedule();
      scheduleError = null;
    } on ApiException catch (e) {
      scheduleError = e.message;
    } finally {
      loadingSchedule = false;
      notifyListeners();
    }
  }

  Future<void> _loadSlides() async {
    loadingSlides = true;
    notifyListeners();
    try {
      _slides = await _repo.getSlides();
      slidesError = null;
    } on ApiException catch (e) {
      slidesError = e.message;
    } finally {
      loadingSlides = false;
      notifyListeners();
    }
  }

  Future<void> _loadPlans() async {
    loadingPlans = true;
    notifyListeners();
    try {
      _pricingPlans = await _repo.getPricingPlans();
      plansError = null;
    } on ApiException catch (e) {
      plansError = e.message;
    } finally {
      loadingPlans = false;
      notifyListeners();
    }
  }

  Future<void> _loadUsers() async {
    loadingUsers = true;
    notifyListeners();
    try {
      _users = await _repo.getDevices();
      usersError = null;
    } on ApiException catch (e) {
      usersError = e.message;
    } finally {
      loadingUsers = false;
      notifyListeners();
    }
  }

  Future<void> _loadSubscriptions() async {
    loadingSubscriptions = true;
    notifyListeners();
    try {
      _subscriptions = await _repo.getSubscriptions();
      subscriptionsError = null;
    } on ApiException catch (e) {
      subscriptionsError = e.message;
    } finally {
      loadingSubscriptions = false;
      notifyListeners();
    }
  }

  Future<void> _loadNotifications() async {
    loadingNotifications = true;
    notifyListeners();
    try {
      _notifications = await _repo.getNotifications();
      notificationsError = null;
    } on ApiException catch (e) {
      notificationsError = e.message;
    } finally {
      loadingNotifications = false;
      notifyListeners();
    }
  }

  Future<void> updateSettings(AdminSettings settings) async {
    final digits = settings.supportWhatsApp.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9) {
      throw ApiException(400, 'Namba ya WhatsApp si sahihi');
    }
    _settings = await _repo.updateSettings(settings.copyWith(supportWhatsApp: digits));
    notifyListeners();
  }

  void setSection(String id) {
    _section = id;
    notifyListeners();
  }

  void setUserQuery(String q) {
    _userQuery = q;
    notifyListeners();
  }

  void setChannelQuery(String q) {
    _channelQuery = q;
    notifyListeners();
  }

  // ── Pricing (Bei) ──────────────────────────────────────────
  Future<void> addPlan(PricingPlan plan) async {
    final created = await _repo.createPricingPlan(plan);
    _pricingPlans = [..._pricingPlans, created];
    if (plan.popular) await setPopularPlan(created.id);
    notifyListeners();
  }

  Future<void> updatePlan(PricingPlan plan) async {
    final updated = await _repo.updatePricingPlan(plan);
    _pricingPlans = _pricingPlans.map((p) => p.id == updated.id ? updated : p).toList();
    if (plan.popular) await setPopularPlan(updated.id);
    notifyListeners();
  }

  Future<void> togglePlanActive(String id) async {
    final updated = await _repo.togglePlanActive(id);
    _pricingPlans = _pricingPlans.map((p) => p.id == id ? updated : p).toList();
    notifyListeners();
  }

  Future<void> setPopularPlan(String id) async {
    _pricingPlans = await _repo.setPopularPlan(id);
    notifyListeners();
  }

  Future<void> deletePlan(String id) async {
    await _repo.deletePlan(id);
    _pricingPlans = _pricingPlans.where((p) => p.id != id).toList();
    notifyListeners();
  }

  PricingPlan newPlanDraft() => const PricingPlan(
        id: '',
        name: '',
        price: '0',
        days: 7,
        note: '',
      );

  // ── Channels ───────────────────────────────────────────────
  Future<void> addChannel(AdminChannel c) async {
    final created = await _repo.createChannel(c);
    _channels = [..._channels, created];
    notifyListeners();
  }

  Future<void> updateChannel(AdminChannel c) async {
    final updated = await _repo.updateChannel(c);
    _channels = _channels.map((x) => x.id == updated.id ? updated : x).toList();
    notifyListeners();
  }

  Future<void> toggleChannelLive(String id) async {
    final updated = await _repo.toggleChannelLive(id);
    _channels = _channels.map((c) => c.id == id ? updated : c).toList();
    notifyListeners();
  }

  Future<void> toggleChannelPremium(String id) async {
    final updated = await _repo.toggleChannelPremium(id);
    _channels = _channels.map((c) => c.id == id ? updated : c).toList();
    notifyListeners();
  }

  Future<void> toggleChannelActive(String id) async {
    final updated = await _repo.toggleChannelActive(id);
    _channels = _channels.map((c) => c.id == id ? updated : c).toList();
    notifyListeners();
  }

  Future<void> deleteChannel(String id) async {
    await _repo.deleteChannel(id);
    _channels = _channels.where((c) => c.id != id).toList();
    notifyListeners();
  }

  /// Reorders the unfiltered channel list (drag-and-drop). Indices come from
  /// ReorderableListView's onReorderItem, which is already adjusted for the
  /// removed item at oldIndex.
  Future<void> reorderChannel(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _channels.length) return;
    if (newIndex < 0 || newIndex >= _channels.length) return;
    final list = List<AdminChannel>.from(_channels);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    _channels = list; // optimistic
    notifyListeners();
    _channels = await _repo.reorderChannels(list.map((c) => c.id).toList());
    notifyListeners();
  }

  AdminChannel newChannelDraft() => const AdminChannel(
        id: '',
        name: '',
        category: 'football',
        url: '',
        premium: true,
        viewers: 0,
        live: true,
      );

  // ── Schedule ───────────────────────────────────────────────
  Future<void> addScheduleItem(AdminScheduleItem item) async {
    final created = await _repo.createScheduleItem(item);
    _schedule = [..._schedule, created];
    notifyListeners();
  }

  Future<void> updateScheduleItem(AdminScheduleItem item) async {
    final updated = await _repo.updateScheduleItem(item);
    _schedule = _schedule.map((s) => s.id == updated.id ? updated : s).toList();
    notifyListeners();
  }

  Future<void> toggleScheduleActive(String id) async {
    final updated = await _repo.toggleScheduleActive(id);
    _schedule = _schedule.map((s) => s.id == id ? updated : s).toList();
    notifyListeners();
  }

  Future<void> deleteScheduleItem(String id) async {
    await _repo.deleteScheduleItem(id);
    _schedule = _schedule.where((s) => s.id != id).toList();
    notifyListeners();
  }

  AdminScheduleItem newScheduleDraft() {
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day, now.hour + 1);
    return AdminScheduleItem(
      id: '',
      dateTime: next,
      title: '',
      channel: _channels.isNotEmpty ? _channels.first.name : '',
      icon: Icons.live_tv_rounded,
    );
  }

  // ── Carousel ───────────────────────────────────────────────
  Future<void> addSlide(AdminCarouselSlide slide) async {
    final created = await _repo.createSlide(slide);
    _slides = [..._slides, created];
    notifyListeners();
  }

  Future<void> updateSlide(AdminCarouselSlide slide) async {
    final updated = await _repo.updateSlide(slide);
    _slides = _slides.map((s) => s.id == updated.id ? updated : s).toList();
    notifyListeners();
  }

  Future<void> toggleSlideActive(String id) async {
    final updated = await _repo.toggleSlideActive(id);
    _slides = _slides.map((s) => s.id == id ? updated : s).toList();
    notifyListeners();
  }

  /// Reorders slides (drag-and-drop). Indices come from ReorderableListView's
  /// onReorderItem over the order-sorted [slides] list.
  Future<void> reorderSlide(int oldIndex, int newIndex) async {
    final sorted = List<AdminCarouselSlide>.from(slides);
    if (oldIndex < 0 || oldIndex >= sorted.length) return;
    if (newIndex < 0 || newIndex >= sorted.length) return;
    final item = sorted.removeAt(oldIndex);
    sorted.insert(newIndex, item);
    _slides = await _repo.reorderSlides(sorted.map((s) => s.id).toList());
    notifyListeners();
  }

  Future<void> deleteSlide(String id) async {
    await _repo.deleteSlide(id);
    _slides = _slides.where((s) => s.id != id).toList();
    notifyListeners();
  }

  AdminCarouselSlide newSlideDraft() => AdminCarouselSlide(
        id: '',
        title: '',
        imageUrl: '',
        order: _slides.length,
      );

  // ── Users / Devices (Watumiaji) ──────────────────────────────
  Future<void> addUser(AppUser u) async {
    final created = await _repo.createDevice(u);
    _users = [..._users, created];
    notifyListeners();
  }

  Future<void> updateUser(AppUser u) async {
    final updated = await _repo.updateDevice(u);
    _users = _users.map((x) => x.id == updated.id ? updated : x).toList();
    notifyListeners();
  }

  Future<void> toggleUserActive(String id) async {
    final updated = await _repo.toggleDeviceActive(id);
    _users = _users.map((u) => u.id == id ? updated : u).toList();
    notifyListeners();
  }

  Future<void> deleteUser(String id) async {
    await _repo.deleteDevice(id);
    _users = _users.where((u) => u.id != id).toList();
    notifyListeners();
  }

  /// Grant or extend premium for a user (minutes, hours, days, weeks).
  /// The server extends from the existing expiry if still active, else from
  /// now, and records a SubscriptionRecord audit row as a side effect.
  Future<void> grantPremium(String userId, int amount, PremiumDurationUnit unit) async {
    if (amount <= 0) return;
    final updated = await _repo.grantPremium(userId, amount, unit);
    _users = _users.map((u) => u.id == userId ? updated : u).toList();
    notifyListeners();
    await _loadSubscriptions();
  }

  Future<void> revokePremium(String userId) async {
    final updated = await _repo.revokePremium(userId);
    _users = _users.map((u) => u.id == userId ? updated : u).toList();
    notifyListeners();
  }

  AppUser? userById(String id) {
    for (final u in _users) {
      if (u.id == id) return u;
    }
    return null;
  }

  AppUser newUserDraft() => AppUser(
        id: '',
        name: '',
        phone: '',
        deviceId: 'LT-${DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase().substring(0, 8)}',
        plan: UserPlan.free,
        joined: '',
      );

  // ── Subscriptions ──────────────────────────────────────────
  Future<void> deleteSubscription(String id) async {
    await _repo.deleteSubscription(id);
    _subscriptions = _subscriptions.where((s) => s.id != id).toList();
    notifyListeners();
  }

  // ── Notifications (Arifa) ───────────────────────────────────
  Future<void> sendNotification(String title, String body) async {
    final log = await _repo.sendNotification(title, body);
    _notifications = [log, ..._notifications];
    notifyListeners();
  }

  Future<void> deleteNotification(String id) async {
    await _repo.deleteNotification(id);
    _notifications = _notifications.where((n) => n.id != id).toList();
    notifyListeners();
  }

  AdminNavItem? sectionMeta(List<AdminNavItem> items) {
    for (final item in items) {
      if (item.id == _section) return item;
    }
    return null;
  }
}
