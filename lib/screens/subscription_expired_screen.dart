import 'package:flutter/material.dart';
import '../services/subscription_service.dart';
import '../utils/app_colors.dart';
import '../utils/logger.dart';
import '../utils/responsive_helper.dart';

/// Screen shown when user's subscription has expired or they don't have access to content
class SubscriptionExpiredScreen extends StatefulWidget {
  final String? contentTitle;
  final String? courseId;

  const SubscriptionExpiredScreen({Key? key, this.contentTitle, this.courseId})
    : super(key: key);

  @override
  State<SubscriptionExpiredScreen> createState() =>
      _SubscriptionExpiredScreenState();
}

class _SubscriptionExpiredScreenState extends State<SubscriptionExpiredScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  Map<String, dynamic>? _subscriptionStatus;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionStatus();
  }

  Future<void> _loadSubscriptionStatus() async {
    try {
      final status =
          await _subscriptionService.getCurrentUserSubscriptionStatus();
      setState(() {
        _subscriptionStatus = status;
        _isLoading = false;
      });
    } catch (error) {
      Logger.e('❌ Error loading subscription status: $error');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = ResponsiveHelper.isTablet(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Subscription Required'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isTablet ? 32 : 24),
          child: Column(
            children: [
              SizedBox(height: screenSize.height * 0.1),
              _buildIcon(),
              const SizedBox(height: 32),
              _buildTitle(),
              const SizedBox(height: 16),
              _buildDescription(),
              const SizedBox(height: 32),
              _buildSubscriptionInfo(),
              const SizedBox(height: 40),
              _buildActionButtons(),
              const SizedBox(height: 24),
              _buildSupportInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.lock_outline, size: 60, color: AppColors.primary),
    );
  }

  Widget _buildTitle() {
    return Text(
      'Subscription Required',
      style: TextStyle(
        fontSize: ResponsiveHelper.isTablet(context) ? 28 : 24,
        fontWeight: FontWeight.bold,
        color: AppColors.onSurface,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildDescription() {
    String description =
        'To access this content, you need an active subscription to Briffini Academy.';

    if (widget.contentTitle != null) {
      description =
          'To access "${widget.contentTitle}", you need an active subscription to Briffini Academy.';
    }

    return Text(
      description,
      style: TextStyle(
        fontSize: 16,
        color: AppColors.onSurface.withOpacity(0.7),
        height: 1.5,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildSubscriptionInfo() {
    if (_isLoading) {
      return const CircularProgressIndicator();
    }

    if (_subscriptionStatus == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          children: [
            Icon(Icons.info_outline, color: Colors.grey[600]),
            const SizedBox(height: 8),
            Text(
              'Unable to load subscription information',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    final hasSubscription =
        _subscriptionStatus!['hasSubscription'] as bool? ?? false;
    final isActive = _subscriptionStatus!['isActive'] as bool? ?? false;
    final message = _subscriptionStatus!['message'] as String?;

    if (!hasSubscription) {
      return _buildInfoCard(
        icon: Icons.new_releases,
        title: 'No Subscription Found',
        description:
            'You don\'t have a subscription yet. Start your learning journey today!',
        color: Colors.blue,
      );
    }

    if (!isActive) {
      final lastEndDate = _subscriptionStatus!['lastEndDate'] as DateTime?;
      String expiredDescription =
          'Your subscription has expired. Renew now to continue learning.';

      if (lastEndDate != null) {
        final daysSinceExpiry = DateTime.now().difference(lastEndDate).inDays;
        expiredDescription =
            'Your subscription expired $daysSinceExpiry day${daysSinceExpiry == 1 ? '' : 's'} ago. Renew now to continue learning.';
      }

      return _buildInfoCard(
        icon: Icons.schedule,
        title: 'Subscription Expired',
        description: expiredDescription,
        color: Colors.orange,
      );
    }

    // Should not reach here if access validation worked correctly
    return _buildInfoCard(
      icon: Icons.warning,
      title: 'Access Restricted',
      description:
          message ??
          'There seems to be an issue with your subscription access.',
      color: Colors.red,
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.onSurface.withOpacity(0.8),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _handleRenewSubscription,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: const Text(
              'Get Subscription',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _handleRefreshStatus,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Refresh Status',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _handleBackToHome,
          child: Text(
            'Back to Home',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.onSurface.withOpacity(0.7),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSupportInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.onSurface.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.help_outline,
            color: AppColors.onSurface.withOpacity(0.6),
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            'Need Help?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Contact our support team if you believe this is an error or if you need assistance with your subscription.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.onSurface.withOpacity(0.7),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _handleContactSupport,
            child: Text(
              'Contact Support',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleRenewSubscription() {
    Logger.i('🔄 User requested subscription renewal');

    // TODO: Implement subscription/payment flow
    // For now, show a dialog
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Subscription'),
            content: const Text(
              'Subscription management will be available soon. Please contact support for assistance.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _handleRefreshStatus() {
    Logger.i('🔄 Refreshing subscription status');
    setState(() {
      _isLoading = true;
    });
    _loadSubscriptionStatus();
  }

  void _handleBackToHome() {
    Logger.i('🏠 Navigating back to home');
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  void _handleContactSupport() {
    Logger.i('📞 User requested support contact');

    // TODO: Implement support contact flow (email, chat, etc.)
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Contact Support'),
            content: const Text(
              'Support contact information:\n\nEmail: support@briffini.academy\n\nWe\'ll respond within 24 hours.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }
}
