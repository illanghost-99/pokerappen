import 'package:flutter/material.dart';
import 'dart:math' as math;

class PokerTableWidget extends StatelessWidget {
  final int playerCount;
  final List<String> playerNames;
  final List<String?> playerPhotoUrls;
  final List<bool> isFinished;
  final List<double> playerChipValues;
  final List<String?> playerCashoutResults;
  final bool isAdmin;
  final Function(String playerId, String playerName)? onPlayerTap;

  const PokerTableWidget({
    super.key,
    required this.playerCount,
    this.playerNames = const [],
    this.playerPhotoUrls = const [],
    this.isFinished = const [],
    this.playerChipValues = const [],
    this.playerCashoutResults = const [],
    this.isAdmin = false,
    this.onPlayerTap,
  });

  @override
  Widget build(BuildContext context) {
    final count = playerCount.clamp(0, 9);
    return SizedBox(
      height: 420,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Realistic poker table – slightly smaller so players fit
          Container(
            width: 300,
            height: 180,
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                colors: [Color(0xFF1E7A1E), Color(0xFF0F4A0F)],
                center: Alignment.center,
                radius: 0.85,
              ),
              borderRadius: BorderRadius.circular(90),
              border: Border.all(color: const Color(0xFF3D2B1F), width: 9),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 18, offset: const Offset(0, 5)),
                BoxShadow(color: Colors.green.withOpacity(0.18), blurRadius: 26, spreadRadius: 2),
              ],
            ),
            child: Container(
              margin: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(78),
                border: Border.all(color: const Color(0xFF5C4033), width: 2),
              ),
              child: const Center(
                child: Text(
                  'POKER',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    letterSpacing: 4,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 3)],
                  ),
                ),
              ),
            ),
          ),

          // Chips on the table
          ...List.generate(count, (i) {
            final angle = (i / count) * 2 * math.pi - math.pi / 2;
            final chipX = 95 * math.cos(angle);
            final chipY = 60 * math.sin(angle);
            final chipValue = i < playerChipValues.length ? playerChipValues[i] : 0.0;
            final cashoutResult = i < playerCashoutResults.length ? playerCashoutResults[i] : null;
            final finished = i < isFinished.length ? isFinished[i] : false;

            return Positioned(
              left: 150 + chipX - 16,
              top: 210 + chipY - 16,
              child: _buildChipPile(chipValue, cashoutResult, finished),
            );
          }),

          // Players outside the table – tighter radius so they stay on screen
          ...List.generate(count, (i) {
            final angle = (i / count) * 2 * math.pi - math.pi / 2;
            final playerX = 155 * math.cos(angle);
            final playerY = 100 * math.sin(angle);
            final name = i < playerNames.length ? playerNames[i] : 'Spelare ${i + 1}';
            final playerId = i < playerNames.length ? playerNames[i] : 'player_$i';
            final photoUrl = i < playerPhotoUrls.length ? playerPhotoUrls[i] : null;
            final finished = i < isFinished.length ? isFinished[i] : false;

            return Positioned(
              left: 150 + playerX - 28,
              top: 210 + playerY - 28,
              child: GestureDetector(
                onTap: isAdmin && onPlayerTap != null ? () => onPlayerTap!(playerId, name) : null,
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Opacity(
                          opacity: finished ? 0.5 : 1.0,
                          child: CircleAvatar(
                            radius: 26,
                            backgroundColor: finished ? Colors.grey.shade800 : Colors.cyan.shade800,
                            backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                            child: photoUrl == null || photoUrl.isEmpty
                                ? Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))
                                : null,
                          ),
                        ),
                        if (isAdmin && !finished)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(color: Colors.cyan, shape: BoxShape.circle),
                              child: const Icon(Icons.add, size: 11, color: Colors.black),
                            ),
                          ),
                        if (finished)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle),
                              child: const Icon(Icons.check, size: 10, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      width: 60,
                      child: Text(
                        name,
                        style: TextStyle(
                          color: finished ? Colors.white38 : Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChipPile(double value, String? cashoutResult, bool finished) {
    if (cashoutResult == 'minus') {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.red.shade700,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white38, width: 1.5),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 3)],
        ),
        child: const Icon(Icons.remove, color: Colors.white, size: 18),
      );
    }

    if (cashoutResult == 'even' || (finished && cashoutResult == null)) {
      return const SizedBox(width: 32, height: 32);
    }

    if (value <= 0 && cashoutResult != 'plus') {
      return const SizedBox(width: 32, height: 32);
    }

    final displayValue = (cashoutResult == 'plus') ? value.abs() : value;
    final chipCount = (displayValue / 500).ceil().clamp(2, 6);

    return SizedBox(
      width: 36,
      height: 32,
      child: Stack(
        children: List.generate(chipCount, (index) {
          const colors = [
            Color(0xFFF5F5F5),
            Color(0xFFD32F2F),
            Color(0xFF1976D2),
            Color(0xFF388E3C),
            Color(0xFF212121),
            Color(0xFFFFA000),
          ];
          final offsetX = (index % 3 - 1) * 4.0;
          final offsetY = (index ~/ 3) * -3.5;
          return Positioned(
            left: 8 + offsetX,
            bottom: 2 + offsetY.abs() * 0.5,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: colors[index % colors.length],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black26, width: 0.6),
                boxShadow: const [
                  BoxShadow(color: Colors.black38, blurRadius: 2, offset: Offset(0, 1)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
