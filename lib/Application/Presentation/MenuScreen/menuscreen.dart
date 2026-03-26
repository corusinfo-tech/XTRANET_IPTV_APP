// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:xeranet_tv_application/Application/Presentation/FullScreen/fullscreen.dart';
import 'package:xeranet_tv_application/Data/Interface/ChannelData/channeldata.dart';

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
  final void Function(Channel channel, List<Channel> allChannels)?
  onChannelSelect;

  const MainScreen({super.key, this.onChannelSelect});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with RouteAware {
  /// 🔹 DRM METHOD CHANNEL
  static const MethodChannel drmChannel = MethodChannel("panaccess_drm");

  // ------------------ Layout ------------------
  static const double _baseCategoryFraction = 0.18;
  static const double _baseChannelFraction = 0.26;
  static const double _minPreviewFraction = 0.46;

  static const double _baseHeaderHeight = 96.0;
  static const double _baseCategoryItemHeight = 72.0;
  static const double _baseChannelItemHeight = 92.0;
  static const double _basePreviewPadding = 24.0;

  // ------------------ Data ------------------
  List<Category> categories = [];
  List<Channel> channels = [];
  List<Channel> allChannels = [];

  int selectedCategoryIndex = 0;
  int selectedChannelIndex = 0;

  DateTime currentTime = DateTime.now();

  String focusColumn = 'category';

  Map<String, List<EPGProgram>> epgData = {};

  String channelNumberInput = '';

  Timer? channelNumberTimer;
  Timer? clockTimer;

  final ScrollController categoryScrollController = ScrollController();
  final ScrollController channelScrollController = ScrollController();
  final FocusNode focusNode = FocusNode();

  Channel? selectedChannel;

  int selectedHeaderIndex = 0;

  // ------------------------------------------------
  // INIT
  // ------------------------------------------------
  @override
  void initState() {
    super.initState();

    categories = [
      Category(id: "all", name: "All Channels"),
      Category(id: "ent", name: "Entertainment"),
      Category(id: "sports", name: "Sports"),
      Category(id: "news", name: "News"),
      Category(id: "kids", name: "Kids"),
      Category(id: "music", name: "Music"),
    ];

    // ⚠️ HARDCODED DATA (FOR TESTING ONLY)
    // Replace with API or DRM service list later
    // TODO: Fetch channels from backend API after DRM login
    /*
    allChannels = [
      Channel(
        id: "101",
        name: "Star Plus HD",
        serviceId: 30882523, // 🔹 DRM SERVICE ID
        categoryId: "ent",
        channelNumber: 101,
        logoUrl: "",
        language: "Hindi",
        quality: "HD",
      ),
      Channel(
        id: "201",
        name: "Star Sports 1",
        serviceId: 30882524,
        categoryId: "sports",
        channelNumber: 201,
        logoUrl: "",
        language: "English",
        quality: "HD",
      ),
    ];
    */

    filterChannelsByCategory();

    clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          currentTime = DateTime.now();
        });
      }
    });
  } // ------------------------------------------------

  // DRM STREAM REQUEST
  // ------------------------------------------------
  /// Fetch DRM stream URL using MethodChannel
  /// Uses serviceId from Channel to request encrypted stream
  Future<String?> getDrmStreamUrl(int serviceId) async {
    try {
      final String? url = await drmChannel.invokeMethod("getStreamUrl", {
        "streamId": serviceId, // Pass serviceId as streamId to DRM
      });
      debugPrint(
        "✅ Stream URL obtained from DRM: ${url != null ? 'Success' : 'Null'}",
      );
      return url;
    } catch (e) {
      debugPrint("❌ DRM error: $e");
      return null;
    }
  }

  // ------------------------------------------------
  // CHANNEL SELECTION
  // ------------------------------------------------
  /// When channel is selected:
  /// 1. Use serviceId to fetch DRM stream URL
  /// 2. Pass encrypted URL to FullScreenPlayerWidget
  Future<void> _onChannelSelected(Channel ch) async {
    setState(() {
      selectedChannel = ch;
    });

    debugPrint(
      "🎬 Requesting stream for: ${ch.name} (serviceId: ${ch.serviceId})",
    );

    // Fetch DRM stream URL using serviceId
    final streamUrl = await getDrmStreamUrl(ch.serviceId);

    if (streamUrl != null && mounted) {
      debugPrint("✅ Stream URL ready, launching player");

      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) =>
                  FullScreenPlayerWidget(channel: ch, streamUrl: streamUrl),
        ),
      );
    } else {
      debugPrint("❌ Failed to get stream URL for ${ch.name}");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to get stream URL")),
        );
      }
    }
  }

  // ------------------------------------------------
  // FILTER CHANNELS
  // ------------------------------------------------
  void filterChannelsByCategory() {
    final sel = categories[selectedCategoryIndex];

    if (sel.id == "all") {
      channels = List.from(allChannels);
    } else {
      channels = allChannels.where((c) => c.categoryId == sel.id).toList();
    }

    selectedChannelIndex = channels.isNotEmpty ? 0 : -1;

    setState(() {});
  }

  // ------------------------------------------------
  // KEY EVENTS
  // ------------------------------------------------
  void onKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (focusColumn == "category") {
          if (selectedCategoryIndex > 0) {
            selectedCategoryIndex--;
            filterChannelsByCategory();
          }
        } else if (focusColumn == "channel") {
          if (selectedChannelIndex > 0) {
            selectedChannelIndex--;
          }
        }

        setState(() {});
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (focusColumn == "category") {
          if (selectedCategoryIndex < categories.length - 1) {
            selectedCategoryIndex++;
            filterChannelsByCategory();
          }
        } else if (focusColumn == "channel") {
          if (selectedChannelIndex < channels.length - 1) {
            selectedChannelIndex++;
          }
        }

        setState(() {});
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (focusColumn == "channel" && channels.isNotEmpty) {
          final ch = channels[selectedChannelIndex];

          _onChannelSelected(ch);
        }
      }
    }
  }

  // ------------------------------------------------
  // BUILD
  // ------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scale = (size.width / 1366).clamp(0.8, 1.2);

    final headerHeight = _baseHeaderHeight * scale;

    final timeStr = DateFormat.jm().format(currentTime);

    return Focus(
      focusNode: focusNode,
      autofocus: true,
      onKey: (node, event) {
        onKey(event);
        return KeyEventResult.handled;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _header(timeStr, headerHeight, scale),
              ),

              Positioned.fill(
                top: headerHeight,
                child: Row(
                  children: [
                    /// ---------------- CATEGORIES ----------------
                    Expanded(
                      flex: 2,
                      child: ListView.builder(
                        controller: categoryScrollController,
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          final selected = index == selectedCategoryIndex;

                          return Container(
                            height: 60,
                            color: selected ? Colors.blue : Colors.transparent,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              cat.name,
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        },
                      ),
                    ),

                    /// ---------------- CHANNELS ----------------
                    Expanded(
                      flex: 3,
                      child: ListView.builder(
                        controller: channelScrollController,
                        itemCount: channels.length,
                        itemBuilder: (context, index) {
                          final ch = channels[index];
                          final selected = index == selectedChannelIndex;

                          return GestureDetector(
                            onTap: () => _onChannelSelected(ch),
                            child: Container(
                              height: 70,
                              color:
                                  selected ? Colors.blue : Colors.transparent,
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    color: Colors.grey,
                                  ),

                                  const SizedBox(width: 10),

                                  Text(
                                    ch.name,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    /// ---------------- PREVIEW ----------------
                    Expanded(
                      flex: 5,
                      child: Container(
                        alignment: Alignment.center,
                        child: const Text(
                          "DRM Preview Disabled\nPreview only works in Fullscreen Player",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------
  // HEADER
  // ------------------------------------------------
  Widget _header(String timeStr, double headerHeight, double scale) {
    return Container(
      height: headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Xeranet TV",
            style: TextStyle(color: Colors.white, fontSize: 24),
          ),

          Text(timeStr, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}
