import 'package:flutter/material.dart';
import '../../services/discovery_service.dart';

/// Bouquet Selector Widget
/// Displays a horizontal list of bouquets with channel count
/// Allows filtering channels by selected bouquet
class BouquetSelector extends StatefulWidget {
  final DiscoveryService discoveryService;
  final Function(String) onBouquetSelected;

  const BouquetSelector({
    Key? key,
    required this.discoveryService,
    required this.onBouquetSelected,
  }) : super(key: key);

  @override
  State<BouquetSelector> createState() => _BouquetSelectorState();
}

class _BouquetSelectorState extends State<BouquetSelector> {
  late String _selectedBouquetId;

  @override
  void initState() {
    super.initState();
    _selectedBouquetId = widget.discoveryService.selectedBouquetId ?? "all";
  }

  int _getChannelCountForBouquet(String bouquetId) {
    return widget.discoveryService.getStreamsForBouquet(bouquetId).length;
  }

  @override
  Widget build(BuildContext context) {
    final bouquets = widget.discoveryService.bouquets;
    final allChannelCount = widget.discoveryService.streams.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Bouquets (${bouquets.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // "All Channels" option
              _buildBouquetCard(
                id: "all",
                name: "All Channels",
                count: allChannelCount,
                isSelected: _selectedBouquetId == "all",
              ),
              // Individual bouquets
              ...bouquets.map((bouquet) {
                final id = bouquet["bouquetId"]?.toString() ?? "";
                final name = bouquet["name"]?.toString() ?? "Unknown";
                final count = _getChannelCountForBouquet(id);
                return _buildBouquetCard(
                  id: id,
                  name: name,
                  count: count,
                  isSelected: _selectedBouquetId == id,
                );
              }).toList(),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildBouquetCard({
    required String id,
    required String name,
    required int count,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedBouquetId = id;
        });
        widget.discoveryService.selectBouquet(id);
        widget.onBouquetSelected(id);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade700 : Colors.grey.shade800,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade600,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$count channels',
              style: TextStyle(color: Colors.grey.shade300, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
