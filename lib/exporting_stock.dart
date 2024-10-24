import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'model/database_helper.dart';
import 'package:intl/intl.dart'; // Import for date formatting
import 'providers/projectinfo_provider.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'dart:io';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as excel;
import 'package:file_picker/file_picker.dart';

class ExportingStock extends ConsumerStatefulWidget {
  final DateTime? selectedDate1Export;
  final DateTime? selectedDate2Export;

  const ExportingStock(
      {super.key, this.selectedDate1Export, this.selectedDate2Export});

  @override
  ExportingStockState createState() => ExportingStockState();
}

class ExportingStockState extends ConsumerState<ExportingStock> {
  final DatabaseHelper dbHelper = DatabaseHelper();
  DateTime? selectedDate1Export;
  DateTime? selectedDate2Export;
  String? errorMessage; // Variable to hold error message

  @override
  void initState() {
    super.initState();
    selectedDate1Export = widget.selectedDate1Export;
    selectedDate2Export = widget.selectedDate2Export;
  }

  bool checkDateRange(BuildContext context) {
    if (selectedDate1Export != null &&
        selectedDate2Export != null &&
        selectedDate1Export!.isAfter(selectedDate2Export!)) {
      setState(() {
        errorMessage =
            'Terjadi kesalahan pada penginputan range tanggal'; // Set error message
      });
      return false; // Return false if the date range is invalid
    }
    setState(() {
      errorMessage = null; // Clear error message if valid
    });
    return true; // Return true if the date range is valid
  }

  Future<void> _showDatePickerDialog(
      BuildContext context, int datePickerNumber) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        List<DateTime?> tempSelectedDates = [];

