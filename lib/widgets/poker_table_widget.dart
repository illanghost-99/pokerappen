import 'package:flutter/material.dart';
import 'dart:math' as math;

class PokerTableWidget extends StatelessWidget {
  final int playerCount;
  final List<String> playerNames;
  final bool isAdmin;
  final Function(String playerId, String playerName)? onPlayerTap;

  const PokerTableWidget({
    super.key,
    required this.playerCount,
    this.playerNames = const [],
    this.isAdmin = false,
    this.onPlayerTap,
  });

  @override
  Widget build(BuildContext context) {
    final count = playerCount.clamp(0, 9);
    return SizedBox(
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 260,
            height: 160,
            decoration: BoxDecoration(
              gradient: const RadialGradient(colors: [Color(0xFF1A6B1A), Color(0xFF0D4F0D)]),
              borderRadius: BorderRadius.circular(80),
              border: Border.all(color: Colors.amber.shade700, width: 4),
              boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 30, spreadRadius: 5)],
            ),
            child: const Center(child: Text('POKER', style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 3, fontWeight: FontWeight.bold))),
          ),
          ...List.generate(count, (i) {
            final angle = (i / count) * 2 * math.pi - math.pi / 2;
            final x = 110 * math.cos(angle);
            final y = 70 * math.sin(angle);
            final name = i < playerNames.length ? playerNames[i] : 'Spelare ${i + 1}';
            final playerId = i < playerNames.length ? playerNames[i] : 'player_$i';

            return Positioned(
              left: 130 + x - 28,
              top: 140 + y - 28,
              child: GestureDetector(
                onTap: isAdmin && onPlayerTap != null ? () => onPlayerTap!(playerId, name) : null,
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.cyan.shade800,
                          child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        if (isAdmin)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.cyan, shape: BoxShape.circle),
                              child: const Icon(Icons.add, size: 14, color: Colors.black),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name.length > 8 ? '${name.substring(0, 6)}..' : name,
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                      textAlign: TextAlign.center,
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
}
