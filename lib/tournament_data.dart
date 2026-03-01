import 'dart:math';
import 'package:flutter/material.dart';

class Match {
  int? player1;
  int? player2;
  int? winner;

  Match(this.player1, this.player2);
}

/// Zarządza całą logiką turnieju drabinkowego.
/// Odpowiada za:
/// - Strukturę turnieju (rundy, mecze)
/// - Automatyczne rozstrzyganie meczów BYE
/// - Zliczanie kolejności meczów
/// - Zarządzanie meczem o 3. miejsce
class BracketData extends ChangeNotifier {
  // Główna struktura: bracket[runda][mecz] = Match
  List<List<Match>> bracket;

  // Mecz o 3. miejsce (między przegranymi z półfinałów)
  Match? thirdPlaceMatch;

  // Nazwy graczy
  Map<int, String> playerNames = {};

  // UIDs graczy z bazy (null = wpisany ręcznie)
  Map<int, String?> playerUids = {};

  // Lista wyników walk
  List<Map<String, dynamic>> fightResults = [];

  // Stan UI
  int _version = 0; // Inkrementowany przy każdej zmianie (wymusza repaint)
  int? _currentMatchRound; // Runda bieżącego meczu
  int? _currentMatchIndex; // Indeks bieżącego meczu w rundzie
  (int, int)? _currentMatchDisplayPlayers; // Dwaj gracze do wyświetlenia
  bool _isThirdPlaceMatchActive = false; // Czy jest aktywny mecz o 3. miejsce

  BracketData({List<int>? initialPlayers}) : bracket = <List<Match>>[] {
    _initializeTournament(players: initialPlayers);
  }

  // ============ GETTERY DLA UI ============
  int get version => _version;
  int? get currentMatchRound => _currentMatchRound;
  int? get currentMatchIndex => _currentMatchIndex;
  (int, int)? get currentMatchDisplayPlayers => _currentMatchDisplayPlayers;
  bool get isThirdPlaceMatchActive => _isThirdPlaceMatchActive;
  int? get thirdPlaceWinner => thirdPlaceMatch?.winner;

  List<int> get playersList {
    final Set<int> players = <int>{};
    for (final round in bracket) {
      for (final match in round) {
        if (match.player1 != null) {
          players.add(match.player1!);
        }
        if (match.player2 != null) {
          players.add(match.player2!);
        }
      }
    }
    return players.toList()..sort();
  }

  List<Map<String, dynamic>> buildMatchesList() {
    final List<Map<String, dynamic>> matches = <Map<String, dynamic>>[];
    for (int r = 0; r < bracket.length; r++) {
      for (int m = 0; m < bracket[r].length; m++) {
        final Match match = bracket[r][m];
        matches.add(<String, dynamic>{
          'round': r + 1,
          'matchIndex': m + 1,
          'player1': match.player1 ?? 0,
          'player2': match.player2 ?? 0,
          'winner': match.winner ?? 0,
          'points1': 0,
          'points2': 0,
        });
      }
    }

    if (thirdPlaceMatch != null) {
      matches.add(<String, dynamic>{
        'round': bracket.length + 1,
        'matchIndex': 1,
        'type': 'third_place',
        'player1': thirdPlaceMatch!.player1 ?? 0,
        'player2': thirdPlaceMatch!.player2 ?? 0,
        'winner': thirdPlaceMatch!.winner ?? 0,
        'points1': 0,
        'points2': 0,
      });
    }

    return matches;
  }

