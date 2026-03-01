import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppSettingsData extends ChangeNotifier {
  static const List<String> allWeapons = [
    'Szabla',
    'Miecz długi',
    'Miecz i puklerz',
    'Rapier',
    'Side-sword',
  ];

  // Mapowanie starych kluczy na nowe (kompatybilnosc wsteczna z Firestore)
  static const Map<String, String> _oldToNewWeaponKeys = {
    'Miecz Dlugi': 'Miecz długi',
    'Miecz z puklerzem': 'Miecz i puklerz',
    'Rapier z lewakiem': 'Rapier',
    'Sidesword': 'Side-sword',
  };

  final Map<String, bool> _categorySelections;

  AppSettingsData()
    : _categorySelections = {
        for (final w in allWeapons) w: false,
      } {
    _loadFromFirebase();
  }

  final List<String> club = [
    'Gwiazdy Katowice',
    'Rebel',
    'Akademia szermierzy',
  ];
  String _chosenClub = "Brak wybranego klubu";

  String get chosenClub => _chosenClub;

  set chosenClub(String newClub) {
    if (_chosenClub != newClub) {
      _chosenClub = newClub;
      notifyListeners();
      _saveToFirebase();
    }
  }

  Map<String, bool> get categorySelections =>
      Map<String, bool>.from(_categorySelections);

  void setCategorySelected(String categoryName, bool isSelected) {
    if (_categorySelections[categoryName] != isSelected) {
      _categorySelections[categoryName] = isSelected;
      notifyListeners();
      _saveToFirebase();
    }
  }

  int _wins = 0;
  int _losses = 0;
  int _draws = 0;
  int _totalYellowCards = 0;
  int _totalRedCards = 0;

  // Statystyki per broń
  Map<String, ({int wins, int losses, int draws, int yellowCards, int redCards})>
      _weaponStats = {};

  String _displayName = '';

  int get wins => _wins;
  int get losses => _losses;
  int get draws => _draws;
  int get totalYellowCards => _totalYellowCards;
  int get totalRedCards => _totalRedCards;
  int get totalMatches => _wins + _losses + _draws;
  double get winRate => totalMatches > 0 ? (_wins / totalMatches) * 100 : 0;

  Map<String, ({int wins, int losses, int draws, int yellowCards, int redCards})>
      get weaponStats => Map.from(_weaponStats);

  String get displayName => _displayName;

  Future<void> updateDisplayName(String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == _displayName) return;
    _displayName = trimmed;
    await FirebaseAuth.instance.currentUser?.updateDisplayName(_displayName);
    await _saveToFirebase();
    notifyListeners();
  }

  Future<void> _recalculateStatsFromMatches() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    int w = 0, l = 0, d = 0, yc = 0, rc = 0;
    final uid = user.uid;
    final matchesRef = FirebaseFirestore.instance.collection('matches');

    // Akumulatory per broń
    final Map<String, ({int w, int l, int d, int yc, int rc})> weaponAccum = {
      for (final weapon in allWeapons)
        weapon: (w: 0, l: 0, d: 0, yc: 0, rc: 0),
    };

    void addWeaponStat(String? weapon, String statType, int ycVal, int rcVal) {
      if (weapon == null || !weaponAccum.containsKey(weapon)) return;
      final current = weaponAccum[weapon]!;
      weaponAccum[weapon] = (
        w: current.w + (statType == 'win' ? 1 : 0),
        l: current.l + (statType == 'loss' ? 1 : 0),
        d: current.d + (statType == 'draw' ? 1 : 0),
        yc: current.yc + ycVal,
        rc: current.rc + rcVal,
      );
    }

    void processAsCreator(Map<String, dynamic> data) {
      final winner = data['winner'] as String? ?? '';
      final playerX = data['playerX'] as String? ?? '';
      final weapon = data['weapon'] as String?;
      final ycVal = (data['blueYellowCards'] as int?) ?? 0;
      final rcVal = (data['blueRedCards'] as int?) ?? 0;

      if (winner == 'Remis') {
        d++;
        addWeaponStat(weapon, 'draw', ycVal, rcVal);
      } else if (winner == playerX) {
        w++;
        addWeaponStat(weapon, 'win', ycVal, rcVal);
      } else {
        l++;
        addWeaponStat(weapon, 'loss', ycVal, rcVal);
      }
      yc += ycVal;
      rc += rcVal;
    }

    void processAsOpponent(Map<String, dynamic> data) {
      final winner = data['winner'] as String? ?? '';
      final playerY = data['playerY'] as String? ?? '';
      final weapon = data['weapon'] as String?;
      final ycVal = (data['yellowYellowCards'] as int?) ?? 0;
      final rcVal = (data['yellowRedCards'] as int?) ?? 0;

      if (winner == 'Remis') {
        d++;
        addWeaponStat(weapon, 'draw', ycVal, rcVal);
      } else if (winner == playerY) {
        w++;
        addWeaponStat(weapon, 'win', ycVal, rcVal);
      } else {
        l++;
        addWeaponStat(weapon, 'loss', ycVal, rcVal);
      }
      yc += ycVal;
      rc += rcVal;
    }

    // Mecze rankingowe + turniejowe, w których aktualny użytkownik jest twórcą
    for (final type in ['ranked', 'tournament']) {
      final asCreator = await matchesRef
          .where('userId', isEqualTo: uid)
          .where('type', isEqualTo: type)
          .get();
      for (final doc in asCreator.docs) {
        processAsCreator(doc.data());
      }

      // Mecze, w których aktualny użytkownik jest przeciwnikiem
      final asOpponent = await matchesRef
          .where('opponentUid', isEqualTo: uid)
          .where('type', isEqualTo: type)
          .get();
      for (final doc in asOpponent.docs) {
        processAsOpponent(doc.data());
      }
    }

    _wins = w;
    _losses = l;
    _draws = d;
    _totalYellowCards = yc;
    _totalRedCards = rc;

    _weaponStats = {
      for (final entry in weaponAccum.entries)
        entry.key: (
          wins: entry.value.w,
          losses: entry.value.l,
          draws: entry.value.d,
          yellowCards: entry.value.yc,
          redCards: entry.value.rc,
        ),
    };
  }

  DocumentReference? get _userDoc {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(user.uid);
  }

  Future<void> _saveToFirebase() async {
    final doc = _userDoc;
    if (doc == null) return;
    await doc.set({
      'chosenClub': _chosenClub,
      'categories': _categorySelections,
      'email': FirebaseAuth.instance.currentUser?.email,
      'displayName': _displayName.isNotEmpty
          ? _displayName
          : FirebaseAuth.instance.currentUser?.displayName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> reloadFromFirebase() => _loadFromFirebase();

  Future<void> _loadFromFirebase() async {
    final doc = _userDoc;
    if (doc == null) return;
    final snapshot = await doc.get();
    if (!snapshot.exists) {
      _chosenClub = 'Brak wybranego klubu';
      for (final key in _categorySelections.keys) {
        _categorySelections[key] = false;
      }
      await _recalculateStatsFromMatches();
      notifyListeners();
      return;
    }
    final data = snapshot.data() as Map<String, dynamic>?;
    if (data == null) return;

    if (data['chosenClub'] is String) {
      _chosenClub = data['chosenClub'] as String;
    }
    if (data['displayName'] is String) {
      _displayName = data['displayName'] as String;
    } else {
      _displayName = FirebaseAuth.instance.currentUser?.displayName ?? '';
    }
    if (data['categories'] is Map) {
      final cats = data['categories'] as Map<String, dynamic>;
      for (final entry in cats.entries) {
        final key = _oldToNewWeaponKeys[entry.key] ?? entry.key;
        if (_categorySelections.containsKey(key)) {
          _categorySelections[key] = entry.value as bool;
        }
      }
    }
    await _recalculateStatsFromMatches();

    notifyListeners();
  }
}



