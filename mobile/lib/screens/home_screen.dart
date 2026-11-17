import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dijital_dolap/providers/calendar_provider.dart';
import 'package:dijital_dolap/providers/occasion_provider.dart';
import 'package:dijital_dolap/screens/calendar_screen.dart';
import 'package:dijital_dolap/screens/home_tab_screen.dart';
import 'package:dijital_dolap/screens/outfits_screen.dart';
import 'package:dijital_dolap/screens/profile_screen.dart';
import 'package:dijital_dolap/screens/wardrobe_screen.dart';
import 'package:dijital_dolap/screens/wear_history_screen.dart';
import 'package:dijital_dolap/theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  late final List<Widget> _pages = [
    HomeTabScreen(onOpenSuggestions: () => _goTo(2)),
    const WardrobeScreen(),
    const OutfitsScreen(),
    const WearHistoryScreen(),
    const CalendarScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OccasionProvider>().load();
    });
  }

  void _goTo(int i) {
    setState(() {
      _index = i.clamp(0, _pages.length - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Sayfa yüklendiği anda yaklaşan olay uyarılarını sor.
    final calendar = context.watch<CalendarProvider>();
    final urgent = calendar.pendingInsights.isEmpty
        ? null
        : calendar.pendingInsights.first;

    return Scaffold(
      body: Column(
        children: [
          if (urgent != null)
            Material(
              color: Colors.red.shade50,
              child: InkWell(
                onTap: () => _goTo(4),
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.event_busy_outlined,
                      color: Colors.red.shade700, size: 22),
                  title: Text(
                    urgent.message,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.red.shade900),
                  ),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppColors.slate),
                ),
              ),
            ),
          Expanded(
            child: IndexedStack(index: _index, children: _pages),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.checkroom_outlined),
            selectedIcon: Icon(Icons.checkroom),
            label: 'Dolabım',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Kombinler',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Geçmiş',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Takvim',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
