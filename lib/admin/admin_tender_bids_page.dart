import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminTenderBidsPage extends StatelessWidget {
  final String tenderId;
  const AdminTenderBidsPage({super.key, required this.tenderId});

  Future<void> _acceptBid(BuildContext context, String bidderUid) async {
    final fs = FirebaseFirestore.instance;
    final tenderRef = fs.collection('tenders').doc(tenderId);
    final bidsRef = tenderRef.collection('bids');

    final tender = await tenderRef.get();
    final status = (tender.data()?['status'] ?? 'open').toString();
    if (status == 'awarded') {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Already awarded')));
      return;
    }

    final allBids = await bidsRef.get();

    final batch = fs.batch();
    for (final b in allBids.docs) {
      final isWinner = b.id == bidderUid;
      batch.set(b.reference, {
        'status': isWinner ? 'accepted' : 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    final winning = allBids.docs.firstWhere((d) => d.id == bidderUid);
    batch.set(tenderRef, {
      'status': 'awarded',
      'awardedTo': bidderUid,
      'awardedBidId': bidderUid,
      'awardedAmount': winning.data()['amount'],
      'awardedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> _rejectBid(String bidderUid) async {
    final fs = FirebaseFirestore.instance;
    final ref = fs
        .collection('tenders')
        .doc(tenderId)
        .collection('bids')
        .doc(bidderUid);
    await ref.set({
      'status': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final bids = FirebaseFirestore.instance
        .collection('tenders')
        .doc(tenderId)
        .collection('bids')
        .orderBy('createdAt', descending: false)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Bids')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: bids,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No bids yet'));
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: docs.map((d) {
              final b = d.data();
              final status = (b['status'] ?? 'submitted').toString();
              final amount = b['amount']?.toString() ?? '-';
              final files = List<String>.from(b['files'] ?? []);
              final sig = b['signatureUrl'] as String?;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bidder: ${d.id}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text('Amount: $amount'),
                      const SizedBox(height: 4),
                      Text('Status: $status'),
                      const SizedBox(height: 8),
                      if (b['note'] != null &&
                          b['note'].toString().isNotEmpty) ...[
                        const Text('Note:'),
                        Text(b['note']),
                        const SizedBox(height: 8),
                      ],
                      const Text('Attachments:'),
                      if (files.isEmpty) const Text('- none -'),
                      ...files.map(
                        (u) => TextButton.icon(
                          onPressed: () => launchUrl(
                            Uri.parse(u),
                            mode: LaunchMode.externalApplication,
                          ),
                          icon: const Icon(Icons.open_in_new),
                          label: Text(u.split('/').last),
                        ),
                      ),
                      if (sig != null) ...[
                        const SizedBox(height: 8),
                        const Text('Signature:'),
                        const SizedBox(height: 4),
                        Image.network(sig, height: 120),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.check),
                            label: const Text('Accept'),
                            onPressed: status == 'accepted'
                                ? null
                                : () async {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('Accept this bid?'),
                                        content: const Text(
                                          'All other bids will be marked rejected and tender marked awarded.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Accept'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (!context.mounted) return;
                                    if (ok == true) {
                                      await _acceptBid(context, d.id);
                                    }
                                  },
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.close),
                            label: const Text('Reject'),
                            onPressed: status == 'rejected'
                                ? null
                                : () => _rejectBid(d.id),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
