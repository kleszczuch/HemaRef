import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_firebase_app/settings.dart';
import 'round.dart';
import 'tournament.dart';
import 'profile.dart';
import 'friends.dart';
import 'user_search_dialog.dart';

Future<({int maxPoints, int roundSeconds})?> _showMatchSettingsDialog(
  BuildContext context,
) async {
  int selectedMaxPoints = 5;
  int selectedTime = 120;

  return showDialog<({int maxPoints, int roundSeconds})>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Ustawienia meczu'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Maks. punkty:'),
                    DropdownButton<int>(
                      value: selectedMaxPoints,
                      items: [5, 7, 10]
                          .map((n) => DropdownMenuItem(
                                value: n,
                                child: Text('$n'),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedMaxPoints = val);
                        }
                      },
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Czas:'),
                    DropdownButton<int>(
                      value: selectedTime,
                      items: [120, 150, 180]
                          .map((n) => DropdownMenuItem(
                                value: n,
                                child: Text(
                                    '${n ~/ 60}:${(n % 60).toString().padLeft(2, '0')}'),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedTime = val);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Anuluj'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  (maxPoints: selectedMaxPoints, roundSeconds: selectedTime),
                ),
                child: const Text('Rozpocznij'),
              ),
            ],
          );
        },
      );
    },
  );
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (BuildContext innerContext) {
          return Scaffold(
            backgroundColor: Colors.brown,
            body: SafeArea(
              child: Stack(
                children: <Widget>[
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        _MainSquareButton(
                          label: 'Szybki\nMecz',
                          color: Colors.redAccent,
                          onTap: () async {
                            // Dialog ustawien meczu (punkty/czas)
                            final settings =
                                await _showMatchSettingsDialog(innerContext);
                            if (settings == null || !innerContext.mounted) {
                              return;
                            }

                            final MatchResult? result =
                                await Navigator.push<MatchResult>(
                                  innerContext,
                                  MaterialPageRoute<MatchResult>(
                                    builder: (context) =>
                                        TimerDecisionScreen(
                                          maxPoints: settings.maxPoints,
                                          roundSeconds: settings.roundSeconds,
                                        ),
                                  ),
                                );
                            if (result == null || !innerContext.mounted) {
                              return;
                            }

                            ScaffoldMessenger.of(innerContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Mecz zakończony | '
                                  'Zwycięzca: ${result.winner} | '
                                  'Niebieski: ${result.bluePoints} | '
                                  'Żółty: ${result.yellowPoints}',
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 16),
                        _MainSquareButton(
                          label: 'Mecz\nRankingowy',
                          color: Colors.green,
                          onTap: () async {
                            // Wybór broni
                            final weaponChoice = await showDialog<String>(
                              context: innerContext,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('Broń'),
                                  content: const Text(
                                    'Wybierz broń do meczu rankingowego:',
                                  ),
                                  actions: AppSettingsData.allWeapons
                                      .map((weapon) => TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, weapon),
                                            child: Text(weapon),
                                          ))
                                      .toList(),
                                );
                              },
                            );

                            if (weaponChoice == null || !innerContext.mounted) return;

                            // Dialog ustawien meczu (punkty/czas)
                            final matchSettings =
                                await _showMatchSettingsDialog(innerContext);
                            if (matchSettings == null || !innerContext.mounted) return;

                            // Wybierz przeciwnika z wyszukiwaniem
                            final currentUid = FirebaseAuth.instance.currentUser?.uid;
                            final searchResult =
                                await Navigator.push<UserSearchResult>(
                              innerContext,
                              MaterialPageRoute<UserSearchResult>(
                                builder: (_) => UserSearchDialog(
                                  excludeUids: {
                                    if (currentUid != null) currentUid,
                                  },
                                  title: 'Wybierz przeciwnika',
                                  friendsOnly: true,
                                ),
                              ),
                            );

                            if (searchResult == null || !innerContext.mounted) return;

                            final opponent = <String, dynamic>{
                              'uid': searchResult.uid,
                              'name': searchResult.name,
                            };

                            // Rozpocznij mecz
                            final currentUserName =
                                FirebaseAuth.instance.currentUser?.displayName ??
                                FirebaseAuth.instance.currentUser?.email ??
                                'Ja';
                            final MatchResult? result =
                                await Navigator.push<MatchResult>(
                                  innerContext,
                                  MaterialPageRoute<MatchResult>(
                                    builder: (context) =>
                                        TimerDecisionScreen(
                                          blueName: currentUserName,
                                          yellowName: opponent['name'] as String,
                                          maxPoints: matchSettings.maxPoints,
                                          roundSeconds: matchSettings.roundSeconds,
                                        ),
                                  ),
                                );
                            if (result == null || !innerContext.mounted) return;

                            // Zapisz do Firestore
                            await FirebaseFirestore.instance
                                .collection('matches')
                                .add(<String, dynamic>{
                                  'type': 'ranked',
                                  'weapon': weaponChoice,
                                  'playerX': currentUserName,
                                  'playerY': opponent['name'],
                                  'opponentUid': opponent['uid'],
                                  'winner': result.winner == 'Niebieski'
                                      ? currentUserName
                                      : result.winner == 'Żółty'
                                          ? opponent['name']
                                          : 'Remis',
                                  'pointsX': result.bluePoints,
                                  'pointsY': result.yellowPoints,
                                  'remainingSeconds': result.remainingSeconds,
                                  'blueYellowCards': result.blueYellowCards,
                                  'blueRedCards': result.blueRedCards,
                                  'yellowYellowCards': result.yellowYellowCards,
                                  'yellowRedCards': result.yellowRedCards,
                                  'maxPoints': matchSettings.maxPoints,
                                  'roundSeconds': matchSettings.roundSeconds,
                                  'userId': currentUid,
                                  'createdAt': FieldValue.serverTimestamp(),
                                });

                            if (!innerContext.mounted) return;
                            ScaffoldMessenger.of(innerContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Mecz rankingowy | '
                                  'Zwycięzca: ${result.winner == 'Niebieski' ? currentUserName : result.winner == 'Żółty' ? opponent['name'] : 'Remis'} | '
                                  '$currentUserName ${result.bluePoints}:${result.yellowPoints} ${opponent['name']}',
                                ),
                              ),
                            );
                          },
                        ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _MainSquareButton(
                          label: 'Drabinka\nTurniejowa',
                          color: Colors.blueAccent,
                          onTap: () {
                            Navigator.push(
                              innerContext,
                              MaterialPageRoute<void>(
                                builder: (context) => const TournamentSetupScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 16.0,
                    right: 16.0,
                    child: FloatingActionButton(
                      heroTag: 'profile_fab',
                      onPressed: () {
                        goToProfile(innerContext);
                      },
                      tooltip: 'Go to Profile',
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28.0),
                      ),
                      child: const Icon(Icons.perm_identity),
                    ),
                  ),

                  Positioned(
                    top: 16.0,
                    left: 16.0,
                    child: FloatingActionButton(
                      heroTag: 'friends_fab',
                      onPressed: () {
                        Navigator.push(
                          innerContext,
                          MaterialPageRoute(
                            builder: (_) => const FriendsPage(),
                          ),
                        );
                      },
                      tooltip: 'Znajomi',
                      backgroundColor: Colors.grey,
                      child: const Icon(Icons.people),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

void goToProfile(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (BuildContext context) => const ProfilePage(),
    ),
  );
}


class _MainSquareButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MainSquareButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
