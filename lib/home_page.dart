import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class Tender {
  final String title;
  final String details;
  final DateTime startDate;
  final DateTime endDate;

  Tender({
    required this.title,
    required this.details,
    required this.startDate,
    required this.endDate,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Tender> tenders = [
    Tender(
      title: "Road Construction Project",
      details: "Dhaka City road repair project for 2025.",
      startDate: DateTime(2025, 9, 20),
      endDate: DateTime(2025, 10, 10),
    ),
    Tender(
      title: "School Building Renovation",
      details: "Renovation of 10 government schools.",
      startDate: DateTime(2025, 9, 15),
      endDate: DateTime(2025, 10, 5),
    ),
  ];

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, "/login");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Open Tenders"),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: tenders.length,
        itemBuilder: (context, index) {
          final tender = tenders[index];
          return Card(
            margin: const EdgeInsets.all(10),
            child: ListTile(
              title: Text(
                tender.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                "Start: ${tender.startDate.toString().split(' ')[0]} | "
                "End: ${tender.endDate.toString().split(' ')[0]}",
              ),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => BidPage(tender: tender)),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// 🔹 Bid Page
class BidPage extends StatefulWidget {
  final Tender tender;

  const BidPage({super.key, required this.tender});

  @override
  State<BidPage> createState() => _BidPageState();
}

class _BidPageState extends State<BidPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  void _submitBid() {
    if (_formKey.currentState!.validate()) {
      String amount = _amountController.text;
      String note = _noteController.text;

      // এখানে তুমি Firestore / API তে ডেটা পাঠাতে পারবে
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Bid submitted for ${widget.tender.title}\nAmount: $amount\nNote: $note",
          ),
        ),
      );

      Navigator.pop(context); // হোমপেজে ফেরত যাবে
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Bid on ${widget.tender.title}")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.tender.details, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Bid Amount (৳)",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value!.isEmpty ? "Enter your bid amount" : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Additional Note",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _submitBid,
                  icon: const Icon(Icons.send),
                  label: const Text("Submit Bid"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
