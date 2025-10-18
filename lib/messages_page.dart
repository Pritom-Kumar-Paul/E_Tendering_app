import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MessagesPage extends StatelessWidget {
  final String tenderId;
  const MessagesPage({super.key, required this.tenderId});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final msgs = FirebaseFirestore.instance
        .collection('tenders')
        .doc(tenderId)
        .collection('threads')
        .doc(uid)
        .collection('messages')
        .orderBy('createdAt');

    final ctrl = TextEditingController();

    Future<void> send() async {
      final text = ctrl.text.trim();
      if (text.isEmpty) {
        return;
      }
      ctrl.clear();
      final ref = FirebaseFirestore.instance
          .collection('tenders')
          .doc(tenderId)
          .collection('threads')
          .doc(uid)
          .collection('messages');
      await ref.add({
        'senderId': uid,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Help & Queries')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: msgs.snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: snap.data!.docs.map((m) {
                    final mine = m['senderId'] == uid;
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: mine
                              ? Colors.blue.shade50
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(m['text'] ?? ''),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: TextField(
                      controller: ctrl,
                      decoration: const InputDecoration(
                        hintText: 'Type your message...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => send(),
                    ),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send), onPressed: send),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