  Map<String, dynamic> buildTournamentPayload() {
    final DateTime now = DateTime.now();
    final String defaultName =
        'Turniej ${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    return <String, dynamic>{
      'name': defaultName,
      'dateTime': now.toIso8601String(),
      'players': playersList,
      'playerNames': playerNames.map((k, v) => MapEntry(k.toString(), v)),
      'matches': buildMatchesList(),
      'firstPlace': bracket.isNotEmpty && bracket.last.first.winner != null
          ? (playerNames[bracket.last.first.winner!] ?? bracket.last.first.winner)
          : 0,
      'secondPlace': 0,
      'thirdPlace': thirdPlaceMatch?.winner != null
          ? (playerNames[thirdPlaceMatch!.winner!] ?? thirdPlaceMatch!.winner)
          : 0,
      'size': playersList.length,
    };
  }

  @override
  void notifyListeners() {
    _version++;
    super.notifyListeners();
  }

  /// Inicjalizuje turniej dla 32 graczy.
  /// - Generuje strukturę drabinki
  /// - Automatycznie rozstrzyga mecze BYE
  /// - Przygotowuje pierwszy mecz do decyzji
  void _initializeTournament({List<int>? players}) {
    // Generuj i tasuj graczy (domyślnie 32)
    final List<int> initialPlayers =
        (players == null || players.isEmpty)
            ? List<int>.generate(32, (int index) => index + 1)
            : List<int>.from(players);
    bracket = _generateBracketStructure(initialPlayers, shuffle: true);
    thirdPlaceMatch = Match(null, null);

    // Automatyczne rozstrzyganie meczów BYE w pierwszej rundzie
    for (int m = 0; m < bracket[0].length; m++) {
      Match match = bracket[0][m];
      int? autoWinnerId;

      if (match.player1 == null && match.player2 != null) {
        autoWinnerId = match.player2;
      } else if (match.player2 == null && match.player1 != null) {
        autoWinnerId = match.player1;
      }

      if (autoWinnerId != null) {
        match.winner = autoWinnerId;
        if (bracket.length > 1) {
          _advanceWinner(bracket, 0, m, autoWinnerId);
        }
      }
    }

    startNextMatchDecision();
  }

  void initializeTournamentWithPlayers(List<int> players, {bool shuffle = true}) {
    bracket = _generateBracketStructure(players, shuffle: shuffle);
    thirdPlaceMatch = Match(null, null);
    _currentMatchRound = null;
    _currentMatchIndex = null;
    _currentMatchDisplayPlayers = null;
    _isThirdPlaceMatchActive = false;
    notifyListeners();
    startNextMatchDecision();
  }

  /// Generuje strukturę drabinki z listy graczy.
  /// Dodaje "gracze BYE" (-1) aby zaokrąglić do potęgi 2.
  List<List<Match>> _generateBracketStructure(
    List<int> players, {
    bool shuffle = false,
  }) {
    final Random random = Random();
    List<int> list = List<int>.from(players);

    if (shuffle) {
      list.shuffle(random);
    }

    // Oblicz liczbę rund potrzebnych
    int rounds = (log(list.length) / log(2)).ceil();
    int size = pow(2, rounds).toInt();

    // Uzupełnij BYE dla zaokrąglenia do potęgi 2
    while (list.length < size) {
      list.add(-1);
    }

    List<List<Match>> generatedBracket = <List<Match>>[];

    // Runda 1: Paruj graczy w mecze
    List<Match> firstRound = <Match>[];
    for (int i = 0; i < list.length; i += 2) {
      firstRound.add(
        Match(
          list[i] == -1 ? null : list[i],
          list[i + 1] == -1 ? null : list[i + 1],
        ),
      );
    }
    generatedBracket.add(firstRound);

    // Następne rundy: Puste mecze (wypełniane w trakcie turnieju)
    for (int r = 1; r < rounds; r++) {
      generatedBracket.add(
        List<Match>.generate(
          generatedBracket[r - 1].length ~/ 2,
          (int index) => Match(null, null),
        ),
      );
    }

    return generatedBracket;
  }

  /// Przenosi zwycięzcę meczu do następnej rundy.
  void _advanceWinner(
    List<List<Match>> bracket,
    int round,
    int matchIndex,
    int winnerId,
  ) {
    if (round >= bracket.length - 1) return; // Nie ma następnej rundy

    int nextMatchIndex = matchIndex ~/ 2;
    Match nextMatch = bracket[round + 1][nextMatchIndex];

    // Przypisz zwycięzcę do odpowiedniego pola (player1 lub player2)
    if (matchIndex.isEven) {
      nextMatch.player1 = winnerId;
    } else {
      nextMatch.player2 = winnerId;
    }
  }

  /// Znajduje następny mecz do rozstrzygnięcia.
  /// Priorytet:
  /// 1. Mecze przed finałem (oprócz samego finału)
  /// 2. Mecz o 3. miejsce
  /// 3. Finał
  /// 4. Koniec turnieju
  void startNextMatchDecision() {
    _currentMatchRound = null;
    _currentMatchIndex = null;
    _currentMatchDisplayPlayers = null;
    _isThirdPlaceMatchActive = false;

    final int grandFinalRound = bracket.length - 1;
    final int semiFinalRound = bracket.length > 1 ? bracket.length - 2 : -1;

    // 1. Szukaj meczów zwykłych (oprócz finału)
    for (int r = 0; r < grandFinalRound; r++) {
      for (int m = 0; m < bracket[r].length; m++) {
        Match match = bracket[r][m];
        if (match.winner == null &&
            match.player1 != null &&
            match.player2 != null) {
          _currentMatchRound = r;
          _currentMatchIndex = m;
          _currentMatchDisplayPlayers = (match.player1!, match.player2!);
          notifyListeners();
          return;
        }
      }
    }

    // 2. Przygotuj mecz o 3. miejsce (gracze przegrywający z półfinałów)
    if (semiFinalRound != -1) {
      final Match sf1 = bracket[semiFinalRound][0];
      final Match sf2 = bracket[semiFinalRound][1];

      if (sf1.winner != null && sf2.winner != null) {
        int? loser1;
        if (sf1.player1 != null && sf1.player2 != null) {
          loser1 = (sf1.winner == sf1.player1) ? sf1.player2 : sf1.player1;
        }

        int? loser2;
        if (sf2.player1 != null && sf2.player2 != null) {
          loser2 = (sf2.winner == sf2.player1) ? sf2.player2 : sf2.player1;
        }

        if (loser1 != null &&
            loser2 != null &&
            thirdPlaceMatch!.player1 == null &&
            thirdPlaceMatch!.player2 == null) {
          thirdPlaceMatch!.player1 = loser1;
          thirdPlaceMatch!.player2 = loser2;
        }
      }
    }

    // 3. Aktywuj mecz o 3. miejsce jeśli gracze są przypisani
    if (thirdPlaceMatch!.player1 != null &&
        thirdPlaceMatch!.player2 != null &&
        thirdPlaceMatch!.winner == null) {
      _isThirdPlaceMatchActive = true;
      _currentMatchDisplayPlayers =
          (thirdPlaceMatch!.player1!, thirdPlaceMatch!.player2!);
      notifyListeners();
      return;
    }

    // 4. Aktywuj finał jeśli mecz o 3. miejsce jest rozstrzygnięty
    final Match grandFinalMatch = bracket[grandFinalRound][0];
    bool isThirdPlaceResolved = (thirdPlaceMatch?.winner != null ||
        (thirdPlaceMatch?.player1 == null && thirdPlaceMatch?.player2 == null));

    if (isThirdPlaceResolved &&
        grandFinalMatch.winner == null &&
        grandFinalMatch.player1 != null &&
        grandFinalMatch.player2 != null) {
      _currentMatchRound = grandFinalRound;
      _currentMatchIndex = 0;
      _currentMatchDisplayPlayers =
          (grandFinalMatch.player1!, grandFinalMatch.player2!);
      notifyListeners();
      return;
    }

    notifyListeners();
  }

  /// Zapisuje wynik dla bieżącego meczu i przechodzi do następnego.
  void selectWinner(int chosenPlayerId) {
    if (_currentMatchDisplayPlayers == null) {
      return;
    }

    if (_isThirdPlaceMatchActive) {
      // Obsłuż mecz o 3. miejsce
      Match currentMatch = thirdPlaceMatch!;
      if (chosenPlayerId != currentMatch.player1 &&
          chosenPlayerId != currentMatch.player2) {
        return;
      }
      currentMatch.winner = chosenPlayerId;
      _isThirdPlaceMatchActive = false;
    } else {
      // Obsłuż mecz zwykły
      if (_currentMatchRound == null || _currentMatchIndex == null) {
        return;
      }

      Match currentMatch = bracket[_currentMatchRound!][_currentMatchIndex!];
      if (chosenPlayerId != currentMatch.player1 &&
          chosenPlayerId != currentMatch.player2) {
        return;
      }

      currentMatch.winner = chosenPlayerId;

      // Przenieś zwycięzcę do następnej rundy
      if (_currentMatchRound! < bracket.length - 1) {
        _advanceWinner(
          bracket,
          _currentMatchRound!,
          _currentMatchIndex!,
          chosenPlayerId,
        );
      }
    }

    // Wyczyść stan i szukaj następnego meczu
    _currentMatchRound = null;
    _currentMatchIndex = null;
    _currentMatchDisplayPlayers = null;
    notifyListeners();
    startNextMatchDecision();
  }
}
