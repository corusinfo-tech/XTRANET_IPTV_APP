import 'dart:ui';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController pulseController;
  late AnimationController floatController;
  late AnimationController glowController;

  @override
  void initState() {
    super.initState();

    pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Auto-navigate
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    });
  }

  @override
  void dispose() {
    pulseController.dispose();
    floatController.dispose();
    glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          /// BACKGROUND GRADIENT
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF05070F),
                  Color(0xFF0B1222),
                  Color(0xFF111827),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          /// BLOBS
          _glowBlob(Colors.blueAccent, size: 300, top: 0.15, left: 0.10),
          _glowBlob(Colors.purpleAccent, size: 260, bottom: 0.20, right: 0.12),
          _glowBlob(Colors.cyanAccent, size: 320, top: 0.45, right: 0.25),

          /// CENTER CONTENT
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                animatedAppName("XTRANET"),
                const SizedBox(height: 25),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// GLOW BLOB WIDGET
  Widget _glowBlob(
    Color color, {
    required double size,
    double? top,
    double? left,
    double? right,
    double? bottom,
  }) {
    return Positioned(
      top: top != null ? MediaQuery.of(context).size.height * top : null,
      bottom:
          bottom != null ? MediaQuery.of(context).size.height * bottom : null,
      left: left != null ? MediaQuery.of(context).size.width * left : null,
      right: right != null ? MediaQuery.of(context).size.width * right : null,
      child: AnimatedBuilder(
        animation: pulseController,
        builder: (_, __) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color.withOpacity(0.25 + pulseController.value * 0.15),
              shape: BoxShape.circle,
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
              child: Container(color: Colors.transparent),
            ),
          );
        },
      ),
    );
  }

  /// LETTER-BY-LETTER NAME ANIMATION
  Widget animatedAppName(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(text.length, (index) {
        return _AnimatedLetter(
          letter: text[index],
          delay: Duration(milliseconds: index * 300),
        );
      }),
    );
  }
}

class _AnimatedLetter extends StatefulWidget {
  final String letter;
  final Duration delay;

  const _AnimatedLetter({required this.letter, required this.delay});

  @override
  State<_AnimatedLetter> createState() => _AnimatedLetterState();
}

class _AnimatedLetterState extends State<_AnimatedLetter> {
  double opacity = 0;
  double scale = 0.4;

  @override
  void initState() {
    super.initState();

    Future.delayed(widget.delay, () {
      if (mounted) {
        setState(() {
          opacity = 1;
          scale = 1;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 600),
      opacity: opacity,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 600),
        scale: scale,
        curve: Curves.easeOutBack,
        child: Text(
          widget.letter,
          style: const TextStyle(
            fontSize: 60,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [Shadow(color: Colors.blueAccent, blurRadius: 20)],
          ),
        ),
      ),
    );
  }
}
