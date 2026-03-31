// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xeranet_tv_application/Application/Presentation/OttPlatformsHomeScreen/ottplatformshomescreen.dart';
import 'package:xeranet_tv_application/Data/Interface/ChannelData/channeldata.dart';
import 'package:xeranet_tv_application/Application/Presentation/MenuScreen/menuscreen.dart';
import 'package:xeranet_tv_application/services/discovery_service.dart';
import 'package:xeranet_tv_application/services/panaccess_drm_service.dart';

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
  // Using PanDrmService

  final FocusNode _focusNode = FocusNode();

  late AnimationController _infoController;
  Animation<double>? _fade;
  Animation<Offset>? _slide;

  Timer? _hideTimer;
  late DiscoveryService _discoveryService;

  MethodChannel? _channel;
  late Channel _currentChannel;
  late String _currentStreamUrl;
  int _zapCounter = 0;
  int _playerKeyCounter = 0;

  @override
  void initState() {
    super.initState();
    _currentChannel = widget.channel;
    _currentStreamUrl = widget.streamUrl;
    _discoveryService = DiscoveryService();

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

  Future<String?> getDrmStreamUrl(String rawUrl) async {
    return await PanDrmService.getStreamUrl(rawUrl);
  }

  void _onPlatformViewCreated(int id) {
    _channel = MethodChannel('native_video_player_$id');
  }

  Future<void> _zapChannel(int direction) async {
    if (_discoveryService.streams.isEmpty) return;

    final currentIndex = _discoveryService.streams.indexWhere(
      (s) => s["id"]?.toString() == _currentChannel.id,
    );
    int nextIndex = currentIndex + direction;

    if (nextIndex < 0) nextIndex = _discoveryService.streams.length - 1;
    if (nextIndex >= _discoveryService.streams.length) nextIndex = 0;

    final stream = _discoveryService.streams[nextIndex];
    final channel = Channel.fromMap(stream);

    final currentZap = ++_zapCounter;
    final streamUrl = await getDrmStreamUrl(channel.streamingUrl);
    if (streamUrl != null && mounted) {
      setState(() {
        _currentChannel = channel;
        _currentStreamUrl = streamUrl;
      });
      _channel?.invokeMethod("changeStream", {"streamUrl": streamUrl});
      _showInfoBar();
    }
  }

  Future<void> _playChannel(Channel channel) async {
    final streamUrl = await getDrmStreamUrl(channel.streamingUrl);
    if (!mounted || streamUrl == null) return;
    setState(() {
      _currentChannel = channel;
      _currentStreamUrl = streamUrl;
    });
    _channel?.invokeMethod("changeStream", {"streamUrl": streamUrl});
    _showInfoBar();
  }

  @override
  void dispose() {
    _infoController.dispose();
    _hideTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        SystemNavigator.pop();
        return false;
      },
      child: RawKeyboardListener(
        focusNode: _focusNode,
        onKey: (event) async {
          if (event is RawKeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.escape ||
                event.logicalKey == LogicalKeyboardKey.goBack ||
                event.logicalKey == LogicalKeyboardKey.backspace) {
              // In full-screen, back should exit directly.
              SystemNavigator.pop();
              return;
            }

            _showInfoBar();

            if (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.contextMenu ||
                event.logicalKey == LogicalKeyboardKey.keyM) {
              final result = await Navigator.push<Channel?>(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => MainScreen(currentChannel: _currentChannel),
                ),
              );
              if (result != null && result.id != _currentChannel.id) {
                setState(() {
                  _playerKeyCounter++;
                });
                await _playChannel(result);
              } else {
                // MenuScreen's video preview steals the ExoPlayer decoder.
                // We must force the FullScreen player to reconnect when returning.
                setState(() {
                  _playerKeyCounter++;
                });
                await _playChannel(_currentChannel);
              }
            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              _zapChannel(1);
            } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              _zapChannel(-1);
            }
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Positioned.fill(
                child: AndroidView(
                  key: ValueKey(_playerKeyCounter),
                  viewType: 'native_video_player',
                  layoutDirection: TextDirection.ltr,
                  creationParams: {"streamUrl": _currentStreamUrl},
                  creationParamsCodec: const StandardMessageCodec(),
                  onPlatformViewCreated: _onPlatformViewCreated,
                ),
              ),

              // Watermark Logo
              // Positioned.fill(
              //   child: IgnorePointer(
              //     child: Center(
              //       child: Opacity(
              //         opacity: 0.2,
              //         child: Image.asset(
              //           'asset/images/Zentryx logo.png',
              //           width: 300,
              //         ),
              //       ),
              //     ),
              //   ),
              // ),

              // Top Info Bar (Logo & Time)
              Positioned(
                top: 40,
                left: 40,
                child: FadeTransition(
                  opacity: _fade!,
                  child: const SizedBox.shrink(),
                  //  Row(
                  //   children: [
                  //     Container(
                  //       height: 60,
                  //       width: 60,
                  //       decoration: BoxDecoration(
                  //         color: Colors.white10,
                  //         borderRadius: BorderRadius.circular(20),
                  //       ),
                  //       child:
                  //           _currentChannel.logoUrl.isNotEmpty
                  //               ? ClipRRect(
                  //                 borderRadius: BorderRadius.circular(20),
                  //                 child: Image.network(
                  //                   _currentChannel.logoUrl,
                  //                   fit: BoxFit.cover,
                  //                   errorBuilder:
                  //                       (_, __, ___) => const Icon(
                  //                         Icons.tv,
                  //                         color: Colors.white24,
                  //                       ),
                  //                 ),
                  //               )
                  //               : const Icon(Icons.tv, color: Colors.white24),
                  //     ),
                  //     const SizedBox(width: 20),
                  //     Text(
                  //       _currentChannel.name,
                  //       style: const TextStyle(
                  //         color: Colors.white,
                  //         fontSize: 25,
                  //         fontWeight: FontWeight.w600,
                  //       ),
                  //     ),
                  //   ],
                  // ),
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
                      final now = DateTime.now();
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

              // Bottom Info Bar
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
                          vertical: 20,
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
                              children: [
                                Text(
                                  "CH ${_currentChannel.id}",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 14,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.90),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Text(
                                    "Press OK for Menu",
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _currentChannel.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.hd, color: Colors.blueAccent),
                                const SizedBox(width: 8),
                                const Text(
                                  "1080p • Stereo • Live",
                                  style: TextStyle(color: Colors.white54),
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
      ),
    );
  }
}
