// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;

import 'package:xeranet_tv_application/Application/Presentation/FullScreen/fullscreen.dart';
import 'package:xeranet_tv_application/Data/Interface/ChannelData/channeldata.dart';
import 'package:xeranet_tv_application/services/discovery_service.dart';
import 'package:xeranet_tv_application/services/panaccess_drm_service.dart';

// ========== DATA MODELS ==========
class Category {
  final String id;
  final String name;

  Category({required this.id, required this.name});
}

class EPGProgram {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String description;

  EPGProgram({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.description,
  });
}

class MainScreen extends StatefulWidget {
  final Channel? currentChannel;
  final void Function(Channel channel, List<Channel> allChannels)?
  onChannelSelect;

  const MainScreen({super.key, this.onChannelSelect, this.currentChannel});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with RouteAware {
  // ------------------ Data ------------------
  List<Category> categories = [];
  List<Channel> channels = [];
  List<Channel> allChannels = [];

  final DiscoveryService _discoveryService = DiscoveryService();

  int selectedCategoryIndex = 0;
  int selectedChannelIndex = 0;

  DateTime currentTime = DateTime.now();
  String focusColumn = 'category';

  Timer? clockTimer;
  Timer? previewTimer;

  final ScrollController categoryScrollController = ScrollController();
  final ScrollController channelScrollController = ScrollController();

  Channel? selectedChannel;
  MethodChannel? _previewChannel;
  bool _isPreviewReady = false;
  int _previewZapCounter = 0;

  @override
  void initState() {
    super.initState();
    _loadBouquetsAndChannels();

    clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    clockTimer?.cancel();
    previewTimer?.cancel();
    categoryScrollController.dispose();
    channelScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadBouquetsAndChannels() async {
    try {
      setState(() {
        categories = [];
        allChannels = [];
      });

      categories = [
        Category(id: "all", name: "All Channels"),
        ..._discoveryService.bouquets.map((bouquet) {
          final id = bouquet["bouquetId"]?.toString() ?? "";
          final name = bouquet["name"]?.toString() ?? "Unknown";
          return Category(id: id, name: name);
        }).toList(),
      ];

      allChannels =
          _discoveryService.streams.map<Channel>((stream) {
            return Channel.fromMap(
              stream is Map<String, dynamic>
                  ? stream
                  : Map<String, dynamic>.from(stream),
            );
          }).toList();

      filterChannelsByCategory();

      if (widget.currentChannel != null) {
        final initialIdx = allChannels.indexWhere(
          (c) => c.id == widget.currentChannel!.id,
        );
        if (initialIdx >= 0) {
          selectedChannelIndex = initialIdx;
          selectedChannel = allChannels[selectedChannelIndex];
          selectedCategoryIndex = 0;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToCurrentChannel();
          });
        } else if (channels.isNotEmpty) {
          selectedChannel = channels[selectedChannelIndex];
        }
      } else if (channels.isNotEmpty) {
        selectedChannel = channels[selectedChannelIndex];
      }
    } catch (e) {
      debugPrint("Error loading bouquets: $e");
    }
  }

  Future<String?> getDrmStreamUrl(String rawUrl) async {
    return await PanDrmService.getStreamUrl(rawUrl);
  }

  void _onPreviewPlatformViewCreated(int id) {
    _previewChannel = MethodChannel('native_video_player_$id');
    _isPreviewReady = true;
    if (selectedChannel != null) {
      _playPreview(selectedChannel!);
    }
  }

  Future<void> _playPreview(Channel ch) async {
    if (!_isPreviewReady) return;
    final currentZap = ++_previewZapCounter;
    final url = await getDrmStreamUrl(ch.streamingUrl);
    if (currentZap == _previewZapCounter && url != null && mounted) {
      _previewChannel?.invokeMethod("changeStream", {"streamUrl": url});
    }
  }

