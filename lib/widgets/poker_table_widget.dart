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
      height: 460,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Realistic poker table
          Container(
            width: 340,
            height: 200,
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                colors: [Color(0xFF1E7A1E), Color(0xFF0F4A0F)],
                center: Alignment.center,
                radius: 0.85,
              ),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: const Color(0xFF3D2B1F), width: 10),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.55), blurRadius: 20, offset: const Offset(0, 6)),
                BoxShadow(color: Colors.green.withOpacity(0.2), blurRadius: 30, spreadRadius: 3),
              ],
            ),
            child: Container(
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(88),
                border: Border.all(color: const Color(0xFF5C4033), width: 2.5),
              ),
              child: const Center(
                child: Text(
                  'POKER',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    letterSpacing: 5,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 3)],
                  ),
                ),
              ),
            ),
          ),

          // Chips on the table (closer to center)
          ...List.generate(count, (i) {
            final angle = (i / count) * 2 * math.pi - math.pi / 2;
            final chipX = 110 * math.cos(angle);
            final chipY = 70 * math.sin(angle);
            final chipValue = i < playerChipValues.length ? playerChipValues[i] : 0.0;
            final cashoutResult = i < playerCashoutResults.length ? playerCashoutResults[i] : null;
            final finished = i < isFinished.length ? isFinished[i] : false;

            return Positioned(
              left: 170 + chipX - 14,
              top: 230 + chipY - 14,
              child: _buildChipIndicator(chipValue, cashoutResult, finished),
            );
          }),

          // Players outside the table
          ...List.generate(count, (i) {
            final angle = (i / count) * 2 * math.pi - math.pi / 2;
            final playerX = 185 * math.cos(angle);
            final playerY = 120 * math.sin(angle);
            final name = i < playerNames.length ? playerNames[i] : 'Spelare ${i + 1}';
            final playerId = i < playerNames.length ? playerNames[i] : 'player_$i';
            final photoUrl = i < playerPhotoUrls.length ? playerPhotoUrls[i] : null;
            final finished = i < isFinished.length ? isFinished[i] : false;

            return Positioned(
              left: 170 + playerX - 34,
              top: 230 + playerY - 34,
              child: GestureDetector(
                onTap: isAdmin && onPlayerTap != null ? () => onPlayerTap!(playerId, name) : null,
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Opacity(
                          opacity: finished ? 0.5 : 1.0,
                          child: CircleAvatar(
                            radius: 30,
                            backgroundColor: finished ? Colors.grey.shade800 : Colors.cyan.shade800,
                            backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                            child: photoUrl == null || photoUrl.isEmpty
                                ? Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))
                                : null,
                          ),
                        ),
                        if (isAdmin && !finished)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(color: Colors.cyan, shape: BoxShape.circle),
                              child: const Icon(Icons.add, size: 12, color: Colors.black),
                            ),
                          ),
                        if (finished)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle),
                              child: const Icon(Icons.check, size: 11, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    SizedBox(
                      width: 68,
                      child: Text(
                        name,
                        style: TextStyle(
                          color: finished ? Colors.white38 : Colors.white,
                          fontSize: 11,
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

  Widget _buildChipIndicator(double value, String? cashoutResult, bool finished) {
    if (cashoutResult == 'minus') {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.red.shade700,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white30, width: 1.5),
        ),
        child: const Icon(Icons.remove, color: Colors.white, size: 16),
      );
    }

    if (cashoutResult == 'even' || (finished && cashoutResult == null)) {
      return const SizedBox(width: 28, height: 28);
    }

    if (value <= 0 && cashoutResult != 'plus') {
      return const SizedBox(width: 28, height: 28);
    }

    final displayValue = (cashoutResult == 'plus') ? value.abs() : value;
    final chipCount = (displayValue / 500).ceil().clamp(1, 7);

    return SizedBox(
      width: 28,
      height: 36,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: List.generate(chipCount, (index) {
          const colors = [
            Color(0xFFFFFFFF),
            Color(0xFFD32F2F),
            Color(0xFF1976D2),
            Color(0xFF388E3C),
            Color(0xFF212121),
            Color(0xFFFFA000),
          ];
          return Positioned(
            bottom: index * 3.2,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: colors[index % colors.length],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black26, width: 0.8),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 1.5, offset: Offset(0, 0.5)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
