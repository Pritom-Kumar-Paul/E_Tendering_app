import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

class BidPageFirestore extends StatefulWidget {
  final String tenderId;
  const BidPageFirestore({super.key, required this.tenderId});

  @override
  State<BidPageFirestore> createState() => _BidPageFirestoreState();
}

class _BidPageFirestoreState extends State<BidPageFirestore> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _sigController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
  );
  List<PlatformFile> _files = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _sigController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );
    if (res != null) setState(() => _files = res.files);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final bidRef = FirebaseFirestore.instance
          .collection('tenders')
          .doc(widget.tenderId)
          .collection('bids')
          .doc(uid); // one bid per user
      final storage = FirebaseStorage.instance;

      // Load existing bid (to preserve createdAt/files/signature if needed)
      final existingSnap = await bidRef.get();
      final existingData = existingSnap.data();
      final existingFiles = List<String>.from(existingData?['files'] ?? []);
      String? sigUrl = existingData?['signatureUrl'];

      // Upload attachments (new ones only)
      final uploaded = <String>[];
      for (final f in _files) {
        if (f.bytes == null) continue;
        final path = 'bids/${widget.tenderId}/$uid/${f.name}';
        final task = await storage
            .ref(path)
            .putData(
              f.bytes!,
              SettableMetadata(
                contentType: f.extension == 'pdf'
                    ? 'application/pdf'
                    : 'application/octet-stream',
              ),
            );
        uploaded.add(await task.ref.getDownloadURL());
      }

      // Upload signature as PNG (only if user drew something)
      final sigBytes = await _sigController.toPngBytes();
      if (sigBytes != null && sigBytes.isNotEmpty) {
        final task = await storage
            .ref('bids/${widget.tenderId}/$uid/signature.png')
            .putData(sigBytes, SettableMetadata(contentType: 'image/png'));
        sigUrl = await task.ref.getDownloadURL();
      }

      final allFiles = [...existingFiles, ...uploaded];

      final payload = <String, dynamic>{
        'bidderId': uid,
        'amount': double.tryParse(_amount.text.replaceAll(',', '').trim()),
        'note': _note.text.trim(),
        'files': allFiles,
        'signatureUrl': sigUrl,
        'status': 'submitted',
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (!existingSnap.exists) {
        payload['createdAt'] = FieldValue.serverTimestamp();
      }

      await bidRef.set(payload, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bid submitted')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _withdraw() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance
        .collection('tenders')
        .doc(widget.tenderId)
        .collection('bids')
        .doc(uid)
        .delete();
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final bidDoc = FirebaseFirestore.instance
        .collection('tenders')
        .doc(widget.tenderId)
        .collection('bids')
        .doc(uid);

    return Scaffold(
      appBar: AppBar(title: const Text("Submit Bid")),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: bidDoc.snapshots(),
        builder: (_, snap) {
          final existing = snap.data?.data();
          if (existing != null && _amount.text.isEmpty) {
            _amount.text = (existing['amount']?.toString() ?? '');
            _note.text = existing['note'] ?? '';
          }
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  TextFormField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: "Bid Amount (৳)",
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? "Enter amount" : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _note,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "Additional Note",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _pickFiles,
                    icon: const Icon(Icons.attach_file),
                    label: Text("Attachments (${_files.length})"),
                  ),
                  const SizedBox(height: 12),
                  const Text("Digital Signature"),
                  const SizedBox(height: 6),
                  Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Signature(
                      controller: _sigController,
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _sigController.clear,
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submit,
                          icon: const Icon(Icons.send),
                          label: const Text("Submit"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (existing != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _withdraw,
                            icon: const Icon(Icons.delete),
                            label: const Text("Withdraw"),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
