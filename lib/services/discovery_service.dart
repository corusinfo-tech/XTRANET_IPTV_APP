import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'panaccess_drm_service.dart';

class DiscoveryService {
  static final DiscoveryService _instance = DiscoveryService._internal();
  factory DiscoveryService() => _instance;
  DiscoveryService._internal();

  List<dynamic> _categories = [];
  List<dynamic> _streams = [];
  List<dynamic> _bouquets = [];
  dynamic _selectedStreamId;
  String? _selectedStreamUrl;
  String? _selectedBouquetId;

  List<dynamic> get categories => _categories;
  List<dynamic> get streams => _streams;
  List<dynamic> get bouquets => _bouquets;
  dynamic get selectedStreamId => _selectedStreamId;
  String? get selectedStreamUrl => _selectedStreamUrl;
  String? get selectedBouquetId => _selectedBouquetId;

  /// Main entry point for content discovery
  Future<void> discoverAllContent() async {
    try {
      debugPrint("DiscoveryService: Starting full content discovery...");

      final drmInfo = await PanDrmService.getDrmInfo();
      debugPrint("DiscoveryService: Current DRM Info: $drmInfo");
      debugPrint(
        "DiscoveryService: Current Session ID: ${drmInfo?['sessionId']}",
      );

      // Clear previous state to avoid stale data
      _categories = [];
      _streams = [];
      _bouquets = [];
      _selectedStreamId = null;
      _selectedStreamUrl = null;
      _selectedBouquetId = null;
      _categories = await PanDrmService.getOttCategoryGroups();

      // First try bouquet query if supported by backend (cvGetBouquets).
      _bouquets = await PanDrmService.getBouquets();
      print("DiscoveryService: ═══════════════════════════════════════");
      print("DiscoveryService: Fetched ${_bouquets.length} BOUQUETS:");
      for (int i = 0; i < _bouquets.length; i++) {
        final bouquet = _bouquets[i];
        final id = bouquet["bouquetId"]?.toString() ?? "?";
        final name = bouquet["name"]?.toString() ?? "Unknown";
        final priority = bouquet["priority"]?.toString() ?? "?";
        print("  [${i + 1}] ID: $id | NAME: $name | PRIORITY: $priority");
      }
      print("DiscoveryService: ═══════════════════════════════════════");

      if (_bouquets.isNotEmpty) {
        debugPrint(
          "DiscoveryService: Bouquets present, parsing for channels...",
        );
        // Set first bouquet as default
        _selectedBouquetId = _bouquets[0]["bouquetId"]?.toString();
      }

      if (_categories.isEmpty) {
        debugPrint(
          "DiscoveryService: No categories found, attempting fallback to Available Streams...",
        );
        _streams = await PanDrmService.getAvailableStreams();
        if (_streams.isNotEmpty) {
          debugPrint(
            "DiscoveryService: LOADED ${_streams.length} STREAMS (Showing Full Metadata for first 10):",
          );
          for (var s in _streams.take(10)) {
            debugPrint(" - Stream Object: ${jsonEncode(s)}");
          }

          // Print channels per bouquet
          print("DiscoveryService: ═══════════════════════════════════════");
          print("DiscoveryService: CHANNELS PER BOUQUET:");
          for (final bouquet in _bouquets) {
            final bouquetId = bouquet["bouquetId"]?.toString() ?? "?";
            final bouquetName = bouquet["name"]?.toString() ?? "Unknown";
            final channelsInBouquet =
                _streams.where((s) {
                  final ids = s["bouquetIds"] as List?;
                  return ids != null && ids.contains(bouquetId);
                }).toList();
            print(
              "  $bouquetName (ID: $bouquetId): ${channelsInBouquet.length} channels",
            );
            // Show first 3 channels for this bouquet
            for (final channel in channelsInBouquet.take(3)) {
              final chName = channel["name"]?.toString() ?? "?";
              print("    - $chName");
            }
            if (channelsInBouquet.length > 3) {
              print(
                "    ... and ${channelsInBouquet.length - 3} more channels",
              );
            }
          }
          print("DiscoveryService: ═══════════════════════════════════════");

          final firstStream = _streams[0];
          _selectedStreamId = firstStream["id"] ?? firstStream["streamId"];
          _selectedStreamUrl = firstStream["url"];
          debugPrint(
            "DiscoveryService: Fallback success. Selected ID: $_selectedStreamId, URL: $_selectedStreamUrl",
          );
        }
        return;
      }

      // 2. Automatically find first available streams to populate initial state
      for (var group in _categories) {
        final groupCats = group["categories"] as List?;
        if (groupCats != null && groupCats.isNotEmpty) {
          final firstCatId = groupCats[0]["id"];
          debugPrint(
            "DiscoveryService: Fetching streams for first category: $firstCatId",
          );

          _streams = await PanDrmService.getOttStreamsByCategoryId(firstCatId);
          if (_streams.isNotEmpty) {
            final firstStream = _streams[0];
            _selectedStreamId = firstStream["id"] ?? firstStream["streamId"];
            _selectedStreamUrl = firstStream["url"] ?? firstStream["id"];
            debugPrint(
              "DiscoveryService: Auto-selected Stream ID: $_selectedStreamId, URL: $_selectedStreamUrl",
            );
            break;
          }
        }
      }

      debugPrint("DiscoveryService: Discovery completed successfully.");
    } catch (e) {
      debugPrint("DiscoveryService: Error during discovery: $e");
      rethrow;
    }
  }

  /// Helper to get streams for a specific category
  Future<void> loadStreamsForCategory(dynamic categoryId) async {
    try {
      _streams = await PanDrmService.getOttStreamsByCategoryId(categoryId);
      debugPrint(
        "DiscoveryService: Loaded ${_streams.length} streams for Category $categoryId (Showing Full Metadata for first 10):",
      );
      for (var s in _streams.take(10)) {
        debugPrint(" - Stream Object: ${jsonEncode(s)}");
      }
    } catch (e) {
      debugPrint("DiscoveryService: Error loading streams: $e");
      rethrow;
    }
  }

  /// Get streams for a specific bouquet
  List<dynamic> getStreamsForBouquet(String bouquetId) {
    if (bouquetId == "all") {
      return _streams; // Return all streams
    }
    return _streams.where((stream) {
      final bouquetIds = stream["bouquetIds"] as List?;
      return bouquetIds != null && bouquetIds.contains(bouquetId);
    }).toList();
  }

  /// Select a bouquet and filter streams
  void selectBouquet(String bouquetId) {
    _selectedBouquetId = bouquetId;
    debugPrint("DiscoveryService: Selected bouquet: $bouquetId");
  }

  /// Get currently filtered streams based on selected bouquet
  List<dynamic> getFilteredStreams() {
    if (_selectedBouquetId == null || _selectedBouquetId == "all") {
      return _streams;
    }
    return getStreamsForBouquet(_selectedBouquetId!);
  }
}
