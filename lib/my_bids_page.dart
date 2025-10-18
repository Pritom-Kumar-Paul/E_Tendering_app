import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'tender_details_page.dart';

class MyBidsPage extends StatelessWidget {
  const MyBidsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final bids = FirebaseFirestore.instance
        .collectionGroup('bids')
        .where('bidderId', isEqualTo: uid)
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('My Bids')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: bids.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No bids yet'));
          }
          return ListView(
            children: docs.map((d) {
              final status = d['status'] ?? 'submitted';
              final path = d.reference.path; // tenders/{tid}/bids/{uid}
              final tid = path.split('/')[1];
              final receipt = d['receiptUrl'] as String?;
              return ListTile(
                title: Text('Tender: $tid'),
                subtitle: Text('Status: $status'),
                trailing: receipt != null
                    ? IconButton(
                        icon: const Icon(Icons.receipt_long),
                        onPressed: () async {
                          final uri = Uri.parse(receipt);
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        },
                      )
                    : null,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TenderDetailsPage(tenderId: tid),
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
