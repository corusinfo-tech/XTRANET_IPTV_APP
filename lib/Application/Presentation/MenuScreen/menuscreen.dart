// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;

import 'package:xeranet_tv_application/Application/BusinessLogic/Login/login_bloc.dart';
import 'package:xeranet_tv_application/Application/BusinessLogic/Login/login_state.dart';
import 'package:xeranet_tv_application/Application/BusinessLogic/Login/login_event.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  String focusColumn = 'category'; // 'category', 'channel', 'preview', 'logout'

  Timer? clockTimer;
  Timer? previewTimer;

  final ScrollController categoryScrollController = ScrollController();
  final ScrollController channelScrollController = ScrollController();

  Channel? previewChannel;
  MethodChannel? _previewChannelView;
  bool _isPreviewReady = false;
  int _previewZapCounter = 0;
  bool _isFullScreenActive = false;

  final FocusNode _mainFocusNode = FocusNode();

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mainFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    clockTimer?.cancel();
    previewTimer?.cancel();
    categoryScrollController.dispose();
    channelScrollController.dispose();
    _mainFocusNode.dispose();
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

      filterChannelsByCategory(initialization: true);

      if (channels.isNotEmpty) {
        if (widget.currentChannel != null) {
          previewChannel = channels.firstWhere(
            (c) => c.id == widget.currentChannel!.id,
            orElse: () => channels[0],
          );
        } else {
          previewChannel = channels[0];
        }
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mainFocusNode.requestFocus();
        _scrollToCurrentCategory();
        _scrollToCurrentChannel();
      });
    } catch (e) {
      debugPrint("Error loading bouquets: $e");
    }
  }

  Future<String?> getDrmStreamUrl(String rawUrl) async {
    return await PanDrmService.getStreamUrl(rawUrl);
  }

  void _onPreviewPlatformViewCreated(int id) {
    _previewChannelView = MethodChannel('native_video_player_$id');
    _isPreviewReady = true;
    if (previewChannel != null) {
      _playPreview(previewChannel!);
    }
  }

  Future<void> _playPreview(Channel ch) async {
    if (!_isPreviewReady) return;
    final currentZap = ++_previewZapCounter;
    final url = await getDrmStreamUrl(ch.streamingUrl);
    if (currentZap == _previewZapCounter && url != null && mounted) {
      _previewChannelView?.invokeMethod("changeStream", {"streamUrl": url});
    }
  }

  void _debouncedPreviewUpdate(Channel ch) {
    setState(() {
      previewChannel = ch;
    });
    previewTimer?.cancel();
    previewTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _playPreview(ch);
    });
  }

  Future<void> _launchFullScreen(Channel ch) async {
    final streamUrl = await getDrmStreamUrl(ch.streamingUrl);
    if (streamUrl != null && mounted) {
      setState(() {
        _isFullScreenActive = true;
      });
      // Short delay to ensure AndroidView is unmounted and native player is released
      await Future.delayed(const Duration(milliseconds: 100));

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) =>
                  FullScreenPlayerWidget(channel: ch, streamUrl: streamUrl),
        ),
      );

      if (mounted) {
        setState(() {
          _isFullScreenActive = false;
          _isPreviewReady = false;
        });
        // We do not call _playPreview here immediately because AndroidView needs to re-mount
        // and trigger _onPreviewPlatformViewCreated again.
      }
    }
  }

  void _selectChannel(Channel ch) {
    if (widget.currentChannel != null) {
      Navigator.pop(context, ch);
    } else {
      _launchFullScreen(ch);
    }
  }

  void filterChannelsByCategory({bool initialization = false}) {
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
      if (initialization && widget.currentChannel != null && sel.id == "all") {
        final idx = channels.indexWhere(
          (c) => c.id == widget.currentChannel!.id,
        );
        if (idx >= 0) {
          selectedChannelIndex = idx;
        } else {
          selectedChannelIndex = 0;
        }
      } else {
        selectedChannelIndex = 0;
      }
    });

    if (channelScrollController.hasClients) {
      channelScrollController.jumpTo(0);
    }
  }

  void _scrollToCurrentCategory() {
    if (categoryScrollController.hasClients) {
      categoryScrollController.animateTo(
        selectedCategoryIndex * 62.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _scrollToCurrentChannel() {
    if (channelScrollController.hasClients) {
      channelScrollController.animateTo(
        selectedChannelIndex * 86.0,
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

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, widget.currentChannel);
        return false;
      },
      child: BlocListener<LoginBloc, LoginState>(
        listener: (context, state) {
          if (state is LoginDataLoaded) {
            // Re-hydrate the memory lists retaining focus states
            _loadBouquetsAndChannels();
          }
        },
        child: RawKeyboardListener(
          focusNode: _mainFocusNode,
          onKey: (event) {
            if (event is RawKeyDownEvent) {
              if (focusColumn == 'category') {
                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  if (selectedCategoryIndex < categories.length - 1) {
                    setState(() => selectedCategoryIndex++);
                    filterChannelsByCategory();
                    _scrollToCurrentCategory();
                  }
                } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  if (selectedCategoryIndex == 0) {
                    setState(() => focusColumn = 'logout');
                  } else if (selectedCategoryIndex > 0) {
                    setState(() => selectedCategoryIndex--);
                    filterChannelsByCategory();
                    _scrollToCurrentCategory();
                  }
                } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                    event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.select) {
                  if (channels.isNotEmpty) {
                    setState(() => focusColumn = 'channel');
                    _debouncedPreviewUpdate(channels[selectedChannelIndex]);
                  }
                }
              } else if (focusColumn == 'channel') {
                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  if (selectedChannelIndex < channels.length - 1) {
                    setState(() => selectedChannelIndex++);
                    _debouncedPreviewUpdate(channels[selectedChannelIndex]);
                    _scrollToCurrentChannel();
                  }
                } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  setState(() => focusColumn = 'category');
                } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  if (selectedChannelIndex == 0) {
                    setState(() => focusColumn = 'logout');
                  } else {
                    setState(() => selectedChannelIndex--);
                    _debouncedPreviewUpdate(channels[selectedChannelIndex]);
                    _scrollToCurrentChannel();
                  }
                } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  setState(() => focusColumn = 'preview');
                } else if (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.select) {
                  _selectChannel(channels[selectedChannelIndex]);
                }
              } else if (focusColumn == 'preview') {
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  setState(() => focusColumn = 'channel');
                } else if (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.select) {
                  if (previewChannel != null) {
                    _selectChannel(previewChannel!);
                  }
                }
              } else if (focusColumn == 'logout') {
                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  setState(() => focusColumn = 'category');
                } else if (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.select) {
                  _showLogoutDialog(context);
                }
              }
            }
          },
          child: Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            body: Shortcuts(
              shortcuts: <LogicalKeySet, Intent>{
                LogicalKeySet(LogicalKeyboardKey.select):
                    const ActivateIntent(),
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
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryColumn() {
    final isFocusedColumn = focusColumn == "category";
    return Expanded(
      flex: 2,
      child: Container(
        decoration: BoxDecoration(
          color:
              isFocusedColumn
                  ? Colors.blueAccent.withOpacity(0.05)
                  : Colors.black.withOpacity(0.2),
          border: Border(
            left:
                isFocusedColumn
                    ? const BorderSide(color: Colors.blueAccent, width: 4)
                    : const BorderSide(color: Colors.transparent, width: 4),
            right: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
        ),
        child: ListView.builder(
          controller: categoryScrollController,
          itemCount: categories.length,
          padding: const EdgeInsets.symmetric(vertical: 20),
          itemBuilder: (context, index) {
            final cat = categories[index];
            final isSelected = index == selectedCategoryIndex;
            final isFocused = isFocusedColumn && isSelected;

            return Transform.scale(
              scale: isFocused ? 1.05 : 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 50,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow:
                      isFocused
                          ? [
                            BoxShadow(
                              color: Colors.blueAccent.withOpacity(0.5),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ]
                          : [],
                  gradient:
                      isFocused
                          ? const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                          )
                          : null,
                  color:
                      isFocused
                          ? null
                          : (isSelected
                              ? Colors.white.withOpacity(0.15)
                              : Colors.transparent),
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  cat.name,
                  maxLines: 1,
                  style: TextStyle(
                    color: isFocused ? Colors.white : Colors.white60,
                    fontWeight: isFocused ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildChannelColumn() {
    final isFocusedColumn = focusColumn == "channel";
    return Expanded(
      flex: 3,
      child: Container(
        decoration: BoxDecoration(
          color:
              isFocusedColumn
                  ? Colors.blueAccent.withOpacity(0.05)
                  : Colors.black.withOpacity(0.1),
          border: Border(
            bottom:
                isFocusedColumn
                    ? const BorderSide(color: Colors.blueAccent, width: 4)
                    : const BorderSide(color: Colors.transparent, width: 4),
            right: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
        ),
        child: ListView.builder(
          controller: channelScrollController,
          itemCount: channels.length,
          padding: const EdgeInsets.symmetric(vertical: 20),
          itemBuilder: (context, index) {
            final ch = channels[index];
            final isSelected = index == selectedChannelIndex;
            final isFocused = isFocusedColumn && isSelected;

            return Transform.scale(
              scale: isFocused ? 1.05 : 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 70,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  boxShadow:
                      isFocused
                          ? [
                            BoxShadow(
                              color: Colors.blueAccent.withOpacity(0.6),
                              blurRadius: 20,
                              spreadRadius: 3,
                            ),
                          ]
                          : [],
                  gradient:
                      isFocused
                          ? const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                          )
                          : null,
                  color:
                      isFocused
                          ? null
                          : (isSelected
                              ? Colors.white.withOpacity(0.15)
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
                              : const Icon(Icons.tv, color: Colors.white24),
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
                            style: TextStyle(
                              color: isFocused ? Colors.white : Colors.white60,
                              fontSize: 16,
                              fontWeight:
                                  isFocused
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          ),
                          Text(
                            "CH ${ch.channelNumber}",
                            style: TextStyle(
                              color:
                                  isFocused ? Colors.white70 : Colors.white38,
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
      ),
    );
  }

  Widget _buildPreviewColumn() {
    final isFocusedColumn = focusColumn == "preview";
    return Expanded(
      flex: 5,
      child: Container(
        color: const Color(0xFF0F172A),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isFocusedColumn ? Colors.blueAccent : Colors.white10,
                    width: isFocusedColumn ? 3.0 : 1.0,
                  ),
                  boxShadow:
                      isFocusedColumn
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
                  child: _isFullScreenActive 
                      ? const Center(child: CircularProgressIndicator())
                      : AndroidView(
                          viewType: 'native_video_player',
                          layoutDirection: TextDirection.ltr,
                          creationParams: const {},
                          creationParamsCodec: const StandardMessageCodec(),
                          onPlatformViewCreated: _onPreviewPlatformViewCreated,
                        ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child:
                    previewChannel == null
                        ? const SizedBox()
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              previewChannel!.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Channel ${previewChannel!.channelNumber} • ${previewChannel!.language} • ${previewChannel!.quality}",
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

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.logout, color: Colors.blueAccent, size: 48),
                const SizedBox(height: 24),
                const Text(
                  "Logout",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Are you sure you want to log out?",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 16),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(color: Colors.white60),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.read<LoginBloc>().add(LogoutRequested());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Logout",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
              const SizedBox(width: 32),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color:
                      focusColumn == 'logout'
                          ? Colors.blueAccent
                          : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        focusColumn == 'logout'
                            ? Colors.white
                            : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.logout,
                      color:
                          focusColumn == 'logout' ? Colors.white : Colors.white60,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Logout",
                      style: TextStyle(
                        color:
                            focusColumn == 'logout' ? Colors.white : Colors.white60,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
