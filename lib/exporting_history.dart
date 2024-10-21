import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'model/database_helper.dart';
import 'package:intl/intl.dart'; // Import for date formatting
import 'package:intl/date_symbol_data_local.dart';
import 'providers/projectinfo_provider.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';

class Exporting_History extends StatefulWidget {
  final DateTime? selectedDate1Export;
  final DateTime? selectedDate2Export;

  Exporting_History({this.selectedDate1Export, this.selectedDate2Export});

  @override
  _Exporting_HistoryState createState() => _Exporting_HistoryState();
}

class _Exporting_HistoryState extends State<Exporting_History> {
  DateTime? selectedDate1Export;
  DateTime? selectedDate2Export;

  @override
  void initState() {
    super.initState();
    selectedDate1Export = widget.selectedDate1Export;
    selectedDate2Export = widget.selectedDate2Export;
  }

  Future<void> _showDatePickerDialog(
      BuildContext context, int datePickerNumber) async {
    List<DateTime?>? selectedDates = await showDialog<List<DateTime?>>(
      context: context,
      builder: (BuildContext context) {
        List<DateTime?> _tempSelectedDates = [];

        return AlertDialog(
          title: Text('Pilih Tanggal'),
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
                    if (datePickerNumber == 1) {
                      selectedDate1Export = _tempSelectedDates.last;
                    } else {
                      selectedDate2Export = _tempSelectedDates.last;
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
              child: Text('Batal'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Pilih Range Data Export'),
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () {
                _showDatePickerDialog(context, 1);
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue[900] ?? Colors.blue),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  selectedDate1Export != null
                      ? 'Mulai: ${selectedDate1Export!.toLocal().toString().split(' ')[0]}'
                      : 'Pilih Range Awal',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            SizedBox(width: 16), // Space between the two containers

            // Second date picker
            GestureDetector(
              onTap: () {
                _showDatePickerDialog(context, 2);
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue[900] ?? Colors.blue),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  selectedDate2Export != null
                      ? 'Sampai: ${selectedDate2Export!.toLocal().toString().split(' ')[0]}'
                      : 'Pilih Range Akhir',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: Text('Konfirmasi'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: Text('Batal'),
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
      return Exporting_History();
    },
  );
}
