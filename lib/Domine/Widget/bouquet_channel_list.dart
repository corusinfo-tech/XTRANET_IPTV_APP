import 'package:flutter/material.dart';
import '../../services/discovery_service.dart';

/// Bouquet Channel List Widget
/// Displays channels grouped under the selected bouquet
class BouquetChannelList extends StatefulWidget {
  final DiscoveryService discoveryService;
  final String selectedBouquetId;
  final Function(dynamic) onChannelSelected;

  const BouquetChannelList({
    Key? key,
    required this.discoveryService,
    required this.selectedBouquetId,
    required this.onChannelSelected,
  }) : super(key: key);

  @override
  State<BouquetChannelList> createState() => _BouquetChannelListState();
}

class _BouquetChannelListState extends State<BouquetChannelList> {
  @override
  Widget build(BuildContext context) {
    final channels = widget.discoveryService.getStreamsForBouquet(
      widget.selectedBouquetId,
    );

    if (channels.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No channels available for this bouquet',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        final channelName = channel["name"]?.toString() ?? "Unknown";
        final channelId = channel["id"]?.toString() ?? "";
        final logoUrl = channel["img"]?.toString();
        final lcn = channel["lcn"]?.toString() ?? "";

        return ListTile(
          leading:
              logoUrl != null
                  ? Image.network(
                    logoUrl,
                    width: 40,
                    height: 40,
                    errorBuilder:
                        (_, __, ___) =>
                            const Icon(Icons.tv, color: Colors.blue),
                  )
                  : const Icon(Icons.tv, color: Colors.blue),
          title: Text(
            channelName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white),
          ),
          subtitle:
              lcn.isNotEmpty
                  ? Text(
                    'LCN: $lcn',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  )
                  : null,
          onTap: () => widget.onChannelSelected(channel),
          tileColor: Colors.grey.shade900,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
        );
      },
    );
  }
}
