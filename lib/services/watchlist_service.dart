import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WatchlistService {
  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  static Stream<bool> isSaved(String tenderId) {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('watchlist')
        .doc(tenderId);
    return ref.snapshots().map((d) => d.exists);
  }

  static Future<void> toggle(String tenderId) async {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('watchlist')
        .doc(tenderId);
    final snap = await ref.get();
    if (snap.exists) {
      await ref.delete();
    } else {
      await ref.set({'createdAt': FieldValue.serverTimestamp()});
    }
  }
}
