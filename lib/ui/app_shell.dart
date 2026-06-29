import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/tokens.dart';
import 'capture_screen.dart';
import 'feed_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'rankings_screen.dart';
import 'success_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  Future<void> _openCapture() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CaptureScreen(
          onSuccess: (number) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => SuccessScreen(
                  number: number,
                  onSeeFeed: () {
                    Navigator.of(context).pop();
                    setState(() => _index = 1);
                  },
                  onContinue: () => Navigator.of(context).pop(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(onAddPinte: _openCapture),
          const FeedScreen(),
          const RankingsScreen(),
          const ProfileScreen(),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTokens.coral,
        onPressed: _openCapture,
        child: const Text(
          '+',
          style: TextStyle(fontSize: 28, color: Colors.white),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: switch (_index) { 0 => 0, 1 => 1, 2 => 3, _ => 4 },
        onTap: (i) {
          if (i == 2) return; // slot central FAB
          setState(
            () => _index = switch (i) {
              0 => 0,
              1 => 1,
              3 => 2, // Villes -> RankingsScreen
              _ => 3, // Profil
            },
          );
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTokens.coral,
        unselectedItemColor: AppTokens.tabInactive,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.dynamic_feed), label: 'Fil'),
          BottomNavigationBarItem(icon: SizedBox.shrink(), label: ''),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events),
            label: 'Villes',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
