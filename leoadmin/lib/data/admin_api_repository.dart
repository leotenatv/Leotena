import '../models/admin_models.dart';
import 'api_client.dart';

/// One typed method per backend endpoint the admin panel needs. Screens
/// never talk to [ApiClient] directly — everything goes through [AdminState]
/// which in turn goes through here.
class AdminApiRepository {
  final ApiClient client;
  AdminApiRepository(this.client);

  // ── Auth ─────────────────────────────────────────────────
  Future<String> login(String email, String password) async {
    final res = await client.post('/auth/login', body: {'email': email, 'password': password});
    return res['token'] as String;
  }

  Future<void> me() => client.get('/auth/me');

  // ── Settings ─────────────────────────────────────────────
  Future<AdminSettings> getSettings() async {
    final res = await client.get('/settings');
    return AdminSettings.fromJson(res as Map<String, dynamic>);
  }

  Future<AdminSettings> updateSettings(AdminSettings settings) async {
    final res = await client.put('/admin/settings', body: settings.toJson());
    return AdminSettings.fromJson(res as Map<String, dynamic>);
  }

  // ── Channels ─────────────────────────────────────────────
  Future<List<AdminChannel>> getChannels() async {
    final res = await client.get('/admin/channels') as List<dynamic>;
    return res.map((e) => AdminChannel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AdminChannel> createChannel(AdminChannel c) async {
    final res = await client.post('/admin/channels', body: c.toJson());
    return AdminChannel.fromJson(res as Map<String, dynamic>);
  }

  Future<AdminChannel> updateChannel(AdminChannel c) async {
    final res = await client.put('/admin/channels/${c.id}', body: c.toJson());
    return AdminChannel.fromJson(res as Map<String, dynamic>);
  }

  Future<AdminChannel> toggleChannelLive(String id) async {
    final res = await client.patch('/admin/channels/$id/live');
    return AdminChannel.fromJson(res as Map<String, dynamic>);
  }

  Future<AdminChannel> toggleChannelPremium(String id) async {
    final res = await client.patch('/admin/channels/$id/premium');
    return AdminChannel.fromJson(res as Map<String, dynamic>);
  }

  Future<AdminChannel> toggleChannelActive(String id) async {
    final res = await client.patch('/admin/channels/$id/active');
    return AdminChannel.fromJson(res as Map<String, dynamic>);
  }

  Future<List<AdminChannel>> reorderChannels(List<String> orderedIds) async {
    final res = await client.patch('/admin/channels/reorder', body: {'orderedIds': orderedIds}) as List<dynamic>;
    return res.map((e) => AdminChannel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> deleteChannel(String id) => client.delete('/admin/channels/$id');

  // ── Schedule ─────────────────────────────────────────────
  Future<List<AdminScheduleItem>> getSchedule() async {
    final res = await client.get('/admin/schedule') as List<dynamic>;
    return res.map((e) => AdminScheduleItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AdminScheduleItem> createScheduleItem(AdminScheduleItem item) async {
    final res = await client.post('/admin/schedule', body: item.toJson());
    return AdminScheduleItem.fromJson(res as Map<String, dynamic>);
  }

  Future<AdminScheduleItem> updateScheduleItem(AdminScheduleItem item) async {
    final res = await client.put('/admin/schedule/${item.id}', body: item.toJson());
    return AdminScheduleItem.fromJson(res as Map<String, dynamic>);
  }

  Future<AdminScheduleItem> toggleScheduleActive(String id) async {
    final res = await client.patch('/admin/schedule/$id/active');
    return AdminScheduleItem.fromJson(res as Map<String, dynamic>);
  }

  Future<void> deleteScheduleItem(String id) => client.delete('/admin/schedule/$id');

  // ── Carousel ─────────────────────────────────────────────
  Future<List<AdminCarouselSlide>> getSlides() async {
    final res = await client.get('/admin/carousel') as List<dynamic>;
    return res.map((e) => AdminCarouselSlide.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AdminCarouselSlide> createSlide(AdminCarouselSlide s) async {
    final res = await client.post('/admin/carousel', body: s.toJson());
    return AdminCarouselSlide.fromJson(res as Map<String, dynamic>);
  }

  Future<AdminCarouselSlide> updateSlide(AdminCarouselSlide s) async {
    final res = await client.put('/admin/carousel/${s.id}', body: s.toJson());
    return AdminCarouselSlide.fromJson(res as Map<String, dynamic>);
  }

  Future<AdminCarouselSlide> toggleSlideActive(String id) async {
    final res = await client.patch('/admin/carousel/$id/active');
    return AdminCarouselSlide.fromJson(res as Map<String, dynamic>);
  }

  Future<List<AdminCarouselSlide>> reorderSlides(List<String> orderedIds) async {
    final res = await client.patch('/admin/carousel/reorder', body: {'orderedIds': orderedIds}) as List<dynamic>;
    return res.map((e) => AdminCarouselSlide.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> deleteSlide(String id) => client.delete('/admin/carousel/$id');

  // ── Pricing ──────────────────────────────────────────────
  Future<List<PricingPlan>> getPricingPlans() async {
    final res = await client.get('/admin/pricing') as List<dynamic>;
    return res.map((e) => PricingPlan.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PricingPlan> createPricingPlan(PricingPlan p) async {
    final res = await client.post('/admin/pricing', body: p.toJson());
    return PricingPlan.fromJson(res as Map<String, dynamic>);
  }

  Future<PricingPlan> updatePricingPlan(PricingPlan p) async {
    final res = await client.put('/admin/pricing/${p.id}', body: p.toJson());
    return PricingPlan.fromJson(res as Map<String, dynamic>);
  }

  Future<PricingPlan> togglePlanActive(String id) async {
    final res = await client.patch('/admin/pricing/$id/active');
    return PricingPlan.fromJson(res as Map<String, dynamic>);
  }

  Future<List<PricingPlan>> setPopularPlan(String id) async {
    final res = await client.patch('/admin/pricing/$id/popular') as List<dynamic>;
    return res.map((e) => PricingPlan.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> deletePlan(String id) => client.delete('/admin/pricing/$id');

  // ── Devices (Watumiaji) ──────────────────────────────────
  Future<List<AppUser>> getDevices() async {
    final res = await client.get('/admin/devices') as List<dynamic>;
    return res.map((e) => AppUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AppUser> createDevice(AppUser u) async {
    final res = await client.post('/admin/devices', body: u.toJson());
    return AppUser.fromJson(res as Map<String, dynamic>);
  }

  Future<AppUser> updateDevice(AppUser u) async {
    final res = await client.put('/admin/devices/${u.id}', body: u.toJson());
    return AppUser.fromJson(res as Map<String, dynamic>);
  }

  Future<AppUser> toggleDeviceActive(String id) async {
    final res = await client.patch('/admin/devices/$id/active');
    return AppUser.fromJson(res as Map<String, dynamic>);
  }

  Future<AppUser> grantPremium(String id, int amount, PremiumDurationUnit unit) async {
    final res = await client.post('/admin/devices/$id/grant-premium', body: {
      'amount': amount,
      'unit': unit.name,
    });
    return AppUser.fromJson(res as Map<String, dynamic>);
  }

  Future<AppUser> revokePremium(String id) async {
    final res = await client.post('/admin/devices/$id/revoke-premium');
    return AppUser.fromJson(res as Map<String, dynamic>);
  }

  Future<void> deleteDevice(String id) => client.delete('/admin/devices/$id');

  // ── Subscriptions ────────────────────────────────────────
  Future<List<SubscriptionRecord>> getSubscriptions() async {
    final res = await client.get('/admin/subscriptions') as List<dynamic>;
    return res.map((e) => SubscriptionRecord.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> deleteSubscription(String id) => client.delete('/admin/subscriptions/$id');

  // ── Notifications (Arifa) ────────────────────────────────
  Future<List<NotificationLog>> getNotifications() async {
    final res = await client.get('/admin/notifications') as List<dynamic>;
    return res.map((e) => NotificationLog.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<NotificationLog> sendNotification(String title, String body) async {
    final res = await client.post('/admin/notifications/send', body: {'title': title, 'body': body});
    return NotificationLog.fromJson(res as Map<String, dynamic>);
  }

  Future<void> deleteNotification(String id) => client.delete('/admin/notifications/$id');
}
