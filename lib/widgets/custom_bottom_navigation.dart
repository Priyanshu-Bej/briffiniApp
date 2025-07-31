import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_colors.dart';
import '../utils/responsive_helper.dart';
import '../screens/assigned_courses_screen.dart';
import '../screens/profile_screen.dart';

class CustomBottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTap;

  const CustomBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: ResponsiveHelper.adaptiveFontSize(context, 80.0),
          padding: ResponsiveHelper.getScreenHorizontalPadding(context),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                context: context,
                icon: Icons.home_outlined,
                selectedIcon: Icons.home,
                label: 'Home',
                index: 0,
                isSelected: selectedIndex == 0,
              ),
              _buildNavItem(
                context: context,
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
                label: 'Profile',
                index: 1,
                isSelected: selectedIndex == 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
    required bool isSelected,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(index),
          borderRadius: BorderRadius.circular(12.0),
          child: Container(
            constraints: ResponsiveHelper.getLargeTouchTarget(),
            padding: EdgeInsets.symmetric(
              vertical: ResponsiveHelper.getAdaptiveSpacing(context, 
                compact: 8.0, regular: 12.0, pro: 14.0, large: 16.0, extraLarge: 18.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  color: isSelected ? AppColors.primary : Colors.grey[500],
                  size: ResponsiveHelper.adaptiveFontSize(context, 24.0),
                ),
                SizedBox(height: ResponsiveHelper.getAdaptiveSpacing(context, 
                  compact: 4.0, regular: 6.0, pro: 6.0, large: 8.0, extraLarge: 8.0)),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: ResponsiveHelper.adaptiveFontSize(context, 12.0),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? AppColors.primary : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Static method to handle navigation
  static void handleNavigation(BuildContext context, int index) {
    switch (index) {
      case 0:
        if (ModalRoute.of(context)?.settings.name != '/home') {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AssignedCoursesScreen()),
            (route) => false,
          );
        }
        break;
      case 1:
        if (ModalRoute.of(context)?.settings.name != '/profile') {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const ProfileScreen()),
            (route) => false,
          );
        }
        break;
    }
  }
} 