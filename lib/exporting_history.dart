import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'model/database_helper.dart';
import 'package:intl/intl.dart'; // Import for date formatting
import 'providers/projectinfo_provider.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'dart:io';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as excel;
import 'package:file_picker/file_picker.dart';

class ExportingHistory extends ConsumerStatefulWidget {
  final DateTime? selectedDate1Export;
  final DateTime? selectedDate2Export;

  const ExportingHistory(
      {super.key, this.selectedDate1Export, this.selectedDate2Export});

  @override
  ExportingHistoryState createState() => ExportingHistoryState();
}

class ExportingHistoryState extends ConsumerState<ExportingHistory> {
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
    showDialog<List<DateTime?>>(
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

            // Generate all dates in the range
            List<DateTime> allDates = [];
            DateTime currentDate = selectedDate1Export!;
            while (!currentDate.isAfter(selectedDate2Export!)) {
              allDates.add(currentDate);
              currentDate = currentDate.add(const Duration(days: 1));
            }

            // Get checkout data
            final List<Map<String, dynamic>> checkoutData =
                await dbHelper.getSummedCheckoutItemsByProjectInRange(
                    projectId, selectedDate1Export!, selectedDate2Export!);

            final List<Map<String, dynamic>> productsList =
                await dbHelper.getInventoryByProject(projectId);

            final excel.Workbook workbook = excel.Workbook();
            final excel.Worksheet sheet =
                workbook.worksheets.addWithName('Checkout Data');

            List<String> staticHeaders = ['No', 'Nama Barang', 'Harga Barang'];
            List<String> dynamicHeaders = [];

            // Prepare data mapping for easy access
            Map<String, List<Map<String, dynamic>>> groupedData = {};
            for (var entry in checkoutData) {
              String checkoutDate = entry['checkout_date'];
              if (!groupedData.containsKey(checkoutDate)) {
                groupedData[checkoutDate] = [];
              }
              groupedData[checkoutDate]!.add(entry);
            }

// Assuming allDates is a list of dates
            int dateCount = allDates.length; // Get the number of dates

            for (int i = 0; i < dateCount; i++) {
              dynamicHeaders.add('Jumlah Barang');
              dynamicHeaders.add('Total Harga');
            }

            dynamicHeaders.add('Jumlah Penjualan'); // Add total sales column

            // Merge static headers
            for (var i = 0; i < staticHeaders.length; i++) {
              final cell = sheet.getRangeByIndex(1, i + 1, 2, i + 1);
              cell.merge();
              cell.setText(staticHeaders[i]);
              cell.cellStyle.bold = true;
              cell.cellStyle.hAlign = excel.HAlignType.center;
              cell.cellStyle.vAlign = excel.VAlignType.center;
              cell.cellStyle.borders.all.lineStyle = excel.LineStyle.thin;
            }

            // Add dynamic headers with dates merged for "Jumlah Barang" and "Total Harga"
            int startColumn = staticHeaders.length + 1;

            for (var date in allDates) {
              final dateString =
                  date.toIso8601String().split('T').first; // Format date
              final dateCell =
                  sheet.getRangeByIndex(1, startColumn, 1, startColumn + 1);
              dateCell.merge();
              dateCell.setText(dateString);
              dateCell.cellStyle.bold = true;
              dateCell.cellStyle.hAlign = excel.HAlignType.center;
              dateCell.cellStyle.borders.all.lineStyle = excel.LineStyle.thin;

              final jumlahBarangCell = sheet.getRangeByIndex(2, startColumn);
              jumlahBarangCell.setText('Jumlah Barang');
              jumlahBarangCell.cellStyle.bold = true;
              jumlahBarangCell.cellStyle.hAlign = excel.HAlignType.center;
              jumlahBarangCell.cellStyle.borders.all.lineStyle =
                  excel.LineStyle.thin;

              final totalHargaCell = sheet.getRangeByIndex(2, startColumn + 1);
              totalHargaCell.setText('Total Harga');
              totalHargaCell.cellStyle.bold = true;
              totalHargaCell.cellStyle.hAlign = excel.HAlignType.center;
              totalHargaCell.cellStyle.borders.all.lineStyle =
                  excel.LineStyle.thin;

              startColumn +=
                  2; // Move to the next set of columns for the next date
            }

            // Add the "Jumlah Penjualan" header
            final sumHeaderCell = sheet.getRangeByIndex(2, startColumn);
            sumHeaderCell.setText('Jumlah Penjualan');
            sumHeaderCell.cellStyle.bold = true;
            sumHeaderCell.cellStyle.hAlign = excel.HAlignType.center;
            sumHeaderCell.cellStyle.borders.all.lineStyle =
                excel.LineStyle.thin;

            // Adding product rows (starting from row 3)
            // Adding product rows (starting from row 3)
            double totalJumlahPenjualan =
                0.0; // Initialize total sum for "Jumlah Penjualan"

            for (var i = 0; i < productsList.length; i++) {
              var product = productsList[i];
              String itemName = product['item_name'];
              double price =
                  product['price'] != null ? product['price'].toDouble() : 0.0;

              List<dynamic> row = [
                (i + 1), // No
                itemName, // Item Name
                price, // Price as double
              ];

              double totalSumForRow = 0.0;

              for (var date in allDates) {
                String dateString =
                    date.toIso8601String().split('T').first; // Format date

                // Check if there are sales data for this date
                var checkoutEntry = groupedData[dateString]?.firstWhere(
                  (item) => item['item_name'] == itemName,
                  orElse: () => {
                    'total_quantity': 0
                  }, // Return a map with total_quantity set to 0
                );

                // Use null-aware operator to safely access total_quantity
                double totalQuantity =
                    checkoutEntry?['total_quantity']?.toDouble() ?? 0.0;

                double totalValue = price * totalQuantity;

                row.add(totalQuantity); // Add quantity for the date
                row.add(totalValue); // Add total value for the date

                totalSumForRow +=
                    totalValue; // Add to the total sum for this row
              }
              // Add the total sum for this product to the end of the row
              row.add(totalSumForRow);
              totalJumlahPenjualan +=
                  totalSumForRow; // Accumulate the total for "Jumlah Penjualan"

              // Insert row into the sheet
              for (var j = 0; j < row.length; j++) {
                final cell = sheet.getRangeByIndex(
                    i + 3, j + 1); // Adjust index based on your layout
                var value = row[j];

                if (j == 0 || j >= 3) {
                  double numberValue = value != null ? value.toDouble() : 0.0;
                  cell.setNumber(numberValue);
                  cell.numberFormat = '0'; // Format as whole number
                } else if (j == 2) {
                  double priceValue = value;
                  cell.setNumber(priceValue);
                  cell.numberFormat = priceValue == priceValue.toInt()
                      ? '0'
                      : '0.00'; // Integer or 2 decimal places
                } else {
                  cell.setText(value.toString()); // For "Nama Barang"
                }

                cell.cellStyle.hAlign = excel.HAlignType.center;
                cell.cellStyle.borders.all.lineStyle = excel.LineStyle.thin;
              }
            }

            // Add the total sum for "Jumlah Penjualan" below the last product row
            final totalSumCell =
                sheet.getRangeByIndex(productsList.length + 3, startColumn - 1);
            totalSumCell.setText('Total');
            totalSumCell.cellStyle.bold = true;
            totalSumCell.cellStyle.hAlign = excel.HAlignType.center;
            totalSumCell.cellStyle.borders.all.lineStyle = excel.LineStyle.thin;

            // Insert the total sum value in the cell below the "Jumlah Penjualan" header
            final totalValueCell =
                sheet.getRangeByIndex(productsList.length + 3, startColumn);
            totalValueCell.setNumber(totalJumlahPenjualan);
            totalValueCell.cellStyle.hAlign = excel.HAlignType.center;
            totalValueCell.cellStyle.borders.all.lineStyle =
                excel.LineStyle.thin;

            // Saving the excel file
            String? outputFilePath = await FilePicker.platform.saveFile(
              dialogTitle: 'Save excel File',
              fileName: 'checkout_data.xlsx',
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

void selectingRangeForExportedData(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      // ignore: prefer_const_constructors
      return ExportingHistory();
    },
  );
}
