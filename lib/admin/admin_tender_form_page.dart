import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class AdminTenderFormPage extends StatefulWidget {
  final String? tenderId;
  const AdminTenderFormPage({super.key, this.tenderId});

  @override
  State<AdminTenderFormPage> createState() => _AdminTenderFormPageState();
}

class _AdminTenderFormPageState extends State<AdminTenderFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _org = TextEditingController();
  final _details = TextEditingController();
  DateTime? _endAt;
  List<PlatformFile> _newFiles = [];
  List<String> _docUrls = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.tenderId != null) {
      _load();
    }
  }

  Future<void> _load() async {
    final d = await FirebaseFirestore.instance
        .collection('tenders')
        .doc(widget.tenderId)
        .get();
    final data = d.data();
    if (data != null) {
      _title.text = data['title'] ?? '';
      _org.text = data['organization'] ?? '';
      _details.text = data['details'] ?? '';
      _endAt = (data['endAt'] as Timestamp?)?.toDate();
      _docUrls = List<String>.from(data['docUrls'] ?? []);
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _pickDocs() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );
    if (res != null) {
      setState(() => _newFiles = res.files);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _endAt == null) {
      if (_endAt == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Select end date')));
      }
      return;
    }

    setState(() => _saving = true);
    try {
      final tenders = FirebaseFirestore.instance.collection('tenders');
      final docRef = widget.tenderId == null
          ? tenders.doc()
          : tenders.doc(widget.tenderId);
      final isNew = widget.tenderId == null;

      // 1) Save base doc first (no file upload yet)
      final baseData = <String, dynamic>{
        'title': _title.text.trim(),
        'organization': _org.text.trim(),
        'details': _details.text.trim(),
        'endAt': Timestamp.fromDate(_endAt!),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (isNew) {
        await docRef.set({
          ...baseData,
          'status': 'open',
          'docUrls': [],
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await docRef.set(baseData, SetOptions(merge: true));
      }

      // 2) Upload attachments (if any), but don't block creation if upload fails
      final storage = FirebaseStorage.instance;
      final newUrls = <String>[];
      for (final f in _newFiles) {
        try {
          if (f.bytes == null) continue;
          final path = 'tenders/${docRef.id}/docs/${f.name}';
          final task = await storage
              .ref(path)
              .putData(
                f.bytes!,
                SettableMetadata(contentType: 'application/octet-stream'),
              );
          final url = await task.ref.getDownloadURL();
          newUrls.add(url);
        } catch (e) {
          debugPrint('File upload failed: $e');
        }
      }

      // 3) Merge existing + new urls, update doc
      final allUrls = [..._docUrls, ...newUrls];
      await docRef.update({'docUrls': allUrls});

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _org.dispose();
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tenderId == null ? 'Add Tender' : 'Edit Tender'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _org,
              decoration: const InputDecoration(
                labelText: 'Organization',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _details,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Details',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _endAt == null
                    ? 'End date not set'
                    : 'Ends: ${_endAt!.toLocal().toString().split(".").first}',
              ),
              trailing: ElevatedButton.icon(
                icon: const Icon(Icons.date_range),
                label: const Text('Pick End'),
                onPressed: () async {
                  final now = DateTime.now();
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _endAt ?? now,
                    firstDate: now,
                    lastDate: DateTime(now.year + 5),
                  );
                  if (d == null) return;
                  final t = await showTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 17, minute: 0),
                  );
                  setState(() {
                    _endAt = DateTime(
                      d.year,
                      d.month,
                      d.day,
                      t?.hour ?? 17,
                      t?.minute ?? 0,
                    );
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _pickDocs,
              icon: const Icon(Icons.attach_file),
              label: Text('Attach Documents (${_newFiles.length} new)'),
            ),
            const SizedBox(height: 8),
            if (_docUrls.isNotEmpty) ...[
              const Text('Existing documents:'),
              const SizedBox(height: 4),
              ..._docUrls.map((u) => Text('• ${u.split('/').last}')),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save),
                label: Text(_saving ? 'Saving...' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
