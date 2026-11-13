import 'package:flutter/material.dart';
import 'dart:math' as math;

class PokerTableWidget extends StatelessWidget {
  final int playerCount;
  final List<String> playerNames;
  final List<String?> playerPhotoUrls;
  final List<bool> isFinished;
  final List<double> playerChipValues; // total invested or remaining chips
  final List<String?> playerCashoutResults; // 'plus', 'minus', 'even' or null
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
          // Realistic poker table
          Container(
            width: 360,
            height: 220,
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                colors: [Color(0xFF1E7A1E), Color(0xFF0F4A0F)],
                center: Alignment.center,
                radius: 0.85,
              ),
              borderRadius: BorderRadius.circular(110),
              border: Border.all(color: const Color(0xFF3D2B1F), width: 12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 25, offset: const Offset(0, 8)),
                BoxShadow(color: Colors.green.withOpacity(0.25), blurRadius: 40, spreadRadius: 4),
              ],
            ),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(95),
                border: Border.all(color: const Color(0xFF5C4033), width: 3),
              ),
              child: const Center(
                child: Text(
                  'POKER',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    letterSpacing: 6,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                  ),
                ),
              ),
            ),
          ),

          // Players + chips
          ...List.generate(count, (i) {
            final angle = (i / count) * 2 * math.pi - math.pi / 2;
            final x = 150 * math.cos(angle);
            final y = 95 * math.sin(angle);
            final name = i < playerNames.length ? playerNames[i] : 'Spelare ${i + 1}';
            final playerId = i < playerNames.length ? playerNames[i] : 'player_$i';
            final photoUrl = i < playerPhotoUrls.length ? playerPhotoUrls[i] : null;
            final finished = i < isFinished.length ? isFinished[i] : false;
            final chipValue = i < playerChipValues.length ? playerChipValues[i] : 0.0;
            final cashoutResult = i < playerCashoutResults.length ? playerCashoutResults[i] : null;

            return Positioned(
              left: 180 + x - 36,
              top: 210 + y - 36,
              child: GestureDetector(
                onTap: isAdmin && onPlayerTap != null ? () => onPlayerTap!(playerId, name) : null,
                child: Column(
                  children: [
                    // Chip stack in front of player
                    if (!finished || cashoutResult == 'plus')
                      _buildChipStack(chipValue, cashoutResult)
                    else if (cashoutResult == 'minus')
                      _buildMinusBadge()
                    else
                      const SizedBox(height: 28),

                    const SizedBox(height: 4),

                    // Avatar
                    Stack(
                      children: [
                        Opacity(
                          opacity: finished ? 0.55 : 1.0,
                          child: CircleAvatar(
                            radius: 32,
                            backgroundColor: finished ? Colors.grey.shade800 : Colors.cyan.shade800,
                            backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                            child: photoUrl == null || photoUrl.isEmpty
                                ? Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))
                                : null,
                          ),
                        ),
                        if (isAdmin && !finished)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.cyan, shape: BoxShape.circle),
                              child: const Icon(Icons.add, size: 14, color: Colors.black),
                            ),
                          ),
                        if (finished && cashoutResult != 'minus')
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle),
                              child: const Icon(Icons.check, size: 12, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 72,
                      child: Text(
                        name,
                        style: TextStyle(
                          color: finished ? Colors.white38 : Colors.white,
                          fontSize: 12,
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

  Widget _buildChipStack(double value, String? cashoutResult) {
    if (value <= 0 && cashoutResult != 'plus') return const SizedBox(height: 28);

    final displayValue = cashoutResult == 'plus' ? value.abs() : value;
    final chipCount = (displayValue / 500).ceil().clamp(1, 8);

    return SizedBox(
      height: 32,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: List.generate(chipCount, (index) {
          final colors = [
            const Color(0xFFFFFFFF), // white
            const Color(0xFFD32F2F), // red
            const Color(0xFF1976D2), // blue
            const Color(0xFF388E3C), // green
            const Color(0xFF212121), // black
            const Color(0xFFFFA000), // amber
          ];
          return Positioned(
            bottom: index * 3.5,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: colors[index % colors.length],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black26, width: 1),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 2, offset: const Offset(0, 1)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMinusBadge() {
    return Container(
      height: 28,
      width: 28,
      decoration: BoxDecoration(
        color: Colors.red.shade700,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      child: const Icon(Icons.remove, color: Colors.white, size: 16),
    );
  }
}
