import 'package:flutter/material.dart';
import 'dart:math';

class CardModel {
  final String rank;
  final String suit;

  CardModel(this.rank, this.suit);

  @override
  String toString() => '$rank$suit';
}

class Deck {
  final List<CardModel> _cards = [];

  Deck() {
    for (var suit in ['♠', '♥', '♦', '♣']) {
      for (var rank in [
        '2',
        '3',
        '4',
        '5',
        '6',
        '7',
        '8',
        '9',
        '10',
        'J',
        'Q',
        'K',
        'A',
      ]) {
        _cards.add(CardModel(rank, suit));
      }
    }
  }

  void shuffle() {
    _cards.shuffle();
  }

  CardModel draw() {
    return _cards.removeLast();
  }
}

// Custom painter for table arc and seat boxes (5 seats)
class TableArcPainter5 extends CustomPainter {
  final List<Offset> seatPositions;
  final Offset dealerPos;
  TableArcPainter5({required this.seatPositions, required this.dealerPos});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.7);
    final radius = size.width * 0.48;
    final arcPaint = Paint()
      ..color = Colors.transparent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFD700), Color(0xFFFFF8DC)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    // Draw arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi, // Start at left
      pi, // Sweep 180 degrees
      false,
      arcPaint,
    );
    // Removed seat rectangles and dealer rectangle
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

enum PlayerTurn { player1, computer, dealer, done }

int handValue(List<CardModel> hand) {
  int value = 0;
  int aces = 0;
  for (var card in hand) {
    if (card.rank == 'A') {
      aces++;
      value += 11;
    } else if (['K', 'Q', 'J'].contains(card.rank)) {
      value += 10;
    } else {
      value += int.parse(card.rank);
    }
  }
  while (value > 21 && aces > 0) {
    value -= 10;
    aces--;
  }
  return value;
}

class BlackjackGame extends StatefulWidget {
  const BlackjackGame({super.key});
  @override
  State<BlackjackGame> createState() => _BlackjackGameState();
}

