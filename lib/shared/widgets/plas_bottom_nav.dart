import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plasmobile/core/theme/plas_tokens.dart';

class PlasBottomNav extends StatelessWidget {
  const PlasBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const List<_PlasNavItem> _items = [
    _PlasNavItem(label: 'Belajar', icon: Symbols.menu_book),
    _PlasNavItem(label: 'Riwayat', icon: Symbols.history),
    _PlasNavItem(label: 'Profil', icon: Symbols.account_circle),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: PlasColors.bgSurface,
        border: Border(top: BorderSide(color: PlasColors.borderSubtle)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Row(
            children: [
              for (var index = 0; index < _items.length; index++)
                Expanded(
                  child: _PlasNavTab(
                    item: _items[index],
                    isSelected: currentIndex == index,
                    onTap: () => onTap(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlasNavTab extends StatelessWidget {
  const _PlasNavTab({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _PlasNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? PlasColors.brandPrimary : PlasColors.textMuted;

    return Semantics(
      button: true,
      selected: isSelected,
      label: item.label,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PlasSpacing.space1,
                vertical: PlasSpacing.space2,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: PlasSpacing.space4,
                      vertical: PlasSpacing.space1,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? PlasColors.brandTint
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(PlasRadii.full),
                    ),
                    child: Icon(item.icon, size: 22, color: color),
                  ),
                  const SizedBox(height: PlasSpacing.space1),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PlasTypography.caption.copyWith(
                      color: color,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
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

class _PlasNavItem {
  const _PlasNavItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
