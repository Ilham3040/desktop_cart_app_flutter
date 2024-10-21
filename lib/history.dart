import 'package:cart_app/exporting_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'model/database_helper.dart';
import 'package:intl/intl.dart'; // Import for date formatting
import 'package:intl/date_symbol_data_local.dart';
import 'providers/projectinfo_provider.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  List<Map<String, dynamic>> checkoutHistory = [];
  final dbHelper = DatabaseHelper(); // DatabaseHelper instance
  DateTime? selectedDate1; // First date variable
  DateTime? selectedDate2; // Second date variable
  DateTime? prevDate1;
  DateTime? prevDate2;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null).then((_) {
      _loadCheckoutHistory(); // Load the history after locale initialization
    });
  }

  // Load checkout history from the database
  Future<void> _loadCheckoutHistory() async {
    final projectInfo = ref.read(projectInfoProvider)!;
    List<Map<String, dynamic>> history =
        await dbHelper.getCheckoutHistoryByProject(projectInfo.id);
    setState(() {
      checkoutHistory = history;
    });
  }

  Future<void> _loadHistoryByRangeDate() async {
    if (selectedDate1 != null && selectedDate2 != null) {
      final projectInfo = ref.read(projectInfoProvider)!;
      // Fetch stock records with item names directly from the database
      List<Map<String, dynamic>> history =
          await dbHelper.getCheckoutHistoryByProjectAndDateRange(
              projectInfo.id, selectedDate1!, selectedDate2!);

      setState(() {
        checkoutHistory = history;
      });
    }
  }

  bool checkDateRange(BuildContext context) {
    if (selectedDate1 != null &&
        selectedDate2 != null &&
        selectedDate1!.isAfter(selectedDate2!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terjadi kesalahan pada penginputan range tanggal'),
          backgroundColor: Colors.black,
          duration: Duration(seconds: 3),
        ),
      );
      return false; // Return false if the date range is invalid
    }
    return true; // Return true if the date range is valid
  }

  Future<void> _showDatePickerDialog(
      BuildContext context, int dateField) async {
    List<DateTime?>? selectedDates = await showDialog<List<DateTime?>>(
      context: context,
      builder: (BuildContext context) {
        List<DateTime?> _tempSelectedDates = [];

        return AlertDialog(
          title: Text('Select Date'),
          content: SizedBox(
            width: double.maxFinite,
            child: CalendarDatePicker2(
              config: CalendarDatePicker2Config(
                firstDate: DateTime(2000, 1, 1),
                lastDate: DateTime(2100, 12, 30),
              ),
              value: _tempSelectedDates,
              onValueChanged: (dates) {
                _tempSelectedDates = dates; // Update temporary selected dates
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (_tempSelectedDates.isNotEmpty) {
                  setState(() {
                    if (dateField == 1) {
                      prevDate1 = selectedDate1;
                      selectedDate1 = _tempSelectedDates.last;
                      bool goodRange = checkDateRange(context);
                      if (!goodRange) {
                        selectedDate1 = prevDate1;
                      }
                      _loadHistoryByRangeDate();
                    } else if (dateField == 2) {
                      prevDate2 = selectedDate2;
                      selectedDate2 = _tempSelectedDates.last;
                      bool goodRange = checkDateRange(context);
                      if (!goodRange) {
                        selectedDate2 = prevDate2;
                      }
                      _loadHistoryByRangeDate();
                    }
                  });
                }
                Navigator.of(context).pop(_tempSelectedDates);
              },
              child: Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // Function to format the ISO timestamp to a human-readable date in Indonesian
  String formatTimestamp(String isoTimestamp) {
    DateTime dateTime = DateTime.parse(isoTimestamp);
    return DateFormat('dd MMMM yyyy', 'id_ID')
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
    final projectInfo = ref.read(projectInfoProvider)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Riwayat Checkout - ${projectInfo.name}",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // First date picker
                GestureDetector(
                  onTap: () {
                    _showDatePickerDialog(context, 1);
                  }, // Assign date to selectedDate1
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: Colors.blue[900] ?? Colors.blue),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      selectedDate1 != null
                          ? 'Mulai: ${selectedDate1!.toLocal().toString().split(' ')[0]}'
                          : 'Pilih Range Awal',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                SizedBox(width: 16), // Space between the two containers

                // Second date picker
                GestureDetector(
                  onTap: () {
                    _showDatePickerDialog(context, 2);
                  }, // Assign date to selectedDate2
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: Colors.blue[900] ?? Colors.blue),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      selectedDate2 != null
                          ? 'Sampai: ${selectedDate2!.toLocal().toString().split(' ')[0]}'
                          : 'Pilih Range Akhir',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),

                SizedBox(width: 16),
                ElevatedButton(
                  style: ButtonStyle(
                    foregroundColor: WidgetStatePropertyAll(Colors.white),
                    backgroundColor:
                        WidgetStatePropertyAll(Colors.blue[900] ?? Colors.blue),
                    shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  onPressed: () {
                    selectingRangeForExportedData(context);
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(
                      "Export Data",
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
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
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
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
          ),
        ],
      ),
    );
  }
}
