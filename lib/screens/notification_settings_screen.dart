import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Notification Preferences',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),

              // General notification settings
              SwitchListTile(
                title: const Text('Enable Notifications'),
                subtitle: const Text(
                  'Receive notifications for messages and updates',
                ),
                value: true, // You would use a provider or state management here
                onChanged: (value) {
                  // Handle notification toggle
                },
              ),

              const Divider(),

              // Specific notification types
              CheckboxListTile(
                title: const Text('Chat Messages'),
                subtitle: const Text('Notifications for new chat messages'),
                value: true,
                onChanged: (value) {
                  // Handle chat notifications toggle
                },
              ),

              CheckboxListTile(
                title: const Text('Course Updates'),
                subtitle: const Text('Notifications for course content updates'),
                value: true,
                onChanged: (value) {
                  // Handle course update notifications toggle
                },
              ),

              CheckboxListTile(
                title: const Text('Announcements'),
                subtitle: const Text('Notifications for general announcements'),
                value: true,
                onChanged: (value) {
                  // Handle announcement notifications toggle
                },
              ),

              const SizedBox(height: 50), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }
}
