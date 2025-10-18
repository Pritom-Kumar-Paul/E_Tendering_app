import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'admin_tender_form_page.dart';
import 'admin_tender_bids_page.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final tenders = FirebaseFirestore.instance
        .collection('tenders')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin • Tenders'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Logout?'),
                  content: const Text('Are you sure you want to log out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await FirebaseAuth.instance.signOut();
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Tender'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminTenderFormPage()),
          );
        },
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: tenders,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No tenders yet'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i];
              final data = d.data();
              final endAt = (data['endAt'] as Timestamp?)?.toDate();
              final status = (data['status'] ?? 'open').toString();

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(data['title'] ?? ''),
                  subtitle: Text(
                    'Org: ${data['organization'] ?? '-'} • '
                    'End: ${endAt?.toLocal().toString().split(' ').first ?? '-'} • '
                    'Status: ${status.toUpperCase()}',
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'View Bids',
                        icon: const Icon(Icons.receipt_long),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AdminTenderBidsPage(tenderId: d.id),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        tooltip: 'Edit',
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AdminTenderFormPage(tenderId: d.id),
                            ),
                          );
                        },
                      ),
                      PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'close') {
                            await d.reference.update({
                              'status': 'closed',
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                          } else if (v == 'reopen') {
                            await d.reference.update({
                              'status': 'open',
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                          } else if (v == 'delete') {
                            await d.reference.delete();
                          }
                        },
                        itemBuilder: (ctx) => [
                          if (status != 'closed')
                            const PopupMenuItem(
                              value: 'close',
                              child: Text('Close Tender'),
                            ),
                          if (status == 'closed')
                            const PopupMenuItem(
                              value: 'reopen',
                              child: Text('Reopen Tender'),
                            ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete Tender'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
