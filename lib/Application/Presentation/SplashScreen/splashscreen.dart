import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:xeranet_tv_application/Application/BusinessLogic/Login/login_bloc.dart';
import 'package:xeranet_tv_application/Application/BusinessLogic/Login/login_event.dart';
import 'package:xeranet_tv_application/Application/BusinessLogic/Login/login_state.dart';
import 'package:xeranet_tv_application/Application/Presentation/FullScreen/fullscreen.dart';
import 'package:xeranet_tv_application/Data/Interface/ChannelData/channeldata.dart';
import 'package:xeranet_tv_application/services/discovery_service.dart';
import 'package:xeranet_tv_application/services/panaccess_drm_service.dart';

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
  bool _timerFinished = false;

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

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _timerFinished = true;
        });
      }
    });

    try {
      await PanDrmService.initDrm();
      await PanDrmService.setManagementServer("https://cv01.panaccess.com");
    } catch (e) {
      debugPrint("DRM Init Failed: $e");
    }

    if (mounted) {
      context.read<LoginBloc>().add(CheckSavedCredentials());
    }
  }

  @override
  void dispose() {
    pulseController.dispose();
    floatController.dispose();
    glowController.dispose();
    super.dispose();
  }

  void _navigateToFullScreen(String streamUrl) {
    final discovery = DiscoveryService();
    final streamId = discovery.selectedStreamId?.toString();
    final stream = discovery.streams.firstWhere(
      (s) => s["id"]?.toString() == streamId,
      orElse: () => discovery.streams.isNotEmpty ? discovery.streams[0] : null,
    );
    
    if (stream != null) {
      final channel = Channel.fromMap(stream);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FullScreenPlayerWidget(
            channel: channel,
            streamUrl: streamUrl,
          ),
        ),
      );
    } else {
      // In case streams aren't loaded properly
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _pollTimer(LoginState state) async {
    while (!_timerFinished) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (mounted) {
      if (state is LoginSuccess) {
         _navigateToFullScreen(state.streamUrl);
      } else {
         Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LoginBloc, LoginState>(
      listener: (context, state) {
        if (state is LoginSuccess && _timerFinished) {
           _navigateToFullScreen(state.streamUrl);
        } else if ((state is LoginInitial || state is LoginFailure) && _timerFinished) {
           Navigator.pushReplacementNamed(context, '/login');
        }
        
        if (!_timerFinished && (state is LoginSuccess || state is LoginInitial || state is LoginFailure)) {
          _pollTimer(state);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
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
            _glowBlob(Colors.blueAccent, size: 300, top: 0.15, left: 0.10),
            _glowBlob(Colors.purpleAccent, size: 260, bottom: 0.20, right: 0.12),
            _glowBlob(Colors.cyanAccent, size: 320, top: 0.45, right: 0.25),
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
      ),
    );
  }

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
      bottom: bottom != null ? MediaQuery.of(context).size.height * bottom : null,
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
