import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'tender_details_page.dart';

class WatchlistPage extends StatelessWidget {
  const WatchlistPage({super.key});

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchByIds(
    List<String> ids,
  ) async {
    final col = FirebaseFirestore.instance.collection('tenders');
    final result = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (int i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
      final snap = await col.where(FieldPath.documentId, whereIn: chunk).get();
      result.addAll(snap.docs);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Watchlist')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('watchlist')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final ids = snap.data!.docs.map((d) => d.id).toList();
          if (ids.isEmpty) {
            return const Center(child: Text('No saved tenders'));
          }
          return FutureBuilder<
            List<QueryDocumentSnapshot<Map<String, dynamic>>>
          >(
            future: _fetchByIds(ids),
            builder: (context, s2) {
              if (!s2.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = s2.data!;
              return ListView(
                children: docs.map((d) {
                  return ListTile(
                    title: Text(d['title'] ?? ''),
                    subtitle: Text(d['organization'] ?? ''),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TenderDetailsPage(tenderId: d.id),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          );
        },
      ),
    );
  }
}
