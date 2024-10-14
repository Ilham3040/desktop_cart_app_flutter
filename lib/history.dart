import 'package:flutter/material.dart';
import 'model/database_helper.dart';
import 'package:intl/intl.dart'; // Import for date formatting
import 'package:intl/date_symbol_data_local.dart'; // Import for initializing locales

class HistoryPage extends StatefulWidget {
  final int projectId;
  final String projectName;

  const HistoryPage({
    Key? key,
    required this.projectId,
    required this.projectName,
  }) : super(key: key);

  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, dynamic>> checkoutHistory = [];
  final dbHelper = DatabaseHelper(); // DatabaseHelper instance

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null).then((_) {
      _loadCheckoutHistory(); // Load the history after locale initialization
    });
  }

  // Load checkout history from the database
  Future<void> _loadCheckoutHistory() async {
    List<Map<String, dynamic>> history =
        await dbHelper.getCheckoutHistoryByProject(widget.projectId);
    setState(() {
      checkoutHistory = history;
    });
  }

  // Function to format the ISO timestamp to a human-readable date in Indonesian
  String formatTimestamp(String isoTimestamp) {
    DateTime dateTime = DateTime.parse(isoTimestamp);
    return DateFormat('dd MMMM yyyy, HH:mm', 'id_ID')
        .format(dateTime); // e.g. "06 Oktober 2024, 00:55"
  }

  // Function to show a dialog with checkout items
  Future<void> _showCheckoutItems(int checkoutHistoryId) async {
    List<Map<String, dynamic>> checkoutItems =
        await dbHelper.getCheckoutItemsByHistory(checkoutHistoryId);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Detail Barang Checkout"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              itemCount: checkoutItems.length,
              itemBuilder: (context, index) {
                final item = checkoutItems[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    title: Text(item['item_name']),
                    subtitle: Text(
                      "Jumlah Barang: ${item['quantity']} - Harga: Rp ${NumberFormat('#,##0', 'id_ID').format(item['price'])}",
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Tutup"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Riwayat Checkout - ${widget.projectName}"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: checkoutHistory.isEmpty
            ? const Center(child: Text("Tidak ada riwayat checkout"))
            : ListView.builder(
                itemCount: checkoutHistory.length,
                itemBuilder: (context, index) {
                  final historyItem = checkoutHistory[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text(
                        "Total: Rp ${NumberFormat('#,##0', 'id_ID').format(historyItem['total_amount'])}",
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        "Tanggal: ${formatTimestamp(historyItem['checkout_date'])}",
                        style: const TextStyle(color: Colors.grey),
                      ),
                      onTap: () {
                        _showCheckoutItems(historyItem['id']);
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}