  void _debouncedPreviewUpdate(Channel ch) {
    previewTimer?.cancel();
    previewTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _playPreview(ch);
    });
  }

  Future<void> _launchFullScreen(Channel ch) async {
    final streamUrl = await getDrmStreamUrl(ch.streamingUrl);
    if (streamUrl != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) =>
                  FullScreenPlayerWidget(channel: ch, streamUrl: streamUrl),
        ),
      );
    }
  }

  void filterChannelsByCategory() {
    final sel = categories[selectedCategoryIndex];
    if (sel.id == "all") {
      channels = List.from(allChannels);
    } else {
      channels =
          allChannels.where((c) {
            final stream = _discoveryService.streams.firstWhere(
              (s) => s["id"]?.toString() == c.id,
              orElse: () => null,
            );
            if (stream != null) {
              final bIds = stream["bouquetIds"] as List?;
              return bIds != null && bIds.contains(sel.id);
            }
            return false;
          }).toList();
    }

    setState(() {
      selectedChannelIndex = 0;
      if (channels.isNotEmpty) {
        selectedChannel = channels[0];
      } else {
        selectedChannel = null;
      }
    });

    if (channelScrollController.hasClients) {
      channelScrollController.jumpTo(0);
    }
  }

  void _scrollToCurrentCategory() {
    if (categoryScrollController.hasClients) {
      categoryScrollController.animateTo(
        selectedCategoryIndex * 60.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _scrollToCurrentChannel() {
    if (channelScrollController.hasClients) {
      channelScrollController.animateTo(
        selectedChannelIndex * 80.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scale = (size.width / 1366).clamp(0.8, 1.2);
    final headerHeight = 96.0 * scale;
    final timeStr = intl.DateFormat.jm().format(currentTime);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
          LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
        },
        child: SafeArea(
          child: Column(
            children: [
              _header(timeStr, headerHeight, scale),
              Expanded(
                child: Row(
                  children: [
                    _buildCategoryColumn(),
                    _buildChannelColumn(),
                    _buildPreviewColumn(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryColumn() {
    final isFocused = focusColumn == "category";
    return Expanded(
      flex: 2,
      child: Container(
        decoration: BoxDecoration(
          color:
              isFocused
                  ? Colors.blueAccent.withOpacity(0.05)
                  : Colors.black.withOpacity(0.2),
          border: Border(
            right: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
        ),
        child: ListView.builder(
          controller: categoryScrollController,
          itemCount: categories.length,
          padding: const EdgeInsets.symmetric(vertical: 20),
          itemBuilder: (context, index) {
            final cat = categories[index];
            return Focus(
              onFocusChange: (f) {
                if (f) {
                  setState(() {
                    focusColumn = "category";
                    selectedCategoryIndex = index;
                  });
                  filterChannelsByCategory();
                  _scrollToCurrentCategory();
                }
              },
              child: Builder(
                builder: (ctx) {
                  final hasFocus = Focus.of(ctx).hasFocus;
                  return Transform.scale(
                    scale: hasFocus ? 1.05 : 1.0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 50,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow:
                            hasFocus
                                ? [
                                  BoxShadow(
                                    color: Colors.blueAccent.withOpacity(0.5),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                  ),
                                ]
                                : [],
                        gradient:
                            hasFocus
                                ? const LinearGradient(
                                  colors: [
                                    Color(0xFF2563EB),
                                    Color(0xFF3B82F6),
                                  ],
                                )
                                : null,
                        color:
                            hasFocus
                                ? null
                                : (index == selectedCategoryIndex
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.transparent),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        cat.name,
                        maxLines: 1,
                        style: TextStyle(
                          color:
                              hasFocus || index == selectedCategoryIndex
                                  ? Colors.white
                                  : Colors.white60,
                          fontWeight:
                              hasFocus || index == selectedCategoryIndex
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildChannelColumn() {
    final isFocused = focusColumn == "channel";
    return Expanded(
      flex: 3,
      child: Container(
        decoration: BoxDecoration(
          color:
              isFocused
                  ? Colors.blueAccent.withOpacity(0.05)
                  : Colors.black.withOpacity(0.1),
          border: Border(
            right: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
        ),
        child: ListView.builder(
          controller: channelScrollController,
          itemCount: channels.length,
          padding: const EdgeInsets.symmetric(vertical: 20),
          itemBuilder: (context, index) {
            final ch = channels[index];
            return Focus(
              onFocusChange: (f) {
                if (f) {
                  setState(() {
                    focusColumn = "channel";
                    selectedChannelIndex = index;
                    selectedChannel = ch;
                  });
                  _debouncedPreviewUpdate(ch);
                  _scrollToCurrentChannel();
                }
              },
              onKey: (node, event) {
                if (event is RawKeyDownEvent &&
                    (event.logicalKey == LogicalKeyboardKey.enter ||
                        event.logicalKey == LogicalKeyboardKey.select)) {
                  _launchFullScreen(ch);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Builder(
                builder: (ctx) {
                  final hasFocus = Focus.of(ctx).hasFocus;
                  return Transform.scale(
                    scale: hasFocus ? 1.05 : 1.0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 70,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        boxShadow:
                            hasFocus
                                ? [
                                  BoxShadow(
                                    color: Colors.blueAccent.withOpacity(0.6),
                                    blurRadius: 20,
                                    spreadRadius: 3,
                                  ),
                                ]
                                : [],
                        gradient:
                            hasFocus
                                ? const LinearGradient(
                                  colors: [
                                    Color(0xFF2563EB),
                                    Color(0xFF3B82F6),
                                  ],
                                )
                                : null,
                        color:
                            hasFocus
                                ? null
                                : (index == selectedChannelIndex
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.transparent),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child:
                                ch.logoUrl.isNotEmpty
                                    ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        ch.logoUrl,
                                        errorBuilder:
                                            (_, __, ___) => const Icon(
                                              Icons.tv,
                                              color: Colors.white24,
                                            ),
                                      ),
                                    )
                                    : const Icon(
                                      Icons.tv,
                                      color: Colors.white24,
                                    ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ch.name,
                                  maxLines: 1,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "CH ${ch.channelNumber}",
                                  style: TextStyle(
                                    color:
                                        hasFocus
                                            ? Colors.white70
                                            : Colors.white38,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPreviewColumn() {
    final isFocused = focusColumn == "preview";
    return Expanded(
      flex: 5,
      child: Container(
        color: const Color(0xFF0F172A),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Focus(
                onFocusChange: (f) {
                  if (f) setState(() => focusColumn = "preview");
                },
                onKey: (node, event) {
                  if (event is RawKeyDownEvent &&
                      (event.logicalKey == LogicalKeyboardKey.enter ||
                          event.logicalKey == LogicalKeyboardKey.select)) {
                    if (selectedChannel != null)
                      _launchFullScreen(selectedChannel!);
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: Builder(
                  builder: (ctx) {
                    final hasFocus = Focus.of(ctx).hasFocus;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: hasFocus ? Colors.blueAccent : Colors.white10,
                          width: hasFocus ? 3.0 : 1.0,
                        ),
                        boxShadow:
                            hasFocus
                                ? [
                                  BoxShadow(
                                    color: Colors.blueAccent.withOpacity(0.5),
                                    blurRadius: 20,
                                    spreadRadius: 4,
                                  ),
                                ]
                                : [],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: AndroidView(
                          viewType: 'native_video_player',
                          layoutDirection: TextDirection.ltr,
                          creationParams: const {},
                          creationParamsCodec: const StandardMessageCodec(),
                          onPlatformViewCreated: _onPreviewPlatformViewCreated,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child:
                    selectedChannel == null
                        ? const SizedBox()
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedChannel!.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Channel ${selectedChannel!.channelNumber} • ${selectedChannel!.language} • ${selectedChannel!.quality}",
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              "EPG Information would be displayed here for the current program.",
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(String timeStr, double headerHeight, double scale) {
    return Container(
      height: headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.tv, color: Colors.blueAccent, size: 32),
              const SizedBox(width: 12),
              Text(
                "XTRANET TV",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24 * scale,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.access_time, color: Colors.white38, size: 20),
              const SizedBox(width: 8),
              Text(
                timeStr,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
