import 'package:cart_app/exporting_stock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'model/database_helper.dart';
import 'package:intl/intl.dart'; // Import for date formatting
import 'package:intl/date_symbol_data_local.dart';
import 'providers/projectinfo_provider.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';

class StockRecordsPage extends ConsumerStatefulWidget {
  const StockRecordsPage({super.key});

  @override
  _StockRecordsPageState createState() => _StockRecordsPageState();
}

class _StockRecordsPageState extends ConsumerState<StockRecordsPage> {
  List<Map<String, dynamic>> stockRecords = [];
  final dbHelper = DatabaseHelper(); // DatabaseHelper instance
  DateTime? selectedDate1; // First date variable
  DateTime? selectedDate2; // Second date variable
  DateTime? prevDate1;
  DateTime? prevDate2;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null).then((_) {
      _loadStockRecords(); // Load the stock records after locale initialization
    });
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

  // Function to show date picker and assign the selected date to a variable
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
                      _loadStockByRangeDate();
                    } else if (dateField == 2) {
                      prevDate2 = selectedDate2;
                      selectedDate2 = _tempSelectedDates.last;
                      bool goodRange = checkDateRange(context);
                      if (!goodRange) {
                        selectedDate2 = prevDate2;
                      }
                      _loadStockByRangeDate();
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

  // Load stock records from the database
  Future<void> _loadStockRecords() async {
    final projectInfo = ref.read(projectInfoProvider)!;
    // Fetch stock records with item names directly from the database
    List<Map<String, dynamic>> records =
        await dbHelper.getStockRecordsByProjectId(projectInfo.id);

    setState(() {
      stockRecords =
          records; // Set stock records directly from the query result
    });
  }

  Future<void> _loadStockByRangeDate() async {
    if (selectedDate1 != null && selectedDate2 != null) {
      final projectInfo = ref.read(projectInfoProvider)!;
      // Fetch stock records with item names directly from the database
      List<Map<String, dynamic>> records =
          await dbHelper.getStockRecordsByProjectIdInRange(
              projectInfo.id, selectedDate1!, selectedDate2!);

      setState(() {
        stockRecords = records;
      });
    }
  }

  // Function to format the ISO timestamp to a human-readable date in Indonesian
  String formatTimestamp(String isoTimestamp) {
    DateTime dateTime = DateTime.parse(isoTimestamp);
    return DateFormat('dd MMMM yyyy', 'id_ID')
        .format(dateTime); // e.g. "06 Oktober 2024"
  }

  // Function to show a dialog with stock item details
  Future<void> _showStockItemDetails(int stockRecordId) async {
    // Get the stock record by ID
    final stockRecord =
        stockRecords.firstWhere((record) => record['id'] == stockRecordId);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Detail Stok"),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Item: ${stockRecord['item_name']}"),
                Text("Jumlah Sebelum: ${stockRecord['stock_before']}"),
                Text("Jumlah Ditambah: ${stockRecord['stock_added']}"),
                Text("Jumlah Setelah: ${stockRecord['stock_after']}"),
                Text(
                    "Harga Jual: Rp ${NumberFormat('#,##0', 'id_ID').format(stockRecord['sell_price'])}"),
                Text(
                    "Harga Modal: Rp ${NumberFormat('#,##0', 'id_ID').format(stockRecord['cost_price'])}"),
                Text(
                    "Tanggal Ditambahkan: ${formatTimestamp(stockRecord['added_at'])}"),
              ],
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
          "Riwayat Stok - ${projectInfo.name}",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.blue[900] ?? Colors.blue[900],
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
                    selectingRangeForExportedStock(context);
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(
                      "Export Data",
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                )
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: stockRecords.isEmpty
                  ? const Center(child: Text("Tidak ada catatan stok"))
                  : ListView.builder(
                      itemCount: stockRecords.length,
                      itemBuilder: (context, index) {
                        final record = stockRecords[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            title: Text(
                              "${record['item_name']} telah ditambahkan sejumlah: ${record['stock_after']}",
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              "Tanggal: ${formatTimestamp(record['added_at'])}", // Using added_at for display
                              style: const TextStyle(color: Colors.grey),
                            ),
                            onTap: () {
                              _showStockItemDetails(
                                  record['id']); // Pass the stock record ID
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
