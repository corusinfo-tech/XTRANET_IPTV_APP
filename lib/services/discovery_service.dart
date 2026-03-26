import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'panaccess_drm_service.dart';

class DiscoveryService {
  static final DiscoveryService _instance = DiscoveryService._internal();
  factory DiscoveryService() => _instance;
  DiscoveryService._internal();

  List<dynamic> _categories = [];
  List<dynamic> _streams = [];
  dynamic _selectedStreamId;
  String? _selectedStreamUrl;

  List<dynamic> get categories => _categories;
  List<dynamic> get streams => _streams;
  dynamic get selectedStreamId => _selectedStreamId;
  String? get selectedStreamUrl => _selectedStreamUrl;

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
      _selectedStreamId = null;
      _selectedStreamUrl = null;
      _categories = await PanDrmService.getOttCategoryGroups();

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
}
