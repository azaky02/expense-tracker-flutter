import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database.dart' hide Card;
import '../../../core/utils/currency.dart';
import 'people_providers.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Opening the list counts as reading it; the read marks sync to the server and other devices.
    Future.microtask(() => ref.read(ledgerRepositoryProvider).markAllRead());
  }

  String _text(BuildContext context, AppNotification n) => 'notifications.${n.type}'.tr(
        namedArgs: {'name': n.actorName ?? '', 'amount': n.amount == null ? '' : formatAmount(n.amount!)},
        context: context,
      );

  IconData _icon(String type) => switch (type) {
        'CONFIRMED' => Icons.check_circle_outline,
        'REJECTED' => Icons.cancel_outlined,
        'CANCELLED' => Icons.remove_circle_outline,
        'SETTLEMENT_RECEIVED' => Icons.payments_outlined,
        _ => Icons.mark_email_unread_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(notificationsProvider).value ?? const <AppNotification>[];
    return Scaffold(
      appBar: AppBar(title: Text('notifications.title'.tr(context: context))),
      body: items.isEmpty
          ? Center(child: Text('notifications.empty'.tr(context: context)))
          : ListView(
              children: [
                for (final n in items)
                  ListTile(
                    leading: Icon(_icon(n.type)),
                    title: Text(_text(context, n)),
                    subtitle: Text(DateFormat.yMd().add_Hm().format(n.createdAt.toLocal())),
                    onTap: n.entryId == null
                        ? null
                        : () async {
                            final personId = await ref.read(ledgerRepositoryProvider).personIdForEntry(n.entryId!);
                            if (personId != null && context.mounted) context.push('/people/$personId');
                          },
                  ),
              ],
            ),
    );
  }
}
