import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/notification_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService();
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final notifications = await _notificationService.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markAllAsRead() async {
    await _notificationService.markAllAsRead();
    await _loadNotifications();
  }

  Future<void> _deleteAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('알림 전체 삭제'),
        content: const Text('모든 알림을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _notificationService.deleteAllNotifications();
      await _loadNotifications();
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.chat_bubble;
      case 'stamp':
        return Icons.verified;
      case 'badge':
        return Icons.emoji_events;
      case 'notice':
        return Icons.campaign;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'like':
        return Colors.red;
      case 'comment':
        return Colors.blue;
      case 'stamp':
        return AppColors.primary;
      case 'badge':
        return Colors.amber;
      case 'notice':
        return Colors.green;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatTime(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${date.month}/${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('알림'),
        actions: [
          if (_notifications.isNotEmpty) ...[
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('모두 읽음', style: TextStyle(fontSize: 13)),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 22),
              onPressed: _deleteAll,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off_outlined,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('알림이 없습니다',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.separated(
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final noti = _notifications[index];
                      final isRead = noti['is_read'] == true;
                      final type = noti['type'] ?? '';

                      return Dismissible(
                        key: Key(noti['id'].toString()),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) async {
                          await _notificationService
                              .deleteNotification(noti['id'].toString());
                          setState(() => _notifications.removeAt(index));
                        },
                        child: ListTile(
                          tileColor: isRead ? null : AppColors.primary.withOpacity(0.05),
                          leading: CircleAvatar(
                            backgroundColor:
                                _getNotificationColor(type).withOpacity(0.1),
                            child: Icon(
                              _getNotificationIcon(type),
                              color: _getNotificationColor(type),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            noti['title'] ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  isRead ? FontWeight.normal : FontWeight.w600,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (noti['message'] != null)
                                Text(
                                  noti['message'],
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 2),
                              Text(
                                _formatTime(noti['created_at'] ?? ''),
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                          onTap: () async {
                            if (!isRead) {
                              await _notificationService
                                  .markAsRead(noti['id'].toString());
                              setState(() => noti['is_read'] = true);
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
