import 'package:flutter/material.dart';
import 'dart:math' as math;

class PokerTableWidget extends StatelessWidget {
  final int playerCount;
  final List<String> playerIds;
  final List<String> playerNames;
  final List<String?> playerPhotoUrls;
  final List<bool> isFinished;
  final List<double> playerChipValues;
  final List<String?> playerCashoutResults;
  final bool isAdmin;
  final bool isEnded;
  final Function(String playerId, String playerName)? onPlayerTap;
  final Function(String playerId, String playerName)? onContinue;
  final Function(String? photoUrl, String name)? onViewPhoto;

  const PokerTableWidget({
    super.key,
    required this.playerCount,
    this.playerIds = const [],
    this.playerNames = const [],
    this.playerPhotoUrls = const [],
    this.isFinished = const [],
    this.playerChipValues = const [],
    this.playerCashoutResults = const [],
    this.isAdmin = false,
    this.isEnded = false,
    this.onPlayerTap,
    this.onContinue,
    this.onViewPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final count = playerCount.clamp(0, 10);
    if (count == 0) {
      return const SizedBox(height: 300, child: Center(child: Text('Inga spelare', style: TextStyle(color: Colors.white54))));
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final centerX = screenWidth / 2 - 12;
    const centerY = 250.0;

    const double tableHalfW = 140.0;
    const double tableHalfH = 82.0;

    final double avatarRadius = count <= 6 ? 26.0 : (count <= 8 ? 22.0 : 18.0);

    final double radiusX = tableHalfW + avatarRadius + 10;
    final double radiusY = tableHalfH + avatarRadius + 14;

    final double amountRadiusX = tableHalfW - 22;
    final double amountRadiusY = tableHalfH - 16;

    return SizedBox(
      height: 540,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: tableHalfW * 2,
            height: tableHalfH * 2,
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                colors: [Color(0xFF1E7A1E), Color(0xFF0F4A0F)],
                center: Alignment.center,
                radius: 0.85,
              ),
              borderRadius: BorderRadius.circular(82),
              border: Border.all(color: const Color(0xFF3D2B1F), width: 8),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 18, offset: const Offset(0, 5)),
                BoxShadow(color: Colors.green.withOpacity(0.15), blurRadius: 24, spreadRadius: 2),
              ],
            ),
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(72),
                border: Border.all(color: const Color(0xFF5C4033), width: 2),
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

          ...List.generate(count, (i) {
            final angle = (i / count) * 2 * math.pi - math.pi / 2;
            final cosA = math.cos(angle);
            final sinA = math.sin(angle);

            final bottomNudge = sinA > 0.4 ? 8.0 : 0.0;

            final playerX = radiusX * cosA;
            final playerY = radiusY * sinA + bottomNudge;

            final amountX = amountRadiusX * cosA;
            final amountY = amountRadiusY * sinA;

            final name = i < playerNames.length ? playerNames[i] : 'Spelare ${i + 1}';
            final playerId = i < playerIds.length ? playerIds[i] : (i < playerNames.length ? playerNames[i] : 'player_$i');
            final photoUrl = i < playerPhotoUrls.length ? playerPhotoUrls[i] : null;
            final finished = i < isFinished.length ? isFinished[i] : false;
            final value = i < playerChipValues.length ? playerChipValues[i] : 0.0;
            final cashoutResult = i < playerCashoutResults.length ? playerCashoutResults[i] : null;

            return Stack(
              children: [
                Positioned(
                  left: centerX + amountX - 28,
                  top: centerY + amountY - 10,
                  child: _buildAmount(value, cashoutResult, finished),
                ),
                Positioned(
                  left: centerX + playerX - avatarRadius,
                  top: centerY + playerY - avatarRadius - 6,
                  child: GestureDetector(
                    onTap: () {
                      if (isEnded) {
                        if (photoUrl != null && photoUrl.isNotEmpty && onViewPhoto != null) {
                          onViewPhoto!(photoUrl, name);
                        }
                        return;
                      }
                      if (isAdmin && finished && onContinue != null) {
                        onContinue!(playerId, name);
                      } else if (isAdmin && !finished && onPlayerTap != null) {
                        onPlayerTap!(playerId, name);
                      } else if (photoUrl != null && photoUrl.isNotEmpty && onViewPhoto != null) {
                        onViewPhoto!(photoUrl, name);
                      }
                    },
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Opacity(
                              opacity: finished ? 0.5 : 1.0,
                              child: CircleAvatar(
                                radius: avatarRadius,
                                backgroundColor: finished ? Colors.grey.shade800 : Colors.cyan.shade800,
                                backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                                child: photoUrl == null || photoUrl.isEmpty
                                    ? Text('${i + 1}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: avatarRadius * 0.55))
                                    : null,
                              ),
                            ),
                            if (isAdmin && !finished && !isEnded)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(color: Colors.cyan, shape: BoxShape.circle),
                                  child: Icon(Icons.add, size: avatarRadius * 0.4, color: Colors.black),
                                ),
                              ),
                            if (finished)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle),
                                  child: Icon(Icons.check, size: avatarRadius * 0.38, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        SizedBox(
                          width: avatarRadius * 2.2,
                          child: Text(
                            name,
                            style: TextStyle(
                              color: finished ? Colors.white38 : Colors.white,
                              fontSize: avatarRadius * 0.38,
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
                ),
              ],
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
      return const SizedBox(width: 56, height: 20);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withOpacity(0.7), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: color.withOpacity(0.55), blurRadius: 3)],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
