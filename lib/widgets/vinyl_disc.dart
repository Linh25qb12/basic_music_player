import 'dart:math';

import 'package:flutter/material.dart';

/// Dia than vector quay kem logo L nam ngoai ria dia (van quay theo dia).
class VinylDisc extends StatelessWidget {
  const VinylDisc({
    super.key,
    required this.rotationController,
    required this.size,
  });

  final AnimationController rotationController;
  final double size;

  static const Color _grooveColor = Color(0xFF8B8AF6);
  static const Color _labelColor = Color(0xFFB8A6FF);

  @override
  Widget build(BuildContext context) {
    final sq = size * 0.068;
    final rimInset = size * 0.028;
    final canvasSize = size;
    final cx = size / 2;
    final cy = size / 2;
    final rOuter = size / 2 - rimInset - sq / 2;
    final theta = -pi / 3;
    final left = cx + rOuter * sin(theta) - sq / 2;
    final top = cy - rOuter * cos(theta) - sq / 2;

    return RotationTransition(
      turns: CurvedAnimation(parent: rotationController, curve: Curves.linear),
      child: SizedBox(
        width: canvasSize,
        height: canvasSize,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF18181B),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    for (final ratio in [0.76, 0.62, 0.48])
                      Container(
                        width: size * ratio,
                        height: size * ratio,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _grooveColor, width: 3),
                        ),
                      ),
                    Container(
                      width: size * 0.26,
                      height: size * 0.26,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _labelColor,
                      ),
                    ),
                    Container(
                      width: size * 0.06,
                      height: size * 0.06,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF2B2B2B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: sq,
              height: sq,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFE9E4FF),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: _grooveColor, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    'L',
                    style: TextStyle(
                      color: const Color(0xFF1F2937),
                      fontSize: sq * 0.62,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