class _BlackjackGameState extends State<BlackjackGame> {
  // Betting widget builder
  Widget bettingWidget({
    required bool isPlayer1,
    required List<int> chipValues,
    required Map<int, int> chips,
    required int selectedBet,
    required Map<int, int> tempBetChips,
    required bool locked,
    required void Function(int) onChipTap,
    required VoidCallback? onLock,
    required VoidCallback onClear,
  }) {
    return Column(
      children: [
        Text(
          isPlayer1 ? 'Your Bet' : 'Computer Bet',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          children: chipValues.map((chip) {
            return GestureDetector(
              onTap: locked ? null : () => onChipTap(chip),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.amber[700],
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        ' \$$chip', // Show as $10, $20, etc.
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    'x${chips[chip] ?? 0}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Text(
          'Selected Bet:  \$$selectedBet', // Show as $40, $100, etc.
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: locked ? null : onClear,
              child: const Text('Clear'),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: locked ? null : onLock,
              child: const Text('Lock Bet'),
            ),
          ],
        ),
      ],
    );
  }

  // --- Game state variables ---
  late Map<int, int> player1Chips;
  late Deck deck;
  List<CardModel> player1 = [];
  List<CardModel> computer = [];
  List<CardModel> dealer = [];
  PlayerTurn turn = PlayerTurn.player1;
  String result1 = '';
  String computerResult = '';
  bool dealerReveal = false;
  final int bettingLimit = 1000;

  @override
  void initState() {
    super.initState();
    player1Chips = Map<int, int>.from(initialPlayer1Chips);
    deck = Deck();
  }

  // Card widget for displaying a card
  Widget cardWidget(CardModel card, {bool hidden = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 48,
      height: 74,
      decoration: BoxDecoration(
        color: hidden ? Colors.grey[400] : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 3,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      child: hidden
          ? Center(
              child: Icon(Icons.help_outline, color: Colors.black45, size: 32),
            )
          : Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  child: Text(
                    card.rank,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: card.suit == '♥' || card.suit == '♦'
                          ? Colors.red[700]
                          : Colors.black,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    card.toString(),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: card.suit == '♥' || card.suit == '♦'
                          ? Colors.red[700]
                          : Colors.black,
                      fontFamily: 'monospace',
                      shadows: [
                        Shadow(
                          color: Colors.black.withAlpha((0.12 * 255).toInt()),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // Player hit logic (stub for now)
  void _playerHit(List<CardModel> hand, PlayerTurn player) {
    setState(() {
      hand.add(deck.draw());
      // Add your game logic here (e.g., check for bust, switch turn, etc.)
    });
  }

  // Player stand logic (stub for now)
  void _playerStand(PlayerTurn player) {
    setState(() {
      if (player == PlayerTurn.player1) {
        turn = PlayerTurn.computer;
        // Computer plays automatically
        while (handValue(computer) < 17) {
          computer.add(deck.draw());
        }
        turn = PlayerTurn.dealer;
        dealerReveal = true;
        // Dealer plays
        while (handValue(dealer) < 17) {
          dealer.add(deck.draw());
        }
        turn = PlayerTurn.done;
        // Evaluate results (simple, can be improved)
        int playerScore = handValue(player1);
        int computerScore = handValue(computer);
        int dealerScore = handValue(dealer);
        if (playerScore > 21) {
          result1 = 'You Bust!';
        } else if (dealerScore > 21 || playerScore > dealerScore) {
          result1 = 'You Win!';
        } else if (playerScore == dealerScore) {
          result1 = 'Push!';
        } else {
          result1 = 'Dealer Wins!';
        }
      }
    });
  }

  // Reset game logic
  void _resetGame() {
    setState(() {
      player1Chips = Map<int, int>.from(initialPlayer1Chips);
      deck = Deck();
      player1 = [];
      computer = [];
      dealer = [];
      turn = PlayerTurn.player1;
      result1 = '';
      computerResult = '';
      dealerReveal = false;
      bettingPhase = true;
      player1SelectedBet = 0;
      player1TempBetChips.clear();
      player1Bet = 0;
      player1Locked = false;
    });
  }

  // --- State variables ---
  bool bettingPhase = true;
  int player1SelectedBet = 0;
  Map<int, int> player1TempBetChips = {};
  int player1Bet = 0;
  bool player1Locked = false;
  final List<int> chipValues = [10, 20, 50, 100, 200, 500, 1000];
  final Map<int, int> initialPlayer1Chips = {
    10: 10, // $100
    20: 10, // $200
    50: 10, // $500
    100: 10, // $1000
    200: 10, // $2000
    500: 5, // $2500
    1000: 3, // $3000
  };

  Widget _fannedHandRow(
    String label,
    List<CardModel> hand, {
    bool hideFirst = false,
  }) {
    if (hand.isEmpty) return const SizedBox(height: 74);
    final angleStep = 0.18;
    final startAngle = -angleStep * (hand.length - 1) / 2;
    return SizedBox(
      height: 90,
      width: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (int i = 0; i < hand.length; i++)
            Positioned(
              left: 43 + 18 * i - (hand.length * 18) / 2,
              child: Transform.rotate(
                angle: startAngle + i * angleStep,
                child: cardWidget(hand[i], hidden: hideFirst && i == 0),
              ),
            ),
        ],
      ),
    );
  }

  Widget playerControls(
    String label,
    List<CardModel> hand,
    PlayerTurn thisTurn,
  ) {
    bool isActive = turn == thisTurn && result1.isEmpty;
    if (isActive) {
      return Row(
        children: <Widget>[
          ElevatedButton(
            onPressed: () {
              _playerHit(hand, PlayerTurn.computer);
              // Computer will play automatically after bust in _playerHit
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 6,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              textStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            child: const Text('Hit'),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () {
              _playerStand(
                PlayerTurn.player1,
              ); // Fixed: now calls for the player
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 6,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              textStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            child: const Text('Stand'),
          ),
        ],
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget yellowBox() => Container(
    width: 48,
    height: 64,
    decoration: BoxDecoration(
      border: Border.all(color: Color(0xFFFFD700), width: 3),
      borderRadius: BorderRadius.circular(8),
      color: Colors.transparent,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[900],
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Text(
              'Blackjack',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            // Betting phase
            if (bettingPhase)
              bettingWidget(
                isPlayer1: true,
                chipValues: chipValues,
                chips: player1Chips,
                selectedBet: player1SelectedBet,
                tempBetChips: player1TempBetChips,
                locked: player1Locked,
                onChipTap: (chip) {
                  setState(() {
                    if (player1Chips[chip]! > 0 &&
                        player1SelectedBet + chip <= bettingLimit) {
                      player1Chips[chip] = player1Chips[chip]! - 1;
                      player1TempBetChips[chip] =
                          (player1TempBetChips[chip] ?? 0) + 1;
                      player1SelectedBet += chip;
                    }
                  });
                },
                onLock: player1SelectedBet > 0 && !player1Locked
                    ? () {
                        setState(() {
                          player1Locked = true;
                          player1Bet = player1SelectedBet;
                          bettingPhase = false;
                          // Deal cards
                          deck = Deck();
                          deck.shuffle();
                          player1 = [deck.draw(), deck.draw()];
                          computer = [deck.draw(), deck.draw()];
                          dealer = [deck.draw(), deck.draw()];
                          turn = PlayerTurn.player1;
                          result1 = '';
                          computerResult = '';
                          dealerReveal = false;
                        });
                      }
                    : null,
                onClear: () {
                  setState(() {
                    for (var chip in player1TempBetChips.keys) {
                      player1Chips[chip] =
                          player1Chips[chip]! + player1TempBetChips[chip]!;
                    }
                    player1TempBetChips.clear();
                    player1SelectedBet = 0;
                  });
                },
              )
            else ...[
              // Table and hands
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Player hand (left)
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 16,
                          bottom: 32,
                          top: 32,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'You',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                ...player1.map((card) => cardWidget(card)),
                                const SizedBox(width: 8),
                                yellowBox(),
                              ],
                            ),
                            const SizedBox(height: 8),
                            playerControls('You', player1, PlayerTurn.player1),
                            if (result1.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  result1,
                                  style: TextStyle(
                                    color: Colors.yellow,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // Table arc and dealer (center)
                    Expanded(
                      flex: 3,
                      child: Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          CustomPaint(
                            size: Size(
                              MediaQuery.of(context).size.width * 0.5,
                              320,
                            ),
                            painter: TableArcPainter5(
                              seatPositions: [
                                Offset(
                                  MediaQuery.of(context).size.width * 0.25,
                                  320,
                                ),
                                Offset(
                                  MediaQuery.of(context).size.width * 0.5,
                                  320,
                                ),
                                Offset(
                                  MediaQuery.of(context).size.width * 0.75,
                                  320,
                                ),
                              ],
                              dealerPos: Offset(
                                MediaQuery.of(context).size.width * 0.5,
                                80,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 40,
                            left: 0,
                            right: 0,
                            child: Column(
                              children: [
                                Text(
                                  'Dealer',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ...dealer.asMap().entries.map((entry) {
                                      int i = entry.key;
                                      CardModel card = entry.value;
                                      return cardWidget(
                                        card,
                                        hidden: !dealerReveal && i == 0,
                                      );
                                    }).toList(),
                                    const SizedBox(width: 8),
                                    yellowBox(),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Computer hand (right)
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          right: 16,
                          bottom: 32,
                          top: 32,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Computer',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ...computer.map((card) => cardWidget(card)),
                                const SizedBox(width: 8),
                                yellowBox(),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Reset button
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _resetGame();
                    });
                  },
                  child: const Text('Reset Game'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

void main() {
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: BlackjackGame()),
  );
}
