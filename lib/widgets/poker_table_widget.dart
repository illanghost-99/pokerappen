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
      height: 440,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Poker table
          Container(
            width: 260,
            height: 160,
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                colors: [Color(0xFF1E7A1E), Color(0xFF0F4A0F)],
                center: Alignment.center,
                radius: 0.85,
              ),
              borderRadius: BorderRadius.circular(80),
              border: Border.all(color: const Color(0xFF3D2B1F), width: 7),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 14, offset: const Offset(0, 3)),
                BoxShadow(color: Colors.green.withOpacity(0.12), blurRadius: 18, spreadRadius: 1),
              ],
            ),
            child: Container(
              margin: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(70),
                border: Border.all(color: const Color(0xFF5C4033), width: 1.5),
              ),
              child: const Center(
                child: Text(
                  'POKER',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    letterSpacing: 2.5,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
                  ),
                ),
              ),
            ),
          ),

          // Amounts
          ...List.generate(count, (i) {
            final angle = (i / count) * 2 * math.pi - math.pi / 2;
            final amountX = 82 * math.cos(angle);
            final amountY = 52 * math.sin(angle);
            final value = i < playerChipValues.length ? playerChipValues[i] : 0.0;
            final cashoutResult = i < playerCashoutResults.length ? playerCashoutResults[i] : null;
            final finished = i < isFinished.length ? isFinished[i] : false;

            return Positioned(
              left: MediaQuery.of(context).size.width / 2 + amountX - 30,
              top: 220 + amountY - 10,
              child: _buildAmount(value, cashoutResult, finished),
            );
          }),

          // Players
          ...List.generate(count, (i) {
            final angle = (i / count) * 2 * math.pi - math.pi / 2;
            final playerX = 135 * math.cos(angle);
            final playerY = 85 * math.sin(angle);
            final name = i < playerNames.length ? playerNames[i] : 'Spelare ${i + 1}';
            final playerId = i < playerNames.length ? playerNames[i] : 'player_$i';
            final photoUrl = i < playerPhotoUrls.length ? playerPhotoUrls[i] : null;
            final finished = i < isFinished.length ? isFinished[i] : false;

            return Positioned(
              left: MediaQuery.of(context).size.width / 2 + playerX - 24,
              top: 220 + playerY - 24,
              child: GestureDetector(
                onTap: isAdmin && onPlayerTap != null ? () => onPlayerTap!(playerId, name) : null,
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Opacity(
                          opacity: finished ? 0.5 : 1.0,
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: finished ? Colors.grey.shade800 : Colors.cyan.shade800,
                            backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                            child: photoUrl == null || photoUrl.isEmpty
                                ? Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))
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
                              child: const Icon(Icons.add, size: 9, color: Colors.black),
                            ),
                          ),
                        if (finished)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle),
                              child: const Icon(Icons.check, size: 8, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    SizedBox(
                      width: 52,
                      child: Text(
                        name,
                        style: TextStyle(
                          color: finished ? Colors.white38 : Colors.white,
                          fontSize: 9,
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
      color = Colors.white;
    } else if (cashoutResult == 'plus') {
      text = '+${value.abs().toStringAsFixed(0)} kr';
      color = const Color(0xFF00E676);
    } else if (cashoutResult == 'minus') {
      text = '-${value.abs().toStringAsFixed(0)} kr';
      color = const Color(0xFFFF1744);
    } else if (value > 0) {
      text = '${value.toStringAsFixed(0)} kr';
      color = Colors.white;
    } else {
      return const SizedBox(width: 52, height: 18);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.7), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: color.withOpacity(0.6), blurRadius: 3)],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
