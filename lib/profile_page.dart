import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _name = TextEditingController();
  final _company = TextEditingController();
  String? _licenseUrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final d = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final data = d.data() ?? {};
    _name.text = data['displayName'] ?? '';
    _company.text = data['companyName'] ?? '';
    _licenseUrl = data['tradeLicense'];
    setState(() {});
  }

  Future<void> _uploadLicense() async {
    final res = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png'],
    );
    if (res == null) return;
    setState(() => _loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final f = res.files.first;
      if (f.bytes == null) return;
      final task = await FirebaseStorage.instance
          .ref('kyc/$uid/${f.name}')
          .putData(
            f.bytes!,
            SettableMetadata(contentType: 'application/octet-stream'),
          );
      final url = await task.ref.getDownloadURL();
      setState(() => _licenseUrl = url);
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'tradeLicense': url,
        'kycStatus': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'displayName': _name.text.trim(),
      'companyName': _company.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile updated')));
  }

  @override
  void dispose() {
    _name.dispose();
    _company.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & KYC')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Email: $email'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Full name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _company,
            decoration: const InputDecoration(
              labelText: 'Company name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _licenseUrl == null
                      ? 'No license uploaded'
                      : 'License uploaded',
                ),
              ),
              TextButton(
                onPressed: _loading ? null : _uploadLicense,
                child: const Text('Upload License'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loading ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
