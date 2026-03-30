import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xeranet_tv_application/services/discovery_service.dart';
import 'package:xeranet_tv_application/services/panaccess_drm_service.dart';

class PlayerScreen extends StatefulWidget {
  final String streamUrl;
  final int? startIndex;

  const PlayerScreen({super.key, required this.streamUrl, this.startIndex});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final FocusNode _videoFocusNode = FocusNode();
  final FocusNode _streamsFocusNode = FocusNode();

  MethodChannel? _channel;
  final DiscoveryService _discoveryService = DiscoveryService();

  /// The logical index of the currently PLAYING stream.
  int _playingStreamIndex = 0;

  /// The logical index of the currently HIGHLIGHTED stream in the channel list.
  /// Differs from _playingStreamIndex while the user is browsing.
  int _highlightedStreamIndex = 0;

  dynamic _currentPlayingStream;

  bool _isOverlayVisible = false;
  Timer? _hideTimer;
  late ScrollController _scrollController;
  static const int _infiniteLoopCount = 10000;

  // Tracks the virtual index of the HIGHLIGHTED item in the infinite list.
  int _highlightedVirtualIndex = 0;

  // Concurrency lock for rapid zapping (fullscreen mode)
  int _zapCounter = 0;

  // Error message from native player (null = no error)
  String? _playerError;

  // The actual stream object currently highlighted in the channel list.
  // Used as source of truth for _confirmAndPlay — avoids any index mismatch.
  dynamic _highlightedStream;

