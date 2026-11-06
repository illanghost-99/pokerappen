import 'package:flutter/material.dart';
import 'dart:math' as math;

class PokerTableWidget extends StatelessWidget {
  final int playerCount;
  final List<String> playerNames;
  const PokerTableWidget({super.key, required this.playerCount, this.playerNames = const []});

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
            return Positioned(
              left: 130 + x - 24,
              top: 140 + y - 24,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.cyan.shade800,
                    child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  if (i < playerNames.length)
                    Text(
                      playerNames[i].length > 8 ? '${playerNames[i].substring(0, 6)}..' : playerNames[i],
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
