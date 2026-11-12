import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'home.dart';
import 'map_screen.dart';
import 'parts.dart';
import 'profile.dart';
import 'requests.dart';

class _Tab {
  final String label;
  final IconData icon;
  final Widget page;
  const _Tab(this.label, this.icon, this.page);
}

class Shell extends StatelessWidget {
  const Shell({super.key});

  List<_Tab> _tabs(String role) {
    if (role == 'mechanic') {
      return const [
        _Tab('Jobs', Icons.assignment_rounded, RequestsScreen()),
        _Tab('Profile', Icons.person_rounded, ProfileScreen()),
      ];
    }
    if (role == 'supplier') {
      return const [
        _Tab('My parts', Icons.inventory_2_rounded, SupplierPartsScreen()),
        _Tab('Profile', Icons.person_rounded, ProfileScreen()),
      ];
    }
    return const [
      _Tab('Home', Icons.home_rounded, HomeScreen()),
      _Tab('Nearby', Icons.map_rounded, MapScreen()),
      _Tab('Requests', Icons.assignment_rounded, RequestsScreen()),
      _Tab('Profile', Icons.person_rounded, ProfileScreen()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final role = app.role;
    final tabs = _tabs(role);
    return ValueListenableBuilder<int>(
      valueListenable: shellIndex,
      builder: (context, i, _) {
        final idx = (i < 0 || i >= tabs.length) ? 0 : i;
        return Scaffold(
          extendBody: true,
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
              fit: StackFit.expand,
              children: <Widget>[...previous, if (current != null) current],
            ),
            child: KeyedSubtree(key: ValueKey('$role-$idx'), child: tabs[idx].page),
          ),
          bottomNavigationBar: _FloatingNav(
            tabs: tabs,
            index: idx,
            onTap: (n) => shellIndex.value = n,
          ),
        );
      },
    );
  }
}

class _FloatingNav extends StatelessWidget {
  final List<_Tab> tabs;
  final int index;
  final ValueChanged<int> onTap;
  const _FloatingNav({required this.tabs, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(34),
            border: context.isDark ? Border.all(color: context.line) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(context.isDark ? 120 : 34),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(children: [
            for (int i = 0; i < tabs.length; i++)
              Expanded(
                child: Tappable(
                  onTap: () => onTap(i),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    AnimatedScale(
                      scale: i == index ? 1.12 : 1,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(tabs[i].icon, size: 24, color: i == index ? AppColors.accent : context.muted),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tabs[i].label,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                        color: i == index ? AppColors.accent : context.muted,
                      ),
                    ),
                  ]),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
