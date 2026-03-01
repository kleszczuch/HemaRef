import 'dart:async';
import 'package:flutter/material.dart';

class MatchResult {
  final String winner;
  final int bluePoints;
  final int yellowPoints;
  final int remainingSeconds;
  final int blueYellowCards;
  final int blueRedCards;
  final int yellowYellowCards;
  final int yellowRedCards;

  const MatchResult({
    required this.winner,
    required this.bluePoints,
    required this.yellowPoints,
    required this.remainingSeconds,
    this.blueYellowCards = 0,
    this.blueRedCards = 0,
    this.yellowYellowCards = 0,
    this.yellowRedCards = 0,
  });
}

enum _ActionType { points, yellowCard, redCard, addTime }

class _MatchAction {
  final _ActionType type;
  final String color; // "Niebieski" lub "Żółty"
  final int value; // punkty lub sekundy
  const _MatchAction(this.type, this.color, this.value);
}

class TimerDecisionScreen extends StatefulWidget {
  final String blueName;
  final String yellowName;
  final int maxPoints;
  final int roundSeconds;

  const TimerDecisionScreen({
    super.key,
    this.blueName = 'NIEBIESKI',
    this.yellowName = 'ŻÓŁTY',
    this.maxPoints = 5,
    this.roundSeconds = 120,
  });

  @override
  State<TimerDecisionScreen> createState() => _TimerDecisionScreenState();
}

class _TimerDecisionScreenState extends State<TimerDecisionScreen> {
  Timer? timer;
  late int seconds;
  bool running = true;
  int yellowPoint = 0;
  int bluePoint = 0;
  int firstPoint = 0;

  // Kartki
  int blueYellowCards = 0;
  int blueRedCards = 0;
  int yellowYellowCards = 0;
  int yellowRedCards = 0;

  // Historia akcji do cofania
  final List<_MatchAction> _actionHistory = [];

  @override
  void initState() {
    super.initState();
    seconds = widget.roundSeconds;
    startTimer();
  }

  void _checkEnd() {
    final isTimeOver = seconds <= 0;
    final isBlueWinner = bluePoint >= widget.maxPoints;
    final isYellowWinner = yellowPoint >= widget.maxPoints;
    if (!isTimeOver && !isBlueWinner && !isYellowWinner) return;
    finishMatch();
  }

  String _determineWinner() {
    if (bluePoint > yellowPoint) return "Niebieski";
    if (yellowPoint > bluePoint) return "Żółty";
    if (firstPoint == 1) return "Niebieski";
    if (firstPoint == 2) return "Żółty";
    return "Remis";
  }

  void finishMatch() {
    stopTimer();
    if (!mounted) return;
    final result = MatchResult(
      winner: _determineWinner(),
      bluePoints: bluePoint,
      yellowPoints: yellowPoint,
      remainingSeconds: seconds < 0 ? 0 : seconds,
      blueYellowCards: blueYellowCards,
      blueRedCards: blueRedCards,
      yellowYellowCards: yellowYellowCards,
      yellowRedCards: yellowRedCards,
    );
    Navigator.of(context).pop(result);
  }