        return AlertDialog(
          title: const Text('Pilih Tanggal'),
          content: SizedBox(
            width: double.maxFinite,
            child: CalendarDatePicker2(
              config: CalendarDatePicker2Config(
                firstDate: DateTime(2000, 1, 1),
                lastDate: DateTime(2100, 12, 30),
              ),
              value: tempSelectedDates,
              onValueChanged: (dates) {
                tempSelectedDates = dates; // Update temporary selected dates
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (tempSelectedDates.isNotEmpty) {
                  setState(() {
                    if (datePickerNumber == 1) {
                      DateTime? prevDate1 = selectedDate1Export;
                      selectedDate1Export = tempSelectedDates.last;
                      if (!checkDateRange(context)) {
                        selectedDate1Export =
                            prevDate1; // Revert to previous date
                      }
                    } else if (datePickerNumber == 2) {
                      DateTime? prevDate2 = selectedDate2Export;
                      selectedDate2Export = tempSelectedDates.last;
                      if (!checkDateRange(context)) {
                        selectedDate2Export =
                            prevDate2; // Revert to previous date
                      }
                    }
                    // _loadHistoryByRangeDate(); // Call this method if necessary
                  });
                }
                Navigator.of(context).pop(tempSelectedDates);
              },
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Batal'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Format the selected dates
    String formattedDate1 = selectedDate1Export != null
        ? DateFormat('dd MMMM yyyy').format(selectedDate1Export!)
        : 'Pilih Range Awal';

    String formattedDate2 = selectedDate2Export != null
        ? DateFormat('dd MMMM yyyy').format(selectedDate2Export!)
        : 'Pilih Range Akhir';

    return AlertDialog(
      title: const Text('Pilih Range Data Export'),
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Make the column take minimal space
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    _showDatePickerDialog(context, 1);
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: Colors.blue[900] ?? Colors.blue),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Mulai: $formattedDate1',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () {
                    _showDatePickerDialog(context, 2);
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: Colors.blue[900] ?? Colors.blue),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Sampai: $formattedDate2',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (errorMessage != null)
              Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Konfirmasi'),
          onPressed: () async {
            final projectId = ref.read(projectInfoProvider)!.id;
            final List<Map<String, dynamic>> stockData =
                List<Map<String, dynamic>>.from(
                    await dbHelper.getSummedStockRecordsByProjectInRange(
                        projectId, selectedDate1Export!, selectedDate2Export!));

            if (stockData.isEmpty) {
              return; // You may also show a message indicating no data
            }

            stockData.sort((a, b) {
              DateTime dateA = DateFormat('yyyy-MM-dd').parse(a['added_at']);
              DateTime dateB = DateFormat('yyyy-MM-dd').parse(b['added_at']);
              return dateA.compareTo(dateB);
            });

            final excel.Workbook workbook = excel.Workbook();
            final excel.Worksheet sheet =
                workbook.worksheets.addWithName('Stock Data');

            List<String> headers = [
              'No',
              'Nama Barang',
              'Ditambahkan Pada',
              'Stok Ditambahkan',
              'Harga Restock',
              'Total Harga'
            ];
            for (var j = 0; j < headers.length; j++) {
              final cell = sheet.getRangeByIndex(1, j + 1);
              cell.setText(headers[j]);
              cell.cellStyle.bold = true;
              cell.cellStyle.hAlign = excel.HAlignType.center;
              cell.cellStyle.borders.all.lineStyle = excel.LineStyle.thin;
            }

            double totalSum = 0;

            for (var i = 0; i < stockData.length; i++) {
              var item = stockData[i];

              double restockPrice = (item['cost_price'] != null)
                  ? (item['cost_price'] is int)
                      ? (item['cost_price'] as int).toDouble()
                      : item['cost_price'] as double
                  : 0.0;

              double addedStock = (item['stock_added'] != null)
                  ? (item['stock_added'] is int)
                      ? (item['stock_added'] as int).toDouble()
                      : item['stock_added'] as double
                  : 0.0;

              double totalPrice = addedStock * restockPrice;
              totalSum += totalPrice;

              List<dynamic> row = [
                (i + 1),
                item['item_name'] ?? 'Unknown Item',
                item['added_at'] ?? 'Unknown Date',
                addedStock,
                restockPrice,
                totalPrice
              ];

              for (var j = 0; j < row.length; j++) {
                final cell = sheet.getRangeByIndex(i + 2, j + 1);
                var value = row[j];
                if (j == 0 || j == 3 || j == 5) {
                  double numberValue = value != null ? value.toDouble() : 0.0;
                  cell.setNumber(numberValue);
                  cell.numberFormat = '#,##0';
                } else if (j == 4) {
                  double priceValue = value;
                  cell.setNumber(priceValue);
                  cell.numberFormat =
                      priceValue == priceValue.toInt() ? '#' : '#,##0.00';
                } else {
                  cell.setText(value.toString());
                }

                cell.cellStyle.hAlign = excel.HAlignType.center;
                cell.cellStyle.borders.all.lineStyle = excel.LineStyle.thin;
              }
            }

            final int totalRowIndex = stockData.length + 2;
            final totalCell = sheet.getRangeByIndex(totalRowIndex, 5);
            totalCell.setText('Total');
            totalCell.cellStyle.bold = true;
            totalCell.cellStyle.hAlign = excel.HAlignType.center;
            totalCell.cellStyle.borders.all.lineStyle = excel.LineStyle.thin;

            final totalValueCell = sheet.getRangeByIndex(totalRowIndex, 6);
            totalValueCell.setNumber(totalSum);
            totalValueCell.numberFormat = '#,##0';
            totalValueCell.cellStyle.borders.all.lineStyle =
                excel.LineStyle.thin;

            String? outputFilePath = await FilePicker.platform.saveFile(
              dialogTitle: 'Save Excel File',
              fileName: 'stock_data.xlsx',
              type: FileType.custom,
              allowedExtensions: ['xlsx'],
            );

            if (outputFilePath != null) {
              if (!outputFilePath.endsWith('.xlsx')) {
                outputFilePath += '.xlsx';
              }

              final List<int> bytes = workbook.saveAsStream();
              File(outputFilePath)
                ..createSync(recursive: true)
                ..writeAsBytesSync(bytes);
            } else {
              // Handle the case where the user cancels the save dialog
              // You might want to show a message or simply return
            }

            if (context.mounted) Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: const Text('Batal'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

void selectingRangeForExportedStock(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return const ExportingStock();
    },
  );
}