  @override
  void initState() {
    super.initState();
    _playingStreamIndex = widget.startIndex ?? 0;
    _currentPlayingStream =
        _discoveryService.streams.isNotEmpty
            ? _discoveryService.streams[_playingStreamIndex]
            : null;
    _highlightedStreamIndex = _playingStreamIndex;
    _highlightedStream = _currentPlayingStream; // start highlighted = playing

    final int streamsCount = _discoveryService.streams.length;
    // Align initialIndex to be a multiple of streamsCount near the middle.
    _highlightedVirtualIndex =
        streamsCount > 0
            ? ((_infiniteLoopCount ~/ 2) ~/ streamsCount) * streamsCount
            : 0;

    _scrollController = ScrollController(
      initialScrollOffset: 20.0 + (_highlightedVirtualIndex * 172.0),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _videoFocusNode.requestFocus();
    });
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) {
        setState(() {
          _isOverlayVisible = false;
        });
        _videoFocusNode.requestFocus();
      }
    });
  }

  void _showOverlay() {
    if (!_isOverlayVisible) {
      setState(() {
        _isOverlayVisible = true;
      });
    }
    _startHideTimer();
    // Sync the highlighted index to the currently playing stream when opening
    _syncHighlightToPlaying();
  }

  void _hideOverlay() {
    _hideTimer?.cancel();
    if (_isOverlayVisible) {
      setState(() {
        _isOverlayVisible = false;
      });
    }
    _videoFocusNode.requestFocus();
  }

  /// When the channel list opens, snap highlight to the currently playing stream.
  void _syncHighlightToPlaying() {
    if (_discoveryService.streams.isEmpty) return;
    final int streamsCount = _discoveryService.streams.length;

    // Recalculate virtual index so it maps to _playingStreamIndex within the
    // current "region" of the infinite list (avoids scroll jumps).
    final int base = (_highlightedVirtualIndex ~/ streamsCount) * streamsCount;
    _highlightedVirtualIndex = base + _playingStreamIndex;
    _highlightedStreamIndex = _playingStreamIndex;
    _highlightedStream = _discoveryService.streams[_playingStreamIndex];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          20.0 + (_highlightedVirtualIndex * 172.0),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _videoFocusNode.dispose();
    _streamsFocusNode.dispose();
    _scrollController.dispose();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onPlatformViewCreated(int id) {
    _channel = MethodChannel('native_video_player_$id');
    // Listen for errors coming up from the native player
    _channel!.setMethodCallHandler((call) async {
      if (call.method == 'onPlayerError') {
        final msg =
            call.arguments['message'] as String? ?? 'Stream unavailable';
        if (mounted) {
          setState(() => _playerError = msg);
        }
      }
    });
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return;

    // ─── Up arrow: always SHOW channel list ───────────────────────────────
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _showOverlay();
      return;
    }

    // ─── Down arrow: always HIDE channel list ─────────────────────────────
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _hideOverlay();
      return;
    }

    // ─── Channel list is VISIBLE ─────────────────────────────────────────
    if (_isOverlayVisible) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _browseChannel(-1); // scroll/highlight only
        return;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _browseChannel(1); // scroll/highlight only
        return;
      } else if (event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter) {
        // Confirm and PLAY the highlighted channel
        _confirmAndPlay();
        return;
      }
      return; // swallow other keys while overlay is visible
    }

    // ─── Back behavior in fullscreen: close app
    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.goBack ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      SystemNavigator.pop();
      return;
    }

    // ─── Channel list is HIDDEN (fullscreen mode) ─────────────────────────
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _zapAndPlay(1); // move forward
      return;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _zapAndPlay(-1); // move backward
      return;
    } else if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      // Navigate back to MainScreen
      Navigator.pop(context);
      return;
    }
  }

  /// Browse (highlight only) through the channel list WITHOUT playing.
  void _browseChannel(int direction) {
    if (_discoveryService.streams.isEmpty) return;
    final int streamsCount = _discoveryService.streams.length;

    _highlightedVirtualIndex += direction;

    // Wrap within infinite list: if we go below 1 full loop from start, jump
    // forward one full cycle; if above the limit, jump back one full cycle.
    // This keeps the virtual index always valid WITHOUT a jarring scroll jump.
    if (_highlightedVirtualIndex < streamsCount) {
      _highlightedVirtualIndex +=
          streamsCount * ((_infiniteLoopCount ~/ 2) ~/ streamsCount);
    }
    if (_highlightedVirtualIndex >= _infiniteLoopCount - streamsCount) {
      _highlightedVirtualIndex -=
          streamsCount * ((_infiniteLoopCount ~/ 2) ~/ streamsCount);
    }

    final int nextIndex = _highlightedVirtualIndex % streamsCount;

    setState(() {
      _highlightedStreamIndex = nextIndex;
      _highlightedStream = _discoveryService.streams[nextIndex];
    });

    // Restart auto-hide timer
    _startHideTimer();

    // Scroll to show the highlighted channel
    _scrollController.animateTo(
      20.0 + (_highlightedVirtualIndex * 172.0),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  /// Confirm: play the currently highlighted channel and close the list.
  void _confirmAndPlay() {
    if (_discoveryService.streams.isEmpty) return;
    // Use the stored _highlightedStream object directly — avoids ANY index mismatch.
    final stream =
        _highlightedStream ??
        _discoveryService.streams[_highlightedStreamIndex];
    final int index = _discoveryService.streams.indexOf(stream);
    debugPrint(
      "[PlayerScreen] confirmAndPlay: index=$index name=${stream['name']} id=${stream['id']}",
    );
    _playStream(index < 0 ? _highlightedStreamIndex : index, stream);
    _hideOverlay();
  }

  /// Instant zap + play (only when in fullscreen, no channel list).
  void _zapAndPlay(int direction) {
    if (_discoveryService.streams.isEmpty) return;
    final int streamsCount = _discoveryService.streams.length;

    // Advance the virtual index continuously
    _highlightedVirtualIndex += direction;

    // Wrap within infinite list bounds smoothly
    if (_highlightedVirtualIndex < streamsCount) {
      _highlightedVirtualIndex +=
          streamsCount * ((_infiniteLoopCount ~/ 2) ~/ streamsCount);
    }
    if (_highlightedVirtualIndex >= _infiniteLoopCount - streamsCount) {
      _highlightedVirtualIndex -=
          streamsCount * ((_infiniteLoopCount ~/ 2) ~/ streamsCount);
    }

    final int nextIndex = _highlightedVirtualIndex % streamsCount;
    _highlightedStream = _discoveryService.streams[nextIndex];
    _playStream(nextIndex, _discoveryService.streams[nextIndex]);
  }

  /// Core method to update playing state and send URL to native player.
  Future<void> _playStream(int index, dynamic stream) async {
    final int currentZap = ++_zapCounter;

    // Guard against invalid index
    final int safeIndex = index.clamp(0, _discoveryService.streams.length - 1);

    setState(() {
      _playingStreamIndex = safeIndex;
      _highlightedStreamIndex = safeIndex;
      _currentPlayingStream = stream;
      _highlightedStream = stream;
      _playerError = null;
    });

    debugPrint(
      "[PlayerScreen] playStream: index=$safeIndex name=${stream['name']} id=${stream['id']}",
    );

    final rawUrl = stream["url"] ?? stream["id"]?.toString();
    if (rawUrl != null) {
      try {
        final url = await PanDrmService.getStreamUrl(rawUrl);
        debugPrint("[PlayerScreen] getStreamUrl returned: $url");
        if (currentZap == _zapCounter && url != null) {
          _channel?.invokeMethod("changeStream", {"streamUrl": url});
        } else if (currentZap != _zapCounter) {
          debugPrint(
            "[PlayerScreen] Zap superseded (zap#$currentZap < current#$_zapCounter), skipping.",
          );
        }
      } catch (e) {
        debugPrint("[PlayerScreen] Failed to get Stream URL: $e");
      }
    }
  }

  /// Shows a centered dialog with channel name, logo, and a close button.
  void _showChannelInfoDialog() {
    if (_currentPlayingStream == null) return;
    final String name = _currentPlayingStream["name"] ?? "Unknown Channel";
    final String? logoUrl = _getLogoUrl(_currentPlayingStream);
    final String channelId = _currentPlayingStream["id"]?.toString() ?? "";

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 340,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF1a1a2e), const Color(0xFF0f3460)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo area
                Container(
                  width: 120,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child:
                      logoUrl != null
                          ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              logoUrl,
                              fit: BoxFit.contain,
                              errorBuilder:
                                  (_, __, ___) => const Icon(
                                    Icons.tv,
                                    color: Colors.white38,
                                    size: 40,
                                  ),
                            ),
                          )
                          : const Icon(
                            Icons.tv,
                            color: Colors.white38,
                            size: 40,
                          ),
                ),
                const SizedBox(height: 16),
                // Channel name
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (channelId.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    "Channel $channelId",
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 14,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Close",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String? _getLogoUrl(dynamic stream) {
    if (stream == null) return null;
    return stream["img"] ??
        stream["logo"] ??
        stream["logoUrl"] ??
        stream["icon"] ??
        stream["logo2Id"]?.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: _handleKeyEvent,
        child: Stack(
          children: [
            // ── Native video player ─────────────────────────────────────────
            Positioned.fill(
              child: Focus(
                focusNode: _videoFocusNode,
                child: AndroidView(
                  viewType: 'native_video_player',
                  layoutDirection: TextDirection.ltr,
                  creationParams: {"streamUrl": widget.streamUrl},
                  creationParamsCodec: const StandardMessageCodec(),
                  onPlatformViewCreated: _onPlatformViewCreated,
                ),
              ),
            ),

            // ── Overlay: channel list ───────────────────────────────────────
            Positioned.fill(
              child: Visibility(
                visible: _isOverlayVisible,
                maintainState: true,
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Column(
                    children: [
                      _buildHeader(),
                      const Spacer(),
                      _buildChannelList(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),

            // ── Player error overlay ────────────────────────────────────────
            if (_playerError != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.redAccent, width: 1.5),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.signal_cellular_connected_no_internet_4_bar,
                            color: Colors.redAccent,
                            size: 42,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Channel Unavailable',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'This stream is currently unavailable\non the server. Please try another channel.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 13,
                            ),
                          ),
                        ],
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

  Widget _buildHeader() {
    final streamName =
        _currentPlayingStream != null
            ? (_currentPlayingStream["name"] ?? "")
            : "";
    final streamId =
        _currentPlayingStream != null
            ? _currentPlayingStream["id"]?.toString() ?? ""
            : "";
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (streamName.isNotEmpty)
            Text(
              streamName,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (streamId.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white30),
              ),
              child: Text(
                "CH $streamId",
                style: const TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChannelList() {
    final streams = _discoveryService.streams;
    if (streams.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hint text for the user
        Padding(
          padding: const EdgeInsets.only(left: 24, bottom: 8),
          child: Text(
            "◄ ► Browse   OK Select   ▼ Close",
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 13,
            ),
          ),
        ),
        SizedBox(
          height: 150,
          child: Focus(
            focusNode: _streamsFocusNode,
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: _infiniteLoopCount,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              itemBuilder: (context, index) {
                final streamIndex = index % streams.length;
                final stream = streams[streamIndex];
                // Highlight = browsing cursor; Selected (blue) = currently playing
                final bool isPlaying = streamIndex == _playingStreamIndex;
                final bool isHighlighted =
                    streamIndex == _highlightedStreamIndex;

                return _buildStreamItem(
                  stream,
                  isPlaying: isPlaying,
                  isHighlighted: isHighlighted,
                  index: streamIndex,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStreamItem(
    dynamic stream, {
    required bool isPlaying,
    required bool isHighlighted,
    required int index,
  }) {
    final String name = stream["name"] ?? "Stream";
    final String? logoUrl = _getLogoUrl(stream);

    // Highlighted = amber border (browse cursor)
    // Playing = blue background
    return InkWell(
      onTap: () {
        setState(() => _highlightedStreamIndex = index);
        _confirmAndPlay();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 160,
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color:
              isPlaying ? Colors.blueAccent.withOpacity(0.85) : Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isHighlighted
                    ? Colors.amberAccent
                    : (isPlaying ? Colors.white : Colors.transparent),
            width: isHighlighted ? 4 : 2,
          ),
          boxShadow:
              isHighlighted
                  ? [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.35),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                  : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    logoUrl != null
                        ? Image.network(
                          logoUrl,
                          fit: BoxFit.contain,
                          errorBuilder:
                              (c, e, s) => const Icon(
                                Icons.tv,
                                color: Colors.white54,
                                size: 40,
                              ),
                        )
                        : const Icon(Icons.tv, color: Colors.white54, size: 40),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
