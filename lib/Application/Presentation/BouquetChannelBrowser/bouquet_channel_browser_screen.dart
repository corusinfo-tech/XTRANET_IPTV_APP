import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xeranet_tv_application/services/discovery_service.dart';
import 'package:xeranet_tv_application/Domine/Widget/bouquet_selector.dart';
import 'package:xeranet_tv_application/Domine/Widget/bouquet_channel_list.dart';
import 'package:xeranet_tv_application/Application/Presentation/MenuScreen/menuscreen.dart';
import 'package:xeranet_tv_application/Application/Presentation/FullScreen/fullscreen.dart';
import 'package:xeranet_tv_application/Data/Interface/ChannelData/channeldata.dart';
import 'package:xeranet_tv_application/services/panaccess_drm_service.dart';

/// Bouquet Channel Browser Screen
class BouquetChannelBrowserScreen extends StatefulWidget {
  const BouquetChannelBrowserScreen({Key? key}) : super(key: key);

  @override
  State<BouquetChannelBrowserScreen> createState() =>
      _BouquetChannelBrowserScreenState();
}

class _BouquetChannelBrowserScreenState
    extends State<BouquetChannelBrowserScreen> {
  final DiscoveryService _discoveryService = DiscoveryService();
  late String _selectedBouquetId;

  // Category overlay state
  bool _showCategoryOverlay = false;
  int _selectedCategoryIndex = 0;
  int _selectedChannelIndex = 0;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _selectedBouquetId = _discoveryService.selectedBouquetId ?? "all";
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleBouquetSelected(String bouquetId) {
    setState(() {
      _selectedBouquetId = bouquetId;
    });
  }

  void _handleChannelSelected(dynamic channel) {
    setState(() {
      _showCategoryOverlay = true;
      _selectedCategoryIndex = 0;
      _selectedChannelIndex = 0;
    });
  }

  Future<String?> getDrmStreamUrl(String rawUrl) async {
    return await PanDrmService.getStreamUrl(rawUrl);
  }

  Future<void> _onChannelSelected(Channel ch) async {
    debugPrint("🎬 Requesting stream for: ${ch.name} (ID: ${ch.id})");

    final streamUrl = await getDrmStreamUrl(ch.streamingUrl);

    if (streamUrl != null && mounted) {
      debugPrint("✅ Stream ready, playing channel");
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FullScreenPlayerWidget(
            channel: ch,
            streamUrl: streamUrl,
          ),
        ),
      );
      setState(() {
        _showCategoryOverlay = false;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to get stream URL"),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildCategoryOverlay() {
    final size = MediaQuery.of(context).size;
    final scale = (size.width / 1366).clamp(0.8, 1.2);

    final categories = [
      Category(id: "all", name: "All Channels"),
      ..._discoveryService.bouquets.map((b) => Category(id: b["bouquetId"]?.toString() ?? "", name: b["name"]?.toString() ?? "Unknown")),
    ];

    final allChannels = _discoveryService.streams
        .map<Channel>((s) => Channel.fromMap(s is Map ? Map<String, dynamic>.from(s) : {}))
        .toList();

    List<Channel> channels = [];
    if (categories.isNotEmpty) {
      final selCat = categories[_selectedCategoryIndex];
      if (selCat.id == "all") {
        channels = List.from(allChannels);
      } else {
        channels = allChannels.where((c) => c.categoryId == selCat.id).toList();
      }
    }

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.9),
        child: Column(
          children: [
            Container(
              height: 80 * scale,
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Row(
                children: [
                  Text("Select Category & Channel", style: TextStyle(color: Colors.white, fontSize: 24 * scale, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  const Text("Press ESC to close | Arrow keys to navigate | ENTER to select", style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  _buildOverlayColumn("Categories", categories.map((e) => e.name).toList(), _selectedCategoryIndex, true, scale),
                  _buildOverlayColumn("Channels", channels.map((e) => e.name).toList(), _selectedChannelIndex, false, scale),
                  Expanded(
                    flex: 2,
                    child: Container(
                      margin: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                      child: Center(
                        child: Text(
                          channels.isNotEmpty ? "Channel: ${channels[_selectedChannelIndex].name}\n\nPress ENTER to play" : "No channels available",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlayColumn(String title, List<String> items, int selectedIdx, bool isFlex2, double scale) {
    return Expanded(
      flex: isFlex2 ? 2 : 3,
      child: Container(
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Padding(padding: const EdgeInsets.all(20), child: Text(title, style: TextStyle(color: Colors.white, fontSize: 18 * scale, fontWeight: FontWeight.bold))),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final isSel = index == selectedIdx;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(color: isSel ? Colors.blueAccent : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                    child: Text(items[index], style: const TextStyle(color: Colors.white)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: (event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            if (_showCategoryOverlay) {
              setState(() => _showCategoryOverlay = false);
              return;
            }
          }
          if (_showCategoryOverlay) {
            final categories = [
              Category(id: "all", name: "All Channels"),
              ..._discoveryService.bouquets.map((b) => Category(id: b["bouquetId"]?.toString() ?? "", name: b["name"]?.toString() ?? "Unknown")),
            ];
            final selCat = categories[_selectedCategoryIndex];
            List<Channel> channels = [];
            if (selCat.id == "all") {
              channels = _discoveryService.streams.map<Channel>((s) => Channel.fromMap(s is Map ? Map<String, dynamic>.from(s) : {})).toList();
            } else {
              channels = _discoveryService.streams
                  .map<Channel>((s) => Channel.fromMap(s is Map ? Map<String, dynamic>.from(s) : {}))
                  .where((c) => c.categoryId == selCat.id).toList();
            }

            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              setState(() => _selectedChannelIndex = _selectedChannelIndex > 0 ? _selectedChannelIndex - 1 : 0);
            } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              setState(() => _selectedChannelIndex = _selectedChannelIndex < channels.length - 1 ? _selectedChannelIndex + 1 : channels.length - 1);
            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              setState(() {
                _selectedCategoryIndex = _selectedCategoryIndex > 0 ? _selectedCategoryIndex - 1 : 0;
                _selectedChannelIndex = 0;
              });
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              setState(() {
                _selectedCategoryIndex = _selectedCategoryIndex < categories.length - 1 ? _selectedCategoryIndex + 1 : categories.length - 1;
                _selectedChannelIndex = 0;
              });
            } else if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.select) {
              if (channels.isNotEmpty) _onChannelSelected(channels[_selectedChannelIndex]);
            }
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: const Text("Channels by Bouquet"), backgroundColor: const Color(0xFF0F172A)),
        body: Stack(
          children: [
            Column(
              children: [
                BouquetSelector(discoveryService: _discoveryService, onBouquetSelected: _handleBouquetSelected),
                Expanded(child: BouquetChannelList(discoveryService: _discoveryService, selectedBouquetId: _selectedBouquetId, onChannelSelected: _handleChannelSelected)),
              ],
            ),
            if (_showCategoryOverlay) _buildCategoryOverlay(),
          ],
        ),
      ),
    );
  }
}
