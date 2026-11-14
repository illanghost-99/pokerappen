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
      height: 400,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Poker table
          Container(
            width: 280,
            height: 170,
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                colors: [Color(0xFF1E7A1E), Color(0xFF0F4A0F)],
                center: Alignment.center,
                radius: 0.85,
              ),
              borderRadius: BorderRadius.circular(85),
              border: Border.all(color: const Color(0xFF3D2B1F), width: 8),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 16, offset: const Offset(0, 4)),
                BoxShadow(color: Colors.green.withOpacity(0.15), blurRadius: 22, spreadRadius: 1),
              ],
            ),
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(74),
                border: Border.all(color: const Color(0xFF5C4033), width: 1.8),
              ),
              child: const Center(
                child: Text(
                  'POKER',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    letterSpacing: 3,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
                  ),
                ),
              ),
            ),
          ),

          // Amounts on the table
          ...List.generate(count, (i) {
            final angle = (i / count) * 2 * math.pi - math.pi / 2;
            final amountX = 88 * math.cos(angle);
            final amountY = 55 * math.sin(angle);
            final value = i < playerChipValues.length ? playerChipValues[i] : 0.0;
            final cashoutResult = i < playerCashoutResults.length ? playerCashoutResults[i] : null;
            final finished = i < isFinished.length ? isFinished[i] : false;

            return Positioned(
              left: 140 + amountX - 28,
              top: 200 + amountY - 12,
              child: _buildAmount(value, cashoutResult, finished),
            );
          }),

          // Players
          ...List.generate(count, (i) {
            final angle = (i / count) * 2 * math.pi - math.pi / 2;
            final playerX = 145 * math.cos(angle);
            final playerY = 92 * math.sin(angle);
            final name = i < playerNames.length ? playerNames[i] : 'Spelare ${i + 1}';
            final playerId = i < playerNames.length ? playerNames[i] : 'player_$i';
            final photoUrl = i < playerPhotoUrls.length ? playerPhotoUrls[i] : null;
            final finished = i < isFinished.length ? isFinished[i] : false;

            return Positioned(
              left: 140 + playerX - 26,
              top: 200 + playerY - 26,
              child: GestureDetector(
                onTap: isAdmin && onPlayerTap != null ? () => onPlayerTap!(playerId, name) : null,
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Opacity(
                          opacity: finished ? 0.5 : 1.0,
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor: finished ? Colors.grey.shade800 : Colors.cyan.shade800,
                            backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                            child: photoUrl == null || photoUrl.isEmpty
                                ? Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))
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
                              child: const Icon(Icons.add, size: 10, color: Colors.black),
                            ),
                          ),
                        if (finished)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle),
                              child: const Icon(Icons.check, size: 9, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    SizedBox(
                      width: 56,
                      child: Text(
                        name,
                        style: TextStyle(
                          color: finished ? Colors.white38 : Colors.white,
                          fontSize: 9.5,
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

  Widget _buildAmount(double value, String? cashoutResult, bool finished) {
    String text;
    Color color;

    if (cashoutResult == 'even') {
      text = '0 kr';
      color = Colors.white70;
    } else if (cashoutResult == 'plus') {
      text = '+${value.abs().toStringAsFixed(0)} kr';
      color = Colors.greenAccent;
    } else if (cashoutResult == 'minus') {
      text = '-${value.abs().toStringAsFixed(0)} kr';
      color = Colors.redAccent;
    } else if (value > 0) {
      text = '${value.toStringAsFixed(0)} kr';
      color = Colors.white;
    } else {
      return const SizedBox(width: 56, height: 20);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.6), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: color.withOpacity(0.5), blurRadius: 4)],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
