import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class FloatingPageMenu extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final bool includeBack;
  final VoidCallback? onBack;
  final IconData? pageIcon;
  final String? pageTooltip;
  final VoidCallback? onPageTap;
  final VoidCallback? onLogout;

  const FloatingPageMenu({
    super.key,
    required this.currentIndex,
    required this.onSelected,
    this.includeBack = false,
    this.onBack,
    this.pageIcon,
    this.pageTooltip,
    this.onPageTap,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 12, right: 16),
        child: Align(
          alignment: Alignment.topRight,
          child: Material(
            color: AppColors.panel,
            elevation: 0,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (includeBack && onBack != null)
                    _MenuIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Indietro',
                      selected: false,
                      onTap: onBack!,
                    ),
                  _MenuIconButton(
                    icon: Icons.space_dashboard_rounded,
                    tooltip: 'Dashboard',
                    selected: currentIndex == 0,
                    onTap: () => onSelected(0),
                  ),
                  _MenuIconButton(
                    icon: Icons.family_restroom_rounded,
                    tooltip: 'Famiglie',
                    selected: currentIndex == 1,
                    onTap: () => onSelected(1),
                  ),
                  _MenuIconButton(
                    icon: Icons.settings_rounded,
                    tooltip: 'Impostazioni',
                    selected: currentIndex == 2,
                    onTap: () => onSelected(2),
                  ),
                  if (pageIcon != null)
                    _MenuIconButton(
                      icon: pageIcon!,
                      tooltip: pageTooltip ?? 'Pagina',
                      selected: true,
                      onTap: onPageTap ?? () {},
                    ),
                  if (onLogout != null)
                    _MenuIconButton(
                      icon: Icons.logout_rounded,
                      tooltip: 'Esci',
                      selected: false,
                      onTap: onLogout!,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  const _MenuIconButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: selected ? Colors.white.withOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}
