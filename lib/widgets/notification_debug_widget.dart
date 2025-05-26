import 'package:flutter/material.dart';
import 'package:student_app/services/notification_service.dart';
import 'package:provider/provider.dart';

class NotificationDebugWidget extends StatefulWidget {
  const NotificationDebugWidget({super.key});

  @override
  State<NotificationDebugWidget> createState() =>
      _NotificationDebugWidgetState();
}

class _NotificationDebugWidgetState extends State<NotificationDebugWidget> {
  bool _isLoading = false;
  String _status = 'Press Check Status to debug notifications';
  Map<String, dynamic> _permissionsReport = {};

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Notification Troubleshooter',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(_status),
            const SizedBox(height: 16),
            if (_permissionsReport.isNotEmpty) ...[
              const Text(
                'Notification Status:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...buildReportItems(),
              const SizedBox(height: 16),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _checkStatus,
                  child: const Text('Check Status'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _refreshToken,
                  child: const Text('Refresh Token'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _requestPermissions,
                  child: const Text('Request Permissions'),
                ),
              ],
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> buildReportItems() {
    List<Widget> items = [];
    _permissionsReport.forEach((key, value) {
      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  key,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  value.toString(),
                  style: TextStyle(
                    color:
                        value == false || value.toString().contains('denied')
                            ? Colors.red
                            : Colors.green,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
    return items;
  }

  Future<void> _checkStatus() async {
    setState(() {
      _isLoading = true;
      _status = 'Checking notification status...';
    });

    try {
      final notificationService = Provider.of<NotificationService>(
        context,
        listen: false,
      );
      final report = await notificationService.checkNotificationPermissions();

      setState(() {
        _permissionsReport = report;
        _status = 'Status check completed';
      });
    } catch (e) {
      setState(() {
        _status = 'Error checking status: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshToken() async {
    setState(() {
      _isLoading = true;
      _status = 'Refreshing FCM token...';
    });

    try {
      final notificationService = Provider.of<NotificationService>(
        context,
        listen: false,
      );
      final token = await notificationService.refreshToken();

      setState(() {
        _status =
            token != null
                ? 'Token refreshed successfully'
                : 'Failed to refresh token';
      });

      // Check status after refresh
      await _checkStatus();
    } catch (e) {
      setState(() {
        _status = 'Error refreshing token: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _isLoading = true;
      _status = 'Requesting notification permissions...';
    });

    try {
      final notificationService = Provider.of<NotificationService>(
        context,
        listen: false,
      );

      // Request FCM permissions - use the proper method instead of accessing private field
      final fcm = await notificationService.requestNotificationPermissions();

      setState(() {
        _status = 'Permissions requested. Status: ${fcm.authorizationStatus}';
      });

      // Check status after requesting permissions
      await _checkStatus();
    } catch (e) {
      setState(() {
        _status = 'Error requesting permissions: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
