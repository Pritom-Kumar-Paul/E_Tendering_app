import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'bid_page_firestore.dart';
import 'messages_page.dart';
import 'services/watchlist_service.dart';

class TenderDetailsPage extends StatelessWidget {
  final String tenderId;
  const TenderDetailsPage({super.key, required this.tenderId});

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('tenders').doc(tenderId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tender Details'),
        actions: [
          StreamBuilder<bool>(
            stream: WatchlistService.isSaved(tenderId),
            builder: (context, s) {
              final saved = s.data == true;
              return IconButton(
                tooltip: saved ? 'Saved' : 'Save to watchlist',
                icon: Icon(
                  saved ? Icons.bookmark : Icons.bookmark_add_outlined,
                ),
                onPressed: () => WatchlistService.toggle(tenderId),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData) {
            return const Center(child: Text('Loading...'));
          }
          if (!snap.data!.exists) {
            return const Center(child: Text('Tender not found'));
          }

          final data = snap.data!.data()!;
          final endAt = (data['endAt'] as Timestamp?)?.toDate();
          final docs = List<String>.from(data['docUrls'] ?? []);

          // Bidding eligibility
          final status = (data['status'] ?? 'open').toString();
          final now = DateTime.now();
          final canBid =
              status == 'open' && (endAt == null || endAt.isAfter(now));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                data['title'] ?? '',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(data['details'] ?? ''),
              const SizedBox(height: 8),
              Text("Organization: ${data['organization'] ?? '-'}"),
              Text("Ends: ${endAt != null ? endAt.toLocal().toString() : '-'}"),
              if (status != 'open') ...[
                const SizedBox(height: 4),
                Text(
                  'Status: ${status.toUpperCase()}',
                  style: TextStyle(
                    color: status == 'awarded' ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 16),

              const Text(
                "Documents",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (docs.isEmpty) const Text('No documents available'),
              for (final url in docs)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.picture_as_pdf),
                    title: Text(url.split('/').last),
                    onTap: () => _openUrl(url),
                  ),
                ),

              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.send),
                label: Text(canBid ? "Submit / Edit Bid" : "Bidding closed"),
                onPressed: canBid
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                BidPageFirestore(tenderId: tenderId),
                          ),
                        );
                      }
                    : null,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text("Help & Queries"),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MessagesPage(tenderId: tenderId),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
