import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'panaccess_drm_service.dart';

// Top-level function for background isolate computation
List<dynamic> _parseData(String jsonStr) {
  try {
    return jsonDecode(jsonStr) as List<dynamic>;
  } catch (e) {
    return [];
  }
}

class DiscoveryService {
  static final DiscoveryService _instance = DiscoveryService._internal();
  factory DiscoveryService() => _instance;
  DiscoveryService._internal();

  List<dynamic> _streams = [];
  List<dynamic> _bouquets = [];
  dynamic _selectedStreamId;
  String? _selectedStreamUrl;
  String? _selectedBouquetId;

  List<dynamic> get categories => []; // Maintained for backward compatibility if needed
  List<dynamic> get streams => _streams;
  List<dynamic> get bouquets => _bouquets;
  dynamic get selectedStreamId => _selectedStreamId;
  String? get selectedStreamUrl => _selectedStreamUrl;
  String? get selectedBouquetId => _selectedBouquetId;

  /// Load from local cache. Returns true if cache exists AND is not empty.
  Future<bool> loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final bStr = prefs.getString('cache_bouquets');
    final sStr = prefs.getString('cache_streams');
    
    if (bStr != null) {
      _bouquets = await compute(_parseData, bStr);
      if (_bouquets.isNotEmpty) {
        _selectedBouquetId = _bouquets[0]["bouquetId"]?.toString();
      }
    }
    
    if (sStr != null) {
      _streams = await compute(_parseData, sStr);
      if (_streams.isNotEmpty) {
        final firstStream = _streams[0];
        _selectedStreamId = firstStream["id"] ?? firstStream["streamId"];
        _selectedStreamUrl = firstStream["url"];
      }
    }
    
    debugPrint("DiscoveryService: Loaded ${_bouquets.length} bouquets and ${_streams.length} streams from CACHE.");
    
    return _streams.isNotEmpty;
  }

  /// Main entry point for content discovery
  Future<void> discoverAllContent() async {
    try {
      debugPrint("DiscoveryService: Starting parallel content discovery...");

      // 1. Fetch APIs Simultaneously with Partial Failure Safety
      final results = await Future.wait([
        PanDrmService.getBouquets().catchError((e) {
          debugPrint("Failed to fetch bouquets: $e");
          return <dynamic>[];
        }),
        PanDrmService.getAvailableStreams().catchError((e) {
          debugPrint("Failed to fetch streams: $e");
          return <dynamic>[];
        }),
      ]);

      final fetchedBouquets = results[0];
      final fetchedStreamsRaw = results[1];

      // 2. Offload heavy stream parsing to background isolate to prevent UI freezing
      final processedStreams = await compute(_parseData, jsonEncode(fetchedStreamsRaw));

      _bouquets = fetchedBouquets;
      _streams = processedStreams;

      // 3. Save cache post-compute inside safe lock
      // We only overwrite cache if data actually arrived successfully to prevent overwriting with blanks
      if (_streams.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cache_bouquets', jsonEncode(_bouquets));
        await prefs.setString('cache_streams', jsonEncode(_streams));
      }

      if (_bouquets.isNotEmpty) {
        debugPrint("DiscoveryService: Loaded ${_bouquets.length} bouquets.");
        _selectedBouquetId = _bouquets[0]["bouquetId"]?.toString();
      }

      if (_streams.isNotEmpty) {
        debugPrint("DiscoveryService: Loaded ${_streams.length} streams.");
        final firstStream = _streams[0];
        _selectedStreamId = firstStream["id"] ?? firstStream["streamId"];
        _selectedStreamUrl = firstStream["url"];
      }

      debugPrint("DiscoveryService: Discovery completed successfully.");
    } catch (e) {
      debugPrint("DiscoveryService: Error during discovery: $e");
      rethrow;
    }
  }

  /// Silently update cache in the background 
  Future<void> discoverAllContentSilently() async {
    try {
      await discoverAllContent();
    } catch (e) {
      debugPrint("Silent discovery failed: $e");
      rethrow; // Upstream logic can handle session expiry if this fails catastrophically
    }
  }

  /// Helper methods
  List<dynamic> getStreamsForBouquet(String bouquetId) {
    if (bouquetId == "all") {
      return _streams;
    }
    return _streams.where((stream) {
      final bouquetIds = stream["bouquetIds"] as List?;
      return bouquetIds != null && bouquetIds.contains(bouquetId);
    }).toList();
  }

  void selectBouquet(String bouquetId) {
    _selectedBouquetId = bouquetId;
  }

  List<dynamic> getFilteredStreams() {
    if (_selectedBouquetId == null || _selectedBouquetId == "all") {
      return _streams;
    }
    return getStreamsForBouquet(_selectedBouquetId!);
  }
}
