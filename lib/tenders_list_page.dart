import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'tender_details_page.dart';
import 'watchlist_page.dart';
import 'profile_page.dart';
import 'my_bids_page.dart';
import 'services/watchlist_service.dart';

class TendersListPage extends StatefulWidget {
  const TendersListPage({super.key});

  @override
  State<TendersListPage> createState() => _TendersListPageState();
}

class _TendersListPageState extends State<TendersListPage> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    // Avoid composite index for now: only orderBy, filter status on client
    final tendersRef = FirebaseFirestore.instance
        .collection('tenders')
        .orderBy('endAt'); // no where('status'...)

    return Scaffold(
      appBar: AppBar(
        title: const Text("Open Tenders"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final q = await showSearch<String>(
                context: context,
                delegate: TenderSearchDelegate(),
              );
              if (q != null) setState(() => _q = q);
            },
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'My Bids',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyBidsPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.bookmark),
            tooltip: 'Watchlist',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WatchlistPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: tendersRef.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            // Show the actual error (e.g., index required)
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText('Error: ${snap.error}'),
              ),
            );
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Text('No tenders found'));
          }

          // Client-side filter: show only status == open, and text query
          final docs = snap.data!.docs.where((d) {
            final status = (d['status'] ?? '').toString();
            if (status != 'open') return false;

            if (_q.isEmpty) return true;
            final t = (d['title'] ?? '').toString().toLowerCase();
            final det = (d['details'] ?? '').toString().toLowerCase();
            final q = _q.toLowerCase();
            return t.contains(q) || det.contains(q);
          }).toList();

          if (docs.isEmpty) {
            return const Center(child: Text('No tenders found'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              final endAt = (d['endAt'] as Timestamp?)?.toDate();
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(d['title'] ?? ''),
                  subtitle: Text(
                    "End: ${endAt?.toLocal().toString().split(' ').first ?? '-'} • ${d['organization'] ?? ''}",
                  ),
                  trailing: StreamBuilder<bool>(
                    stream: WatchlistService.isSaved(d.id),
                    builder: (ctx, s) {
                      final saved = s.data == true;
                      return IconButton(
                        icon: Icon(
                          saved ? Icons.bookmark : Icons.bookmark_add_outlined,
                        ),
                        onPressed: () => WatchlistService.toggle(d.id),
                      );
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TenderDetailsPage(tenderId: d.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class TenderSearchDelegate extends SearchDelegate<String> {
  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, ''),
  );

  @override
  Widget buildResults(BuildContext context) => Center(
    child: ElevatedButton(
      onPressed: () => close(context, query),
      child: Text('Search "$query"'),
    ),
  );

  @override
  Widget buildSuggestions(BuildContext context) => Container();
}