  void startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _checkEnd();
        seconds--;
      });
    });
    running = true;
  }

  void stopTimer() {
    timer?.cancel();
    running = false;
  }

  void _addPoints(String color, int points) {
    setState(() {
      if (bluePoint == 0 && yellowPoint == 0 && firstPoint == 0) {
        firstPoint = color == "Niebieski" ? 1 : 2;
      }
      if (color == "Niebieski") {
        bluePoint += points;
      } else {
        yellowPoint += points;
      }
      _actionHistory.add(_MatchAction(_ActionType.points, color, points));
      _checkEnd();
    });
  }

  void _giveYellowCard(String color) {
    setState(() {
      if (color == "Niebieski") {
        blueYellowCards++;
        if (blueYellowCards >= 2) {
          blueYellowCards -= 2;
          blueRedCards++;
          // Czerwona kartka = 1 punkt dla przeciwnika
          yellowPoint++;
          _actionHistory.add(
            _MatchAction(_ActionType.redCard, "Niebieski", 1),
          );
        } else {
          _actionHistory.add(
            _MatchAction(_ActionType.yellowCard, "Niebieski", 1),
          );
        }
      } else {
        yellowYellowCards++;
        if (yellowYellowCards >= 2) {
          yellowYellowCards -= 2;
          yellowRedCards++;
          bluePoint++;
          _actionHistory.add(
            _MatchAction(_ActionType.redCard, "Żółty", 1),
          );
        } else {
          _actionHistory.add(
            _MatchAction(_ActionType.yellowCard, "Żółty", 1),
          );
        }
      }
      _checkEnd();
    });
  }

  void _giveRedCard(String color) {
    setState(() {
      if (color == "Niebieski") {
        blueRedCards++;
        yellowPoint++;
      } else {
        yellowRedCards++;
        bluePoint++;
      }
      _actionHistory.add(_MatchAction(_ActionType.redCard, color, 1));
      _checkEnd();
    });
  }

  void _addTime(int extraSeconds) {
    setState(() {
      seconds += extraSeconds;
      _actionHistory.add(
        _MatchAction(_ActionType.addTime, "", extraSeconds),
      );
    });
  }

  void _undoLastAction() {
    if (_actionHistory.isEmpty) return;
    setState(() {
      final action = _actionHistory.removeLast();
      switch (action.type) {
        case _ActionType.points:
          if (action.color == "Niebieski") {
            bluePoint = (bluePoint - action.value).clamp(0, 999);
          } else {
            yellowPoint = (yellowPoint - action.value).clamp(0, 999);
          }
          break;
        case _ActionType.yellowCard:
          if (action.color == "Niebieski") {
            blueYellowCards = (blueYellowCards - 1).clamp(0, 999);
          } else {
            yellowYellowCards = (yellowYellowCards - 1).clamp(0, 999);
          }
          break;
        case _ActionType.redCard:
          if (action.color == "Niebieski") {
            blueRedCards = (blueRedCards - 1).clamp(0, 999);
            yellowPoint = (yellowPoint - 1).clamp(0, 999);
          } else {
            yellowRedCards = (yellowRedCards - 1).clamp(0, 999);
            bluePoint = (bluePoint - 1).clamp(0, 999);
          }
          break;
        case _ActionType.addTime:
          seconds -= action.value;
          break;
      }
    });
  }

  Future<void> _showPointsScreen() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (ctx, _, __) => _FullScreenPointsPage(),
      ),
    );
    if (!mounted || result == null) return;
    _addPoints(result["color"] as String, result["points"] as int);
  }

  Future<void> _showCardScreen() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (ctx, _, __) => _FullScreenCardPage(),
      ),
    );
    if (!mounted || result == null) return;
    final color = result["color"] as String;
    final cardType = result["card"] as String;
    if (cardType == "yellow") {
      _giveYellowCard(color);
    } else {
      _giveRedCard(color);
    }
  }

  Future<void> _showActionMenu() async {
    stopTimer();
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add, color: Colors.green),
              title: const Text('Dodaj punkty'),
              onTap: () => Navigator.pop(ctx, 'points'),
            ),
            ListTile(
              leading: const Icon(Icons.undo, color: Colors.orange),
              title: const Text('Cofnij ostatnią akcję'),
              enabled: _actionHistory.isNotEmpty,
              onTap: () => Navigator.pop(ctx, 'undo'),
            ),
            ListTile(
              leading: const Icon(Icons.timer, color: Colors.blue),
              title: const Text('Dodaj 10 sekund'),
              onTap: () => Navigator.pop(ctx, 'time'),
            ),
            ListTile(
              leading: const Icon(Icons.style, color: Colors.amber),
              title: const Text('Daj kartkę'),
              onTap: () => Navigator.pop(ctx, 'card'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.close, color: Colors.red),
              title: const Text('Zakończ mecz'),
              onTap: () => Navigator.pop(ctx, 'finish'),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;

    switch (action) {
      case 'points':
        await _showPointsScreen();
        break;
      case 'undo':
        _undoLastAction();
        break;
      case 'time':
        _addTime(10);
        break;
      case 'card':
        await _showCardScreen();
        break;
      case 'finish':
        finishMatch();
        return;
    }

    if (mounted) startTimer();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  String _formatTime(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _cardIcons(int yellowCards, int redCards) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (yellowCards > 0) ...[
          const Icon(Icons.square, color: Colors.amber, size: 16),
          if (yellowCards > 1) Text('x$yellowCards', style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
        ],
        if (redCards > 0) ...[
          const Icon(Icons.square, color: Colors.red, size: 16),
          if (redCards > 1) Text('x$redCards', style: const TextStyle(fontSize: 12)),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTap: running ? _showActionMenu : () { startTimer(); },
          child: Container(
            color: Colors.black,
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(seconds < 0 ? 0 : seconds),
                        style: const TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        running ? 'Kliknij aby zatrzymać' : 'Kliknij aby wznowić',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
                // Niebieski - lewa strona
                Positioned(
                  top: 16,
                  left: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.blueName,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.lightBlueAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$bluePoint',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.lightBlueAccent,
                        ),
                      ),
                      _cardIcons(blueYellowCards, blueRedCards),
                    ],
                  ),
                ),
                // Żółty - prawa strona
                Positioned(
                  top: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        widget.yellowName,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$yellowPoint',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.amberAccent,
                        ),
                      ),
                      _cardIcons(yellowYellowCards, yellowRedCards),
                    ],
                  ),
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FullScreenPointsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Niebieski
          Expanded(
            child: Column(
              children: [
                _pointButton(context, "Niebieski", 2, Colors.blue[700]!, Colors.white),
                _pointButton(context, "Niebieski", 1, Colors.blue[300]!, Colors.white),
              ],
            ),
          ),
          // Żółty
          Expanded(
            child: Column(
              children: [
                _pointButton(context, "Żółty", 2, Colors.yellow[700]!, Colors.black87),
                _pointButton(context, "Żółty", 1, Colors.yellow[300]!, Colors.black87),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pointButton(
    BuildContext context, String color, int points, Color bg, Color textColor,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop({"color": color, "points": points}),
        child: Container(
          color: bg,
          child: Center(
            child: Text(
              points == 1 ? "1 PUNKT" : "$points PUNKTY",
              style: TextStyle(
                fontSize: 32,
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FullScreenCardPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Wybór koloru kartki
            Expanded(
              child: Row(
              children: [
                // Niebieski żółta kartka
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop({
                      "color": "Niebieski",
                      "card": "yellow",
                    }),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue[700],
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.square, color: Colors.amber, size: 48),
                            SizedBox(height: 8),
                            Text(
                              "ŻÓŁTA KARTKA\nNIEBIESKI",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Żółty żółta kartka
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop({
                      "color": "Żółty",
                      "card": "yellow",
                    }),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.yellow[700],
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.square, color: Colors.amber, size: 48),
                            SizedBox(height: 8),
                            Text(
                              "ŻÓŁTA KARTKA\nŻÓŁTY",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                // Niebieski czerwona kartka
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop({
                      "color": "Niebieski",
                      "card": "red",
                    }),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue[400],
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.square, color: Colors.red, size: 48),
                            SizedBox(height: 8),
                            Text(
                              "CZERWONA KARTKA\nNIEBIESKI",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Żółty czerwona kartka
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop({
                      "color": "Żółty",
                      "card": "red",
                    }),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.yellow[300],
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.square, color: Colors.red, size: 48),
                            SizedBox(height: 8),
                            Text(
                              "CZERWONA KARTKA\nŻÓŁTY",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }
}
