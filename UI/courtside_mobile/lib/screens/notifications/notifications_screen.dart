import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/translations.dart';
import '../../models/app_notification.dart';
import '../../providers/base_provider.dart';
import '../../providers/notification_provider.dart';
import '../../utils/util.dart';
import '../../providers/api_error.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _items = [];
  bool _loading = true;
  String? _error;
  StreamSubscription<AppNotification>? _live;

  @override
  void initState() {
    super.initState();
    _load();

    // The hub already pushes each notification the moment it is created; listening here
    // puts it at the top of an open list, so the screen shows the same thing the badge does.
    _live = context.read<NotificationProvider>().onNotification.listen((notification) {
      if (!mounted) return;
      setState(() => _items = [
            notification,
            ..._items.where((n) => n.id != notification.id),
          ]);
    });
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await context
          .read<NotificationProvider>()
          .get(filter: {'page': 1, 'pageSize': BaseProvider.maxPageSize});
      if (!mounted) return;
      setState(() => _items = result.result);
    } catch (e) {
      if (mounted) {
        final message = describeError(e);
        setState(() => _error = trMessage(context, message));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(AppNotification notification) async {
    if (notification.isRead) return;
    try {
      await context.read<NotificationProvider>().markRead(notification.id);
      if (!mounted) return;
      setState(() {
        final index = _items.indexWhere((n) => n.id == notification.id);
        if (index != -1) _items[index] = notification.copyWith(isRead: true);
      });
    } catch (_) {
      // Best-effort — the badge count will still refresh next time the list loads.
    }
  }

  Future<void> _markAllRead() async {
    try {
      await context.read<NotificationProvider>().markAllRead();
      if (!mounted) return;
      setState(() => _items = _items.map((n) => n.copyWith(isRead: true)).toList());
    } catch (e) {
      if (mounted) showError(context, describeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _items.any((n) => !n.isRead);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'Notifikacije')),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (hasUnread)
            IconButton(
              tooltip: tr(context, 'Označi sve kao pročitano'),
              icon: const Icon(Icons.done_all),
              onPressed: _markAllRead,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _load, child: Text(tr(context, 'Pokušaj ponovo'))),
                      ],
                    ),
                  ),
                )
              : _items.isEmpty
                  ? Center(child: Text(tr(context, 'Nema notifikacija.')))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _notificationCard(_items[i]),
                      ),
                    ),
    );
  }

  Widget _notificationCard(AppNotification notification) {
    return Card(
      elevation: 0,
      color: notification.isRead ? null : kPrimaryColor.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: notification.isRead ? Colors.grey.shade200 : kPrimaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: kPrimaryColor.withValues(alpha: 0.12),
          child: Icon(_iconForType(notification.type), color: kPrimaryColor),
        ),
        title: Text(tr(context, notification.title),
            style: TextStyle(fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(tr(context, notification.text)),
            const SizedBox(height: 4),
            Text(DateFormat('dd.MM.yyyy. HH:mm').format(notification.createdAt.toLocal()),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
        trailing: notification.isRead
            ? null
            : Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(color: kPrimaryColor, shape: BoxShape.circle),
              ),
        onTap: () => _open(notification),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'ReservationCreated':
      case 'ReservationConfirmed':
        return Icons.event_available_outlined;
      case 'ReservationCancelled':
        return Icons.event_busy_outlined;
      case 'ReservationCompleted':
        return Icons.check_circle_outline;
      case 'PaymentCompleted':
        return Icons.payments_outlined;
      case 'PaymentRefunded':
        return Icons.replay_outlined;
      case 'PaymentRefundPending':
        return Icons.hourglass_top_outlined;
      case 'PaymentRefundFailed':
        return Icons.money_off_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }
}
