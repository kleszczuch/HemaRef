import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'settings.dart';
import 'tournament_data.dart';
import 'round.dart';
import 'user_search_dialog.dart';

class TournamentSetupScreen extends StatefulWidget {
  const TournamentSetupScreen({super.key});

  @override
  State<TournamentSetupScreen> createState() => _TournamentSetupScreenState();
}

class _TournamentSetupScreenState extends State<TournamentSetupScreen> {
  int _playerCount = 4;
  int _maxPoints = 5;
  int _roundSeconds = 120;
  String _selectedWeapon = AppSettingsData.allWeapons.first;
  final List<TextEditingController> _controllers = [];
  final List<String?> _selectedUserUids = [];

  @override
  void initState() {
    super.initState();
    _updateControllers();
  }

  void _updateControllers() {
    while (_controllers.length < _playerCount) {
      _controllers.add(TextEditingController(
        text: 'Zawodnik ${_controllers.length + 1}',
      ));
      _selectedUserUids.add(null);
    }
    while (_controllers.length > _playerCount) {
      _controllers.removeLast().dispose();
      _selectedUserUids.removeLast();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ustawienia turnieju'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Text('Ilość zawodników: ',
                      style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _playerCount,
                    items: [2, 4, 8, 16, 32]
                        .map((n) => DropdownMenuItem(
                              value: n,
                              child: Text('$n'),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _playerCount = val;
                          _updateControllers();
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  const Text('Maks. punkty: ',
                      style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _maxPoints,
                    items: [5, 7, 10]
                        .map((n) => DropdownMenuItem(
                              value: n,
                              child: Text('$n'),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _maxPoints = val);
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  const Text('Czas rundy: ',
                      style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _roundSeconds,
                    items: [120, 150, 180]
                        .map((n) => DropdownMenuItem(
                              value: n,
                              child: Text(
                                  '${n ~/ 60}:${(n % 60).toString().padLeft(2, '0')}'),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _roundSeconds = val);
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  const Text('Broń: ',
                      style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _selectedWeapon,
                    items: AppSettingsData.allWeapons
                        .map((w) => DropdownMenuItem(
                              value: w,
                              child: Text(w),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedWeapon = val);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _playerCount,
                itemBuilder: (context, index) {
                  final bool isFromDb = _selectedUserUids[index] != null;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controllers[index],
                            readOnly: isFromDb,
                            decoration: InputDecoration(
                              labelText: 'Zawodnik ${index + 1}',
                              border: const OutlineInputBorder(),
                              suffixIcon: isFromDb
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      tooltip: 'Usuń wybór z bazy',
                                      onPressed: () {
                                        setState(() {
                                          _selectedUserUids[index] = null;
                                          _controllers[index].text =
                                              'Zawodnik ${index + 1}';
                                        });
                                      },
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.person_search),
                          tooltip: 'Wybierz z bazy',
                          onPressed: () async {
                            final alreadySelected = _selectedUserUids
                                .whereType<String>()
                                .toSet();
                            final currentUid =
                                FirebaseAuth.instance.currentUser?.uid;
                            final excludeUids = <String>{
                              ...alreadySelected,
                              if (currentUid != null) currentUid,
                            };
                            final result =
                                await Navigator.push<UserSearchResult>(
                              context,
                              MaterialPageRoute<UserSearchResult>(
                                builder: (_) => UserSearchDialog(
                                  excludeUids: excludeUids,
                                  title: 'Wybierz zawodnika ${index + 1}',
                                  friendsOnly: true,
                                ),
                              ),
                            );
                            if (result != null && mounted) {
                              setState(() {
                                _selectedUserUids[index] = result.uid;
                                _controllers[index].text = result.name;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {
                  final names = _controllers
                      .map((c) => c.text.trim())
                      .where((n) => n.isNotEmpty)
                      .toList();
                  if (names.length < 2) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Wpisz co najmniej 2 zawodników')),
                    );
                    return;
                  }
                  final bracketData =
                      Provider.of<BracketData>(context, listen: false);
                  bracketData.playerNames = {
                    for (int i = 0; i < names.length; i++) i + 1: names[i]
                  };
                  bracketData.playerUids = {
                    for (int i = 0; i < names.length; i++)
                      i + 1: _selectedUserUids[i]
                  };
                  bracketData.fightResults = [];
                  bracketData.initializeTournamentWithPlayers(
                    List.generate(names.length, (i) => i + 1),
                    shuffle: true,
                  );
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (context) => BracketScreen(
                        maxPoints: _maxPoints,
                        roundSeconds: _roundSeconds,
                        weapon: _selectedWeapon,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('Rozpocznij turniej',
                    style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// =======================================================
/// EKRAN - UI turnieju
/// =======================================================
class BracketScreen extends StatefulWidget {
  final int maxPoints;
  final int roundSeconds;
  final String weapon;

  const BracketScreen({
    super.key,
    this.maxPoints = 5,
    this.roundSeconds = 120,
    this.weapon = 'Szabla',
  });

  @override
  State<BracketScreen> createState() => _BracketScreenState();
}

class _BracketScreenState extends State<BracketScreen> {
  bool _fightInProgress = false;

  String _getPlayerName(BracketData bd, int id) {
    return bd.playerNames[id] ?? 'Zawodnik $id';
  }

  Future<void> _startFight(BracketData bracketData) async {
    if (_fightInProgress) return;
    final players = bracketData.currentMatchDisplayPlayers;
    if (players == null) return;

    setState(() => _fightInProgress = true);

    final p1Name = _getPlayerName(bracketData, players.$1);
    final p2Name = _getPlayerName(bracketData, players.$2);

    final MatchResult? result = await Navigator.push<MatchResult>(
      context,
      MaterialPageRoute<MatchResult>(
        builder: (context) => TimerDecisionScreen(
          blueName: p1Name,
          yellowName: p2Name,
          maxPoints: widget.maxPoints,
          roundSeconds: widget.roundSeconds,
        ),
      ),
    );

    if (!mounted) return;
    setState(() => _fightInProgress = false);

    if (result == null) return;

    // Determine winner player id
    int winnerId;
    if (result.winner == 'Niebieski') {
      winnerId = players.$1;
    } else if (result.winner == 'Żółty') {
      winnerId = players.$2;
    } else {
      // Remis - losowo lub gracz z firstPoint
      winnerId = players.$1; // default to player 1
    }

    // Save fight result
    bracketData.fightResults.add({
      'player1': p1Name,
      'player1Id': players.$1,
      'player2': p2Name,
      'player2Id': players.$2,
      'winner': _getPlayerName(bracketData, winnerId),
      'winnerId': winnerId,
      'bluePoints': result.bluePoints,
      'yellowPoints': result.yellowPoints,
      'remainingSeconds': result.remainingSeconds,
      'blueYellowCards': result.blueYellowCards,
      'blueRedCards': result.blueRedCards,
      'yellowYellowCards': result.yellowYellowCards,
      'yellowRedCards': result.yellowRedCards,
    });

    // Zapisz do kolekcji matches jeśli obaj gracze są z bazy
    final p1Uid = bracketData.playerUids[players.$1];
    final p2Uid = bracketData.playerUids[players.$2];
    if (p1Uid != null && p2Uid != null) {
      FirebaseFirestore.instance.collection('matches').add(<String, dynamic>{
        'type': 'tournament',
        'weapon': widget.weapon,
        'playerX': p1Name,
        'playerY': p2Name,
        'userId': p1Uid,
        'opponentUid': p2Uid,
        'winner': result.winner == 'Niebieski'
            ? p1Name
            : result.winner == 'Żółty'
                ? p2Name
                : 'Remis',
        'pointsX': result.bluePoints,
        'pointsY': result.yellowPoints,
        'remainingSeconds': result.remainingSeconds,
        'blueYellowCards': result.blueYellowCards,
        'blueRedCards': result.blueRedCards,
        'yellowYellowCards': result.yellowYellowCards,
        'yellowRedCards': result.yellowRedCards,
        'maxPoints': widget.maxPoints,
        'roundSeconds': widget.roundSeconds,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    bracketData.selectWinner(winnerId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<BracketData>(
          builder: (BuildContext context, BracketData bracketData, Widget? child) {
            if (bracketData.bracket.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            // Oblicz wymiary canvasu na podstawie struktury turnieju
            final double initialPadding = 50;
            final double dynamicPlayerTextMaxWidth = 180;
            final double roundSpacing =
                BracketPainter.roundHorizontalSpacing +
                BracketPainter.subsequentRoundNameOffset;

            final double bracketWidth =
                initialPadding +
                (bracketData.bracket.length * roundSpacing) +
                dynamicPlayerTextMaxWidth +
                BracketPainter.playerNameToLineGap +
                BracketPainter.playerLineLength +
                initialPadding +
                100;

            final double baseMatchBlockHeight =
                BracketPainter.playerTextHeight * 2 +
                BracketPainter.verticalMatchLineLength +
                20;
            double actualCanvasHeight =
                (bracketData.bracket[0].length * baseMatchBlockHeight) + 50;

            // Dodaj wysokość dla meczu o 3. miejsce
            if (bracketData.thirdPlaceMatch != null &&
                bracketData.thirdPlaceMatch!.player1 != null &&
                bracketData.thirdPlaceMatch!.player2 != null &&
                bracketData.bracket.isNotEmpty) {
              actualCanvasHeight +=
                  BracketPainter.playerTextHeight * 2 + 10 + 30 + 100;
            }

            final bool hasActiveMatch =
                bracketData.currentMatchDisplayPlayers != null;

            // Check if tournament is finished
            final bool tournamentFinished =
                !hasActiveMatch &&
                bracketData.currentMatchRound == null &&
                bracketData.currentMatchIndex == null &&
                !bracketData.isThirdPlaceMatchActive &&
                bracketData.bracket.isNotEmpty &&
                bracketData.bracket.last.first.winner != null &&
                (bracketData.thirdPlaceMatch == null ||
                    bracketData.thirdPlaceMatch!.winner != null);

            return Stack(
              children: <Widget>[
                Column(
                  children: <Widget>[
                    // Sekcja z informacją o aktualnym meczu i przyciskiem walki
                    if (hasActiveMatch)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: <Widget>[
                            Text(
                              bracketData.isThirdPlaceMatchActive
                                  ? 'Mecz o 3. miejsce'
                                  : (bracketData.currentMatchRound ==
                                        bracketData.bracket.length - 1)
                                  ? 'FINAŁ'
                                  : 'Runda ${bracketData.currentMatchRound! + 1}, Mecz ${bracketData.currentMatchIndex! + 1}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_getPlayerName(bracketData, bracketData.currentMatchDisplayPlayers!.$1)}'
                              ' vs '
                              '${_getPlayerName(bracketData, bracketData.currentMatchDisplayPlayers!.$2)}',
                              style: const TextStyle(fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _fightInProgress
                                  ? null
                                  : () => _startFight(bracketData),
                              icon: const Icon(Icons.sports_kabaddi),
                              label: const Text('Rozpocznij walkę'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(200, 48),
                              ),
                            ),
                          ],
                        ),
                      )
                    // Komunikat o zakończeniu turnieju
                    else if (tournamentFinished)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Builder(
                          builder: (BuildContext context) {
                            String completionMessage = 'Turniej zakończony! ';
                            final int? grandFinalWinner =
                                bracketData.bracket.last.first.winner;
                            final int? thirdPlaceWinner =
                                bracketData.thirdPlaceWinner;

                            if (grandFinalWinner != null) {
                              completionMessage +=
                                  'Zwycięzca: ${_getPlayerName(bracketData, grandFinalWinner)}. ';
                            }
                            if (thirdPlaceWinner != null) {
                              completionMessage +=
                                  '3. miejsce: ${_getPlayerName(bracketData, thirdPlaceWinner)}.';
                            }

                            return Text(
                              completionMessage,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            );
                          },
                        ),
                      )
                    // Inicjalizacja
                    else if (bracketData.bracket.isNotEmpty &&
                        bracketData.currentMatchDisplayPlayers == null)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          '⏳ Inicjalizacja turnieju...',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      const SizedBox.shrink(),

                    // Canvas z drabinką
                    Expanded(
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 3,
                        constrained: false,
                        child: CustomPaint(
                          size: Size(bracketWidth, actualCanvasHeight),
                          painter: BracketPainter(
                            bracketData.bracket,
                            bracketData.thirdPlaceMatch,
                            bracketData.version,
                            bracketData.playerNames,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  bottom: 24,
                  left: 24,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Zakończ mecz'),
                  ),
                ),
                Positioned(
                  bottom: 24,
                  right: 24,
                  child: ElevatedButton(
                    onPressed: () async {
                      final payload = bracketData.buildTournamentPayload();
                      final doc = await FirebaseFirestore.instance
                          .collection('tournaments')
                          .add(<String, dynamic>{
                            ...payload,
                            'weapon': widget.weapon,
                            'fightResults': bracketData.fightResults,
                            'userId': FirebaseAuth.instance.currentUser?.uid,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Zapisano turniej: ${doc.id}')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Zapisz turniej'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// =======================================================
/// PAINTER - Rysowanie drabinki
/// =======================================================

/// Odpowiada za wizualizację drabinki turnieju.
/// Rysuje:
/// - Graczy i ich linie (poziome i pionowe)
/// - Połączenia między rundami
/// - Zwycięzców
/// - Mecz o 3. miejsce
class BracketPainter extends CustomPainter {
  final List<List<Match>> bracket;
  final Match? thirdPlaceMatch;
  final int version; // Wymusza repaint przy każdej zmianie
  final Map<int, String> playerNames;

  BracketPainter(this.bracket, this.thirdPlaceMatch, this.version, this.playerNames);

  final Paint linePaint = Paint()
    ..color = Colors.black
    ..strokeWidth = 2;

  // ============ STAŁE LAYOUTU ============
  static const double playerTextHeight = 20;
  static const double playerLineVerticalOffset = 7;
  static const double playerLineLength = 80;
  static const double verticalMatchLineLength = 30;
  static const double playerNameToLineGap = 10;
  static const double roundHorizontalSpacing = 180;
  static const double subsequentRoundNameOffset = 60;

  // Cache dla współrzędnych Y meczów (optymalizacja wydajności)
  final Map<String, double> _matchCenterYCache = <String, double>{};

  /// Oblicza współrzędną Y dla środka linii zwycięzcy w danym meczu.
  /// Dla rundy 0: rozłożone równomiernie
  /// Dla kolejnych rund: średnia z dwóch meczów wcześniejszych
  double _getMatchCenterY(int r, int m, double canvasHeight) {
    final String key = '$r-$m';
    if (_matchCenterYCache.containsKey(key)) {
      return _matchCenterYCache[key]!;
    }

    double centerY;
    if (r == 0) {
      final double baseMatchBlockHeight =
          playerTextHeight * 2 + verticalMatchLineLength + 20;
      final double totalHeightForRound0 =
          bracket[0].length * baseMatchBlockHeight;
      final double startYOffset = (canvasHeight - totalHeightForRound0) / 2;
      centerY =
          startYOffset +
          (m * baseMatchBlockHeight) +
          (baseMatchBlockHeight / 2);
    } else {
      // Średnia pozycji z dwóch meczów poprzedniej rundy
      final double parent1Y = _getMatchCenterY(r - 1, 2 * m, canvasHeight);
      final double parent2Y = _getMatchCenterY(r - 1, 2 * m + 1, canvasHeight);
      centerY = (parent1Y + parent2Y) / 2;
    }

    _matchCenterYCache[key] = centerY;
    return centerY;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _matchCenterYCache.clear(); // Wyczyść cache na początek

    final double canvasHeight = size.height;

    // PASS 1: Rysuj graczy, linie indywidualne i połączenia w meczu
    final List<List<Offset>> matchWinnerExitPoints = <List<Offset>>[];

    for (int r = 0; r < bracket.length; r++) {
      matchWinnerExitPoints.add(<Offset>[]);

      final bool isFinalRound = (r == bracket.length - 1);
      final double currentRoundTextStartX =
          50 + r * (roundHorizontalSpacing + subsequentRoundNameOffset);

      for (int m = 0; m < bracket[r].length; m++) {
        final Match match = bracket[r][m];
        final double matchCenterY = _getMatchCenterY(r, m, canvasHeight);

        // Pozycje Y graczy
        final double player1TextY =
            matchCenterY -
            (verticalMatchLineLength / 2) -
            playerTextHeight +
            playerLineVerticalOffset;
        final double player2TextY =
            matchCenterY +
            (verticalMatchLineLength / 2) -
            playerTextHeight +
            playerLineVerticalOffset;

        // Rysuj gracze (pogrubienie dla zwycięzców w rundach przedfinałowych)
        _drawPlayer(
          canvas,
          match.player1,
          currentRoundTextStartX,
          player1TextY,
          isWinner: !isFinalRound && (match.winner == match.player1),
        );
        _drawPlayer(
          canvas,
          match.player2,
          currentRoundTextStartX,
          player2TextY,
          isWinner: !isFinalRound && (match.winner == match.player2),
        );

        // Oblicz szerokość tekstu dla wyrównania linii
        final String player1Text = match.player1 == null
            ? 'BYE'
            : (playerNames[match.player1!] ?? 'Zawodnik ${match.player1}');
        final String player2Text = match.player2 == null
            ? 'BYE'
            : (playerNames[match.player2!] ?? 'Zawodnik ${match.player2}');
        final double maxTextWidth = max(
          _getTextWidth(player1Text, const TextStyle(fontSize: 14)),
          _getTextWidth(player2Text, const TextStyle(fontSize: 14)),
        );

        // Współrzędne dla linii
        final double horizontalLineStartX =
            currentRoundTextStartX + maxTextWidth + playerNameToLineGap;
        final double horizontalLineEndX =
            horizontalLineStartX + playerLineLength;

        // Rysuj linie poziome dla każdego gracza
        canvas.drawLine(
          Offset(horizontalLineStartX, player1TextY + playerLineVerticalOffset),
          Offset(horizontalLineEndX, player1TextY + playerLineVerticalOffset),
          linePaint,
        );
        canvas.drawLine(
          Offset(horizontalLineStartX, player2TextY + playerLineVerticalOffset),
          Offset(horizontalLineEndX, player2TextY + playerLineVerticalOffset),
          linePaint,
        );

        // Rysuj linię pionową łączącą obydwu graczy
        canvas.drawLine(
          Offset(horizontalLineEndX, player1TextY + playerLineVerticalOffset),
          Offset(horizontalLineEndX, player2TextY + playerLineVerticalOffset),
          linePaint,
        );

        // Zapamiętaj punkt wyjścia zwycięzcy
        matchWinnerExitPoints[r].add(Offset(horizontalLineEndX, matchCenterY));
      }
    }

    // PASS 2: Rysuj połączenia zwycięzców między rundami
    for (int r = 0; r < bracket.length - 1; r++) {
      for (int m = 0; m < bracket[r + 1].length; m++) {
        final Offset winner1Point = matchWinnerExitPoints[r][2 * m];
        final Offset winner2Point = matchWinnerExitPoints[r][2 * m + 1];

        final double connectionLineX =
            winner1Point.dx + roundHorizontalSpacing / 2;

        // Linie poziome od wyjść do linii połączenia
        canvas.drawLine(
          winner1Point,
          Offset(connectionLineX, winner1Point.dy),
          linePaint,
        );
        canvas.drawLine(
          winner2Point,
          Offset(connectionLineX, winner2Point.dy),
          linePaint,
        );

        // Linia pionowa łącząca zwycięzców
        canvas.drawLine(
          Offset(connectionLineX, winner1Point.dy),
          Offset(connectionLineX, winner2Point.dy),
          linePaint,
        );

        // Finalna linia pozioma do następnego meczu
        final double nextMatchInputY = (winner1Point.dy + winner2Point.dy) / 2;
        final double nextRoundPlayerTextStartX =
            50 + (r + 1) * (roundHorizontalSpacing + subsequentRoundNameOffset);

        canvas.drawLine(
          Offset(connectionLineX, nextMatchInputY),
          Offset(nextRoundPlayerTextStartX, nextMatchInputY),
          linePaint,
        );
      }
    }

    // PASS 3: Rysuj mecz o 3. miejsce (jeśli istnieje)
    _drawThirdPlaceMatch(canvas, canvasHeight);

    // PASS 4: Rysuj zwycięzcę finału
    _drawGrandFinalWinner(canvas, canvasHeight);
  }

  /// Rysuje mecz o 3. miejsce poniżej głównej drabinki.
  void _drawThirdPlaceMatch(Canvas canvas, double canvasHeight) {
    if (thirdPlaceMatch == null ||
        thirdPlaceMatch!.player1 == null ||
        thirdPlaceMatch!.player2 == null) {
      return;
    }

    final double finalRoundPlayerTextStartX =
        50 +
        (bracket.length - 1) *
            (roundHorizontalSpacing + subsequentRoundNameOffset);
    final double thirdPlaceMatchTextStartX = finalRoundPlayerTextStartX;

    double maxYOfMainBracket = 0;
    if (bracket.isNotEmpty) {
      maxYOfMainBracket = _getMatchCenterY(bracket.length - 1, 0, canvasHeight);
    }

    final double thirdPlaceMatchBaseY = maxYOfMainBracket + 100;

    // Etykieta "Mecz o 3. miejsce"
    final TextPainter labelPainter = TextPainter(
      text: const TextSpan(
        text: 'Mecz o 3. miejsce',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.purple,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelPainter.paint(
      canvas,
      Offset(thirdPlaceMatchTextStartX, thirdPlaceMatchBaseY - 30),
    );

    final double player1Y = thirdPlaceMatchBaseY;
    final double player2Y = thirdPlaceMatchBaseY + playerTextHeight + 10;

    // Rysuj graczy
    _drawPlayer(
      canvas,
      thirdPlaceMatch!.player1,
      thirdPlaceMatchTextStartX,
      player1Y,
    );
    _drawPlayer(
      canvas,
      thirdPlaceMatch!.player2,
      thirdPlaceMatchTextStartX,
      player2Y,
    );

    // Oblicz szerokość tekstu
    final String p1Text = thirdPlaceMatch!.player1 == null
        ? 'BYE'
        : (playerNames[thirdPlaceMatch!.player1!] ?? 'Zawodnik ${thirdPlaceMatch!.player1}');
    final String p2Text = thirdPlaceMatch!.player2 == null
        ? 'BYE'
        : (playerNames[thirdPlaceMatch!.player2!] ?? 'Zawodnik ${thirdPlaceMatch!.player2}');
    final double maxTextWidth = max(
      _getTextWidth(p1Text, const TextStyle(fontSize: 14)),
      _getTextWidth(p2Text, const TextStyle(fontSize: 14)),
    );

    final double horizontalLineStartX =
        thirdPlaceMatchTextStartX + maxTextWidth + playerNameToLineGap;
    final double horizontalLineEndX = horizontalLineStartX + playerLineLength;

    // Rysuj linie
    canvas.drawLine(
      Offset(horizontalLineStartX, player1Y + playerLineVerticalOffset),
      Offset(horizontalLineEndX, player1Y + playerLineVerticalOffset),
      linePaint,
    );
    canvas.drawLine(
      Offset(horizontalLineStartX, player2Y + playerLineVerticalOffset),
      Offset(horizontalLineEndX, player2Y + playerLineVerticalOffset),
      linePaint,
    );
    canvas.drawLine(
      Offset(horizontalLineEndX, player1Y + playerLineVerticalOffset),
      Offset(horizontalLineEndX, player2Y + playerLineVerticalOffset),
      linePaint,
    );

    // Rysuj zwycięzcę jeśli wyznaczony
    if (thirdPlaceMatch!.winner != null) {
      final TextPainter winnerPainter = TextPainter(
        text: TextSpan(
          text: 'Zwycięzca: ${playerNames[thirdPlaceMatch!.winner!] ?? 'Zawodnik ${thirdPlaceMatch!.winner}'}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      winnerPainter.paint(
        canvas,
        Offset(
          horizontalLineEndX + playerNameToLineGap,
          (player1Y + player2Y) / 2 - winnerPainter.height / 2,
        ),
      );
    }
  }

  /// Rysuje tekst zwycięzcy finału.
  void _drawGrandFinalWinner(Canvas canvas, double canvasHeight) {
    final int grandFinalRound = bracket.length - 1;
    if (grandFinalRound < 0 || bracket[grandFinalRound].isEmpty) {
      return;
    }

    final Match grandFinalMatch = bracket[grandFinalRound][0];
    if (grandFinalMatch.winner == null) {
      return;
    }

    final double grandFinalMatchCenterY = _getMatchCenterY(
      grandFinalRound,
      0,
      canvasHeight,
    );
    final double finalRoundTextStartX =
        50 +
        grandFinalRound * (roundHorizontalSpacing + subsequentRoundNameOffset);

    final String player1Text = grandFinalMatch.player1 == null
        ? 'BYE'
        : (playerNames[grandFinalMatch.player1!] ?? 'Zawodnik ${grandFinalMatch.player1}');
    final String player2Text = grandFinalMatch.player2 == null
        ? 'BYE'
        : (playerNames[grandFinalMatch.player2!] ?? 'Zawodnik ${grandFinalMatch.player2}');
    final double maxTextWidth = max(
      _getTextWidth(player1Text, const TextStyle(fontSize: 14)),
      _getTextWidth(player2Text, const TextStyle(fontSize: 14)),
    );
    final double finalMatchHorizontalLineEndX =
        finalRoundTextStartX +
        maxTextWidth +
        playerNameToLineGap +
        playerLineLength;

    final TextPainter winnerPainter = TextPainter(
      text: TextSpan(
        text: 'Zwycięzca: ${playerNames[grandFinalMatch.winner!] ?? 'Zawodnik ${grandFinalMatch.winner}'}',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    winnerPainter.paint(
      canvas,
      Offset(
        finalMatchHorizontalLineEndX + playerNameToLineGap,
        grandFinalMatchCenterY - winnerPainter.height / 2,
      ),
    );
  }

  /// Rysuje tekst gracza z opcjonalnym pogrubieniem dla zwycięzców.
  void _drawPlayer(
    Canvas canvas,
    int? id,
    double x,
    double y, {
    bool isWinner = false,
  }) {
    final String text = id == null ? 'BYE' : (playerNames[id] ?? 'Zawodnik $id');

    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 14,
          color: isWinner ? Colors.blue.shade800 : Colors.black,
          fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, Offset(x, y));
  }

  /// Oblicza szerokość tekstu (pomocnicza dla wyrównania).
  double _getTextWidth(String text, TextStyle style) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    return textPainter.width;
  }

  @override
  bool shouldRepaint(covariant BracketPainter oldDelegate) {
    return oldDelegate.version != version;
  }
}
