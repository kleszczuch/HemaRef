import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'settings.dart';
import 'round.dart';
import 'user_search_dialog.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _currentUid => FirebaseAuth.instance.currentUser!.uid;

  Future<void> _sendFriendRequest() async {
    final result = await Navigator.push<UserSearchResult>(
      context,
      MaterialPageRoute(
        builder: (_) => UserSearchDialog(
          excludeUids: {_currentUid},
          title: 'Dodaj znajomego',
        ),
      ),
    );
    if (result == null || !mounted) return;

    final firestore = FirebaseFirestore.instance;

    // Sprawdź czy już są znajomymi
    final friendDoc = await firestore
        .collection('users')
        .doc(_currentUid)
        .collection('friends')
        .doc(result.uid)
        .get();
    if (friendDoc.exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ta osoba jest już Twoim znajomym')),
        );
      }
      return;
    }

    // Sprawdź czy zaproszenie już istnieje
    final existing = await firestore
        .collection('friend_requests')
        .where('from', isEqualTo: _currentUid)
        .where('to', isEqualTo: result.uid)
        .where('status', isEqualTo: 'pending')
        .get();
    if (existing.docs.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zaproszenie już wysłane')),
        );
      }
      return;
    }

    // Sprawdź czy druga osoba już wysłała zaproszenie do nas
    final reverse = await firestore
        .collection('friend_requests')
        .where('from', isEqualTo: result.uid)
        .where('to', isEqualTo: _currentUid)
        .where('status', isEqualTo: 'pending')
        .get();
    if (reverse.docs.isNotEmpty) {
      // Automatycznie akceptuj
      await _acceptRequest(reverse.docs.first.id, result.uid, result.name);
      return;
    }

    final currentName =
        FirebaseAuth.instance.currentUser?.displayName ?? 'Nieznany';
    await firestore.collection('friend_requests').add({
      'from': _currentUid,
      'to': result.uid,
      'fromName': currentName,
      'toName': result.name,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Zaproszenie wysłane do ${result.name}')),
      );
    }
  }

  Future<void> _acceptRequest(
      String requestId, String otherUid, String otherName) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    final currentName =
        FirebaseAuth.instance.currentUser?.displayName ?? 'Nieznany';

    // Zaktualizuj status zaproszenia
    batch.update(
      firestore.collection('friend_requests').doc(requestId),
      {'status': 'accepted'},
    );

    // Dodaj do znajomych obu użytkownikom
    batch.set(
      firestore
          .collection('users')
          .doc(_currentUid)
          .collection('friends')
          .doc(otherUid),
      {'name': otherName, 'addedAt': FieldValue.serverTimestamp()},
    );
    batch.set(
      firestore
          .collection('users')
          .doc(otherUid)
          .collection('friends')
          .doc(_currentUid),
      {'name': currentName, 'addedAt': FieldValue.serverTimestamp()},
    );

    await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$otherName dodany do znajomych!')),
      );
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    await FirebaseFirestore.instance
        .collection('friend_requests')
        .doc(requestId)
        .update({'status': 'rejected'});
  }

  Future<void> _removeFriend(String friendUid, String friendName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usuń znajomego'),
        content: Text('Czy na pewno chcesz usunąć $friendName ze znajomych?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Usuń', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    batch.delete(
      firestore
          .collection('users')
          .doc(_currentUid)
          .collection('friends')
          .doc(friendUid),
    );
    batch.delete(
      firestore
          .collection('users')
          .doc(friendUid)
          .collection('friends')
          .doc(_currentUid),
    );
    await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$friendName usunięty ze znajomych')),
      );
    }
  }

  Future<void> _startDuel(String friendUid, String friendName) async {
    // Wybierz broń
    final weaponChoice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Broń'),
        content: const Text('Wybierz broń do pojedynku:'),
        actions: AppSettingsData.allWeapons
            .map((weapon) => TextButton(
                  onPressed: () => Navigator.pop(ctx, weapon),
                  child: Text(weapon),
                ))
            .toList(),
      ),
    );
    if (weaponChoice == null || !mounted) return;

    // Ustawienia meczu
    final matchSettings = await _showMatchSettingsDialog(context);
    if (matchSettings == null || !mounted) return;

    final currentUserName =
        FirebaseAuth.instance.currentUser?.displayName ??
        FirebaseAuth.instance.currentUser?.email ??
        'Ja';

    final MatchResult? result = await Navigator.push<MatchResult>(
      context,
      MaterialPageRoute<MatchResult>(
        builder: (_) => TimerDecisionScreen(
          blueName: currentUserName,
          yellowName: friendName,
          maxPoints: matchSettings.maxPoints,
          roundSeconds: matchSettings.roundSeconds,
        ),
      ),
    );
    if (result == null || !mounted) return;

    // Zapisz do Firestore
    await FirebaseFirestore.instance.collection('matches').add({
      'type': 'ranked',
      'weapon': weaponChoice,
      'playerX': currentUserName,
      'playerY': friendName,
      'opponentUid': friendUid,
      'winner': result.winner == 'Niebieski'
          ? currentUserName
          : result.winner == 'Żółty'
              ? friendName
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
      'userId': _currentUid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Pojedynek | Zwycięzca: ${result.winner == 'Niebieski' ? currentUserName : result.winner == 'Żółty' ? friendName : 'Remis'} | '
          '$currentUserName ${result.bluePoints}:${result.yellowPoints} $friendName',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Znajomi'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Znajomi'),
            Tab(text: 'Zaproszenia'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _sendFriendRequest,
        child: const Icon(Icons.person_add),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsList(),
          _buildRequestsList(),
        ],
      ),
    );
  }

  Widget _buildFriendsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .collection('friends')
          .orderBy('addedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'Brak znajomych.\nKliknij + aby dodać.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final friendUid = docs[index].id;
            final friendName = data['name'] ?? 'Nieznany';
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(friendName),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.sports_kabaddi, color: Colors.red),
                    tooltip: 'Pojedynek',
                    onPressed: () => _startDuel(friendUid, friendName),
                  ),
                  IconButton(
                    icon: const Icon(Icons.person_remove, color: Colors.grey),
                    tooltip: 'Usuń',
                    onPressed: () => _removeFriend(friendUid, friendName),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRequestsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('friend_requests')
          .where('to', isEqualTo: _currentUid)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'Brak oczekujących zaproszeń',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final requestId = docs[index].id;
            final fromUid = data['from'] as String;
            final fromName = data['fromName'] ?? 'Nieznany';
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_add)),
              title: Text(fromName),
              subtitle: const Text('Chce zostać Twoim znajomym'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    tooltip: 'Akceptuj',
                    onPressed: () =>
                        _acceptRequest(requestId, fromUid, fromName),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    tooltip: 'Odrzuć',
                    onPressed: () => _rejectRequest(requestId),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

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
