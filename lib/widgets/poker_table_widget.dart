import 'package:flutter/material.dart';
import 'dart:math' as math;

class PokerTableWidget extends StatelessWidget {
  final int playerCount;
  final List<String> playerNames;
  final List<String?> playerPhotoUrls;
  final List<bool> isFinished;
  final bool isAdmin;
  final Function(String playerId, String playerName)? onPlayerTap;

  const PokerTableWidget({
    super.key,
    required this.playerCount,
    this.playerNames = const [],
    this.playerPhotoUrls = const [],
    this.isFinished = const [],
    this.isAdmin = false,
    this.onPlayerTap,
  });

  @override
  Widget build(BuildContext context) {
    final count = playerCount.clamp(0, 9);
    return SizedBox(
      height: 340,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 300,
            height: 190,
            decoration: BoxDecoration(
              gradient: const RadialGradient(colors: [Color(0xFF1A6B1A), Color(0xFF0D4F0D)]),
              borderRadius: BorderRadius.circular(95),
              border: Border.all(color: Colors.amber.shade700, width: 5),
              boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 30, spreadRadius: 5)],
            ),
            child: const Center(child: Text('POKER', style: TextStyle(color: Colors.white70, fontSize: 16, letterSpacing: 4, fontWeight: FontWeight.bold))),
          ),
          ...List.generate(count, (i) {
            final angle = (i / count) * 2 * math.pi - math.pi / 2;
            final x = 125 * math.cos(angle);
            final y = 80 * math.sin(angle);
            final name = i < playerNames.length ? playerNames[i] : 'Spelare ${i + 1}';
            final playerId = i < playerNames.length ? playerNames[i] : 'player_$i';
            final photoUrl = i < playerPhotoUrls.length ? playerPhotoUrls[i] : null;
            final finished = i < isFinished.length ? isFinished[i] : false;

            return Positioned(
              left: 150 + x - 30,
              top: 170 + y - 30,
              child: GestureDetector(
                onTap: isAdmin && onPlayerTap != null ? () => onPlayerTap!(playerId, name) : null,
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Opacity(
                          opacity: finished ? 0.5 : 1.0,
                          child: CircleAvatar(
                            radius: 28,
                            backgroundColor: finished ? Colors.grey.shade700 : Colors.cyan.shade800,
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
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.cyan, shape: BoxShape.circle),
                              child: const Icon(Icons.add, size: 14, color: Colors.black),
                            ),
                          ),
                        if (finished)
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
                      width: 64,
                      child: Text(
                        name,
                        style: TextStyle(color: finished ? Colors.white38 : Colors.white70, fontSize: 11),
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
}
