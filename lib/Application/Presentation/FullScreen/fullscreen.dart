// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xeranet_tv_application/Application/Presentation/OttPlatformsHomeScreen/ottplatformshomescreen.dart';
import 'package:xeranet_tv_application/Data/Interface/ChannelData/channeldata.dart';
import 'package:xeranet_tv_application/Application/Presentation/MenuScreen/menuscreen.dart';

class FullScreenPlayerWidget extends StatefulWidget {
  final Channel channel;
  final String streamUrl;
  const FullScreenPlayerWidget({
    super.key,
    required this.channel,
    required this.streamUrl,
  });

  @override
  State<FullScreenPlayerWidget> createState() => _FullScreenPlayerWidgetState();
}

class _FullScreenPlayerWidgetState extends State<FullScreenPlayerWidget>
    with TickerProviderStateMixin {
  // late YoutubePlayerController _ytController;
  final FocusNode _focusNode = FocusNode();

  late AnimationController _infoController;
  Animation<double>? _fade;
  Animation<Offset>? _slide;

  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();

    const sampleUrl = "https://youtu.be/3TYABnOSgCE?si=KyPM_kX_MtL_1fCl";
    // final videoId = YoutubePlayer.convertUrlToId(sampleUrl)!;

    // _ytController = YoutubePlayerController(
    //   initialVideoId: videoId,
    //   flags: const YoutubePlayerFlags(
    //     autoPlay: true,
    //     mute: false,
    //     loop: true,
    //     disableDragSeek: true,
    //     hideControls: true,
    //     controlsVisibleAtStart: false,
    //     enableCaption: false,
    //   ),
    // );

    _infoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fade = CurvedAnimation(parent: _infoController, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(_fade!);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _showInfoBar();
    });
  }

  void _showInfoBar() {
    if (!mounted) return;
    _infoController.forward();
    _restartAutoHideTimer();
  }

  void _restartAutoHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        _infoController.reverse();
      }
    });
  }

  @override
  void dispose() {
   // _ytController.dispose();
    _infoController.dispose();
    _hideTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: (event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.pop(context);
            return;
          }

          _showInfoBar();

          if (event.logicalKey == LogicalKeyboardKey.contextMenu ||
              event.logicalKey == LogicalKeyboardKey.keyM) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MainScreen()),
            );
          } else if (event.logicalKey == LogicalKeyboardKey.home ||
              event.logicalKey == LogicalKeyboardKey.keyH) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const Ottplatformshomescreen(),
              ),
            );
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child:
              //  YoutubePlayer(
              //   controller: _ytController,
              //   aspectRatio: 16 / 9,
              // ),
              Text(
                "Video Player Placeholder",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 18,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

            Positioned(
              top: 40,
              left: 40,
              child: FadeTransition(
                opacity: _fade!,
                child: Row(
                  children: [
                    Container(
                      height: 60,
                      width: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        image: DecorationImage(
                          image: NetworkImage(
                            "https://image.slidesharecdn.com/starmoviessecretscreening-141021132127-conversion-gate02/75/Star-movies-secret-screening-1-2048.jpg",
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Text(
                      "Star Movies",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              top: 40,
              right: 40,
              child: FadeTransition(
                opacity: _fade!,
                child: StreamBuilder(
                  stream: Stream.periodic(const Duration(seconds: 1)),
                  builder: (_, __) {
                    final now = TimeOfDay.now();
                    return Text(
                      "${now.hour}:${now.minute.toString().padLeft(2, '0')}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ),
            ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: SlideTransition(
                position: _slide!,
                child: FadeTransition(
                  opacity: _fade!,
                  child: Center(
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.90,

                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 10,
                      ),

                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                          width: 1.0,
                        ),
                      ),

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,

                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                height: 30,
                                width: 30,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color: Colors.white.withOpacity(0.9),
                                  image: const DecorationImage(
                                    image: NetworkImage(
                                      "https://image.slidesharecdn.com/starmoviessecretscreening-141021132127-conversion-gate02/75/Star-movies-secret-screening-1-2048.jpg",
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),

                              const SizedBox(width: 10),

                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Channel 121",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.85),
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    "Star Movies HD",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),

                              const Spacer(),

                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.90),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      height: 6,
                                      width: 6,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      "LIVE",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          Text(
                            "Spider Man",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),

                          const SizedBox(height: 2),

                          Text(
                            "11:00 AM - 12:30 PM",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.70),
                              fontSize: 12,
                            ),
                          ),

                          const SizedBox(height: 10),

                          Stack(
                            children: [
                              Container(
                                height: 4,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),

                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: 0.42,
                                child: Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    gradient: const LinearGradient(
                                      colors: [Colors.redAccent, Colors.red],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Up Next - 12:30 PM",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.55),
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  const Text(
                                    "Malayali Manga",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Icon(
                                Icons.keyboard_arrow_right_rounded,
                                color: Colors.white.withOpacity(0.70),
                                size: 26,
                              ),
                            ],
                          ),
                        ],
                      ),
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
