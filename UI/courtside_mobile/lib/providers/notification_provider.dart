import 'dart:async';

import 'package:signalr_netcore/signalr_client.dart';

import '../config/app_config.dart';
import '../models/app_notification.dart';
import '../utils/authorization.dart';
import 'base_provider.dart';

/// How often the unread count is re-checked over REST. The SignalR hub delivers
/// notifications the moment they happen; this is the safety net that keeps the badge
/// correct even if the socket is down (server restart, connection lost, sleep).
const _countRefreshInterval = Duration(seconds: 30);

/// Delay before rebuilding a connection that closed for good.
const _reconnectDelay = Duration(seconds: 10);

/// Notifications REST + a live SignalR connection to the same hub the backend pushes
/// to on reservation and payment events. The hub URL reuses [AppConfig] (same host as
/// the REST API, just outside the `/api` prefix) and the JWT already held in
/// [Authorization] authenticates the socket the same way it authenticates REST calls.
class NotificationProvider extends BaseProvider<AppNotification> {
  NotificationProvider() : super('notifications');

  @override
  AppNotification fromJson(Map<String, dynamic> json) => AppNotification.fromJson(json);

  int unreadCount = 0;
  HubConnection? _hub;
  Timer? _countTimer;
  Timer? _reconnectTimer;
  bool _connecting = false;

  /// Set while the user is signed in. Stops reconnect attempts after logout.
  bool _wanted = false;

  final _controller = StreamController<AppNotification>.broadcast();

  /// Emits every notification pushed live while the socket is connected, so an open
  /// notifications screen can prepend it without a manual refresh.
  Stream<AppNotification> get onNotification => _controller.stream;

  Future<void> refreshUnreadCount() async {
    final response = await http.get(Uri.parse('${BaseProvider.baseUrl}notifications/unread-count'),
        headers: createHeaders());
    if (isValidResponse(response)) {
      final count = int.tryParse(response.body) ?? 0;
      if (count != unreadCount) {
        unreadCount = count;
        notifyListeners();
      }
    }
  }

  Future<void> markRead(int id) async {
    final response = await http.put(Uri.parse('${BaseProvider.baseUrl}notifications/$id/read'),
        headers: createHeaders());
    isValidResponse(response);
    if (unreadCount > 0) unreadCount--;
    notifyListeners();
  }

  Future<void> markAllRead() async {
    final response = await http.put(Uri.parse('${BaseProvider.baseUrl}notifications/read-all'),
        headers: createHeaders());
    isValidResponse(response);
    unreadCount = 0;
    notifyListeners();
  }

  Future<void> connect() async {
    _wanted = true;
    _startCountRefresh();
    await _openSocket();
  }

  Future<void> _openSocket() async {
    if (!_wanted || _hub != null || _connecting) return;
    if (Authorization.token == null || Authorization.token!.isEmpty) return;
    _connecting = true;

    final hub = HubConnectionBuilder()
        .withUrl(
          '${AppConfig.serverBase}/hubs/notifications',
          options: HttpConnectionOptions(accessTokenFactory: () async => Authorization.token ?? ''),
        )
        .withAutomaticReconnect(retryDelays: [2000, 5000, 10000, 20000])
        .build();

    hub.on('ReceiveNotification', (arguments) {
      if (arguments == null || arguments.isEmpty) return;
      final notification = AppNotification.fromJson(arguments[0] as Map<String, dynamic>);
      unreadCount++;
      notifyListeners();
      _controller.add(notification);
    });

    // The built-in policy retries a handful of times and then stops for good, which
    // leaves the app permanently silent after a longer outage. Rebuilding the
    // connection here means it recovers on its own once the API is back.
    hub.onclose(({Exception? error}) {
      _hub = null;
      _scheduleReconnect();
    });

    try {
      await hub.start();
      _hub = hub;
      // Catch up on anything that arrived while the socket was down.
      await refreshUnreadCount();
    } catch (_) {
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  void _scheduleReconnect() {
    if (!_wanted || _reconnectTimer != null) return;
    _reconnectTimer = Timer(_reconnectDelay, () {
      _reconnectTimer = null;
      _openSocket();
    });
  }

  void _startCountRefresh() {
    _countTimer ??= Timer.periodic(_countRefreshInterval, (_) async {
      if (!_wanted) return;
      try {
        await refreshUnreadCount();
      } catch (_) {
        // Offline or the session ended; the next tick tries again.
      }
    });
  }

  Future<void> disconnect() async {
    _wanted = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _countTimer?.cancel();
    _countTimer = null;
    final hub = _hub;
    _hub = null;
    unreadCount = 0;
    await hub?.stop();
  }

  @override
  void dispose() {
    _wanted = false;
    _reconnectTimer?.cancel();
    _countTimer?.cancel();
    _hub?.stop();
    _controller.close();
    super.dispose();
  }
}
