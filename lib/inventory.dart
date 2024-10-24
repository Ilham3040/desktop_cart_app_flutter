import 'package:cart_app/stock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import './model/database_helper.dart'; // Ensure to import your DatabaseHelper
import 'package:intl/intl.dart';
import 'cart.dart';
import 'history.dart';
import 'providers/projectinfo_provider.dart';
import 'providers/inventory_provider.dart';
import 'package:excel/excel.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});

  @override
  InventoryPageState createState() => InventoryPageState();
}

class InventoryPageState extends ConsumerState<InventoryPage> {
  String selectedProductName = "Nama Produk: Pilih produk";
  String selectedProductPrice = "Harga: -";
  String selectedProductStock = "Jumlah Barang: -";
  int selectedProductId = 0;
  DatabaseHelper dbHelper = DatabaseHelper();
  TextEditingController searchController = TextEditingController();

  List<Map<String, dynamic>> filteredItems = [];
  List<List<dynamic>> _tableData = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(inventoryProvider.notifier).fetchInventory());
  }

  Future<void> insertOrUpdateProducts(
      String name, int price, int stock, int cost) async {
    final dbHelper = DatabaseHelper();
    var existingProduct = await dbHelper.getInventoryByName(name);

    if (existingProduct.isNotEmpty) {
      var product = existingProduct.first;
      int currentStock = product['stock_quantity'];
      await dbHelper.insertStockRecord(
          ref.read(projectInfoProvider)!.id,
          product['id'],
          currentStock,
          stock,
          currentStock + stock,
          price,
          cost);
      await dbHelper.updateProductStock(product['id'], currentStock + stock);
    } else {
      int productId = await dbHelper.insertInventoryItem(
          ref.read(projectInfoProvider)!.id,
          name, // Product name
          price.toDouble(), // Selling price
          stock // Initial stock quantity
          );

      // Insert into stock record for the new product
      await dbHelper.insertStockRecord(
          ref.read(projectInfoProvider)!.id,
          productId, // Newly inserted product ID
          0, // No previous stock
          stock, // Stock added
          stock, // Final stock
          price, // Selling price
          cost // Cost price
          );
    }
  }

  Future<void> insertOrUpdateProductsFromTable(
      List<Map<String, dynamic>> tableData) async {
    final dbHelper = DatabaseHelper();
    for (var productData in tableData) {
      // Convert string fields to int if necessary
      int hargaJual = int.tryParse(productData['Harga Jual'].toString()) ?? 0;
      int jumlahTersedia =
          int.tryParse(productData['Jumlah Tersedia'].toString()) ?? 0;
      int hargaAwal = int.tryParse(productData['Harga Awal'].toString()) ?? 0;

      // Check if the product already exists
      var existingProduct =
          await dbHelper.getInventoryByName(productData['Nama Barang']);

      if (existingProduct.isNotEmpty) {
        // Product exists, update stock
        var product = existingProduct.first;
        int currentStock = product['stock_quantity'];

        // Update stock and insert stock record
        await dbHelper.insertStockRecord(
            ref.read(projectInfoProvider)!.id,
            product['id'], // Use the actual product ID
            currentStock, // Stock before
            jumlahTersedia, // Stock added
            currentStock + jumlahTersedia, // Stock after
            hargaJual, // Selling price
            hargaAwal // Cost price
            );

        // Update the product stock
        await dbHelper.updateProductStock(
            product['id'], currentStock + jumlahTersedia);
      } else {
        // Product doesn't exist, insert new product
        int productId = await dbHelper.insertInventoryItem(
            ref.read(projectInfoProvider)!.id,
            productData['Nama Barang'], // Product name
            hargaJual.toDouble(), // Selling price
            jumlahTersedia // Initial stock quantity
            );

        // Insert into stock record for the new product
        await dbHelper.insertStockRecord(
            ref.read(projectInfoProvider)!.id,
            productId, // Newly inserted product ID
            0, // No previous stock
            jumlahTersedia, // Stock added
            jumlahTersedia, // Final stock
            hargaJual, // Selling price
            hargaAwal // Cost price
            );
      }
    }
  }

  dynamic _convertToAppropriateType(dynamic cellValue) {
    // If the value is already a string or int, return it directly
    if (cellValue is String || cellValue is int || cellValue is double) {
      return cellValue;
    }

    // If the value is of another type (e.g., TextCellValue), convert it to String
    return cellValue.toString(); // Convert unknown types to string for safety
  }

  // Function to show the table in a popup
  void showTableDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
              'Data Tabel Excel'), // "Excel Table Data" in Indonesian
          content: SizedBox(
            width: double.maxFinite, // Allow table to take max width
            child: SingleChildScrollView(
              scrollDirection:
                  Axis.horizontal, // Horizontal scroll for wide tables
              child: SingleChildScrollView(
                scrollDirection:
                    Axis.vertical, // Vertical scroll for long tables
                child: DataTable(
                  columns: _tableData.isNotEmpty
                      ? _tableData[0]
                          .map((header) =>
                              DataColumn(label: Text(header.toString())))
                          .toList()
                      : [],
                  rows: _tableData.length > 1
                      ? _tableData
                          .skip(1)
                          .map(
                            (row) => DataRow(
                              cells: row
                                  .map(
                                    (cell) => DataCell(Text(cell.toString())),
                                  )
                                  .toList(),
                            ),
                          )
                          .toList()
                      : [],
                ),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'), // "Cancel" in Indonesian
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
            TextButton(
              child: const Text('Konfirmasi'), // "Confirm" in Indonesian
              onPressed: () async {
                // Ensure _tableData is available before proceeding
                if (_tableData.isNotEmpty) {
                  // Extract the header row (first index)
                  List<dynamic> headers = _tableData[0];

                  // Map each subsequent row to a dictionary using the headers as keys
                  List<Map<String, dynamic>> mappedData =
                      _tableData.skip(1).map((row) {
                    // Safely cast each value in the row to a proper type (e.g., String, int)
                    return Map<String, dynamic>.fromIterables(
                      headers.map((header) =>
                          header.toString()), // Ensure headers are strings
                      row.map((cellValue) => _convertToAppropriateType(
                          cellValue)), // Convert each cell value
                    );
                  }).toList();

                  // // Call the function to insert or update products from the table
                  await insertOrUpdateProductsFromTable(mappedData);
                  await ref.read(inventoryProvider.notifier).fetchInventory();
                  if (context.mounted) Navigator.of(context).pop();

                  // Provide feedback or perform other actions after confirmation
                } else {
                  // Handle the case where _tableData is empty
                  Navigator.pop(context);
                }
              },
            )
          ],
        );
      },
    );
  }

  Future<void> pickXlsxFile(BuildContext context) async {
    // Open file picker to select a file
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    // Check if a file was selected
    if (result != null) {
      String? filePath = result.files.single.path;

      // Validate the file extension
      if (filePath != null && filePath.endsWith('.xlsx')) {
        // Read the file bytes
        Uint8List bytes = await File(filePath).readAsBytes();

        // Read the Excel file
        var excel = Excel.decodeBytes(bytes);

        // Check if the widget is still mounted before showing the dialog
        if (!context.mounted) return; // Ensure the context is valid

        // Show the sheet selection dialog
        showSheetSelectionDialog(context, excel.tables.keys.toList(), excel);
      } else {
        // Print a message if the file format is incorrect
        // "Please input .xlsx format" in Indonesian
      }
    } else {
      // Print a message if no file was selected
      // "No file selected" in Indonesian
    }
  }

  void showSheetSelectionDialog(
      BuildContext context, List<String> sheetNames, Excel excel) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pilih Lembar'), // "Select a Sheet" in Indonesian
          content: SizedBox(
            width: double.maxFinite, // Define width
            height: 200, // Define height
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: sheetNames.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(sheetNames[index]),
                  onTap: () {
                    // Handle the sheet selection
                    // "Selected sheet" in Indonesian
                    Navigator.of(context).pop(); // Close the dialog

                    // Load the selected sheet data
                    var selectedSheet = excel.tables[sheetNames[index]];
                    if (selectedSheet != null) {
                      setState(() {
                        // Extract only cell values, not the cell details
                        _tableData = selectedSheet.rows.map((row) {
                          return row.map((cell) => cell?.value).toList();
                        }).toList();
                      });
                      // // Show the table in a new dialog
                      showTableDialog(context);
                    }
                  },
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'), // "Cancel" in Indonesian
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }

  void showAddProductDialog(BuildContext context) {
    // Use TextEditingControllers for each input field
    TextEditingController productNameController = TextEditingController();
    TextEditingController productPriceController = TextEditingController();
    TextEditingController productStockController = TextEditingController();
    TextEditingController productCostController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tambahkan Produk Baru'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: productNameController,
                decoration: const InputDecoration(labelText: 'Nama Produk'),
              ),
              TextField(
                controller: productPriceController,
                decoration: const InputDecoration(labelText: 'Harga Produk'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: productStockController,
                decoration: const InputDecoration(labelText: 'Jumlah Barang'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: productCostController,
                decoration: const InputDecoration(labelText: 'Harga Stock'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () async {
                // Get the values from the controllers
                String productName = productNameController.text;
                String productPrice = productPriceController.text;
                String productStock = productStockController.text;
                String productCost = productCostController.text;

                if (productName.isNotEmpty &&
                    productPrice.isNotEmpty &&
                    productStock.isNotEmpty) {
                  await insertOrUpdateProducts(
                      productName,
                      int.parse(productPrice),
                      int.parse(productStock),
                      int.parse(productCost));
                }

                ref.read(inventoryProvider.notifier).fetchInventory();
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Tambahkan'),
            ),
          ],
        );
      },
    );
  }

  void addingProductOption(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pilih Opsi Penambahan Product'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () async {
                  pickXlsxFile(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[900], // Button background color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20), // Rounded corners
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(
                      vertical: 12, horizontal: 20), // Padding around text
                  child: Text(
                    'Tambahkan Dari File',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),

              const SizedBox(height: 10), // Add spacing between the buttons
              ElevatedButton(
                onPressed: () {
                  showAddProductDialog(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[900], // Button background color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20), // Rounded corners
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(
                      vertical: 12, horizontal: 20), // Padding around text
                  child: Text(
                    'Tambahkan Secara Manual',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _searchItems(query) {
    final inventoryState = ref.watch(inventoryProvider);
    String searchQuery = query.toLowerCase();

    setState(() {
      filteredItems = inventoryState.items.where((item) {
        final itemName = item['item_name'].toString().toLowerCase();
        return itemName.contains(searchQuery);
      }).toList();
    });
  }

  void showEditProductDialog(BuildContext context, Map<String, dynamic> item) {
    TextEditingController productNameController =
        TextEditingController(text: item['item_name']);
    TextEditingController productPriceController =
        TextEditingController(text: item['price'].toString());
    TextEditingController productStockController =
        TextEditingController(text: item['stock_quantity'].toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Produk'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: productNameController,
                decoration: const InputDecoration(labelText: 'Nama Produk'),
              ),
              TextField(
                controller: productPriceController,
                decoration: const InputDecoration(labelText: 'Harga Produk'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: productStockController,
                decoration: const InputDecoration(labelText: 'Jumlah Barang'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () async {
                // Ensure fields are not empty
                if (productNameController.text.isNotEmpty &&
                    productPriceController.text.isNotEmpty &&
                    productStockController.text.isNotEmpty) {
                  // Update the product in the database
                  await ref
                      .read(inventoryProvider.notifier)
                      .updateInventoryItem(
                        item['id'], // Assuming 'id' is the item's identifier
                        productNameController.text,
                        double.parse(productPriceController.text),
                        int.parse(productStockController.text),
                      );

                  // Refetch the inventory after the edit
                  await ref.read(inventoryProvider.notifier).fetchInventory();

                  selectedProductName =
                      "Nama Produk: ${productNameController.text}";
                  selectedProductPrice =
                      "Harga: ${formatCurrency(double.parse(productPriceController.text))}";
                  selectedProductStock =
                      "Jumlah Barang: ${productStockController.text}";

                  if (context.mounted) Navigator.of(context).pop();
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void deleteProduct(int itemId) async {
    // Confirm deletion with the user
    bool? confirm = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Produk'),
          content: const Text('Apakah Anda yakin ingin menghapus produk ini?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      // Delete the item from the database
      await ref.read(inventoryProvider.notifier).deleteInventoryItem(itemId);

      // Refetch the inventory after the deletion
      await ref.read(inventoryProvider.notifier).fetchInventory();
      selectedProductName = "Nama Produk: Pilih produk";
      selectedProductPrice = "Harga: -";
      selectedProductStock = "Jumlah Barang: -";
    }
  }

  String _formatDate(String timestamp) {
    final DateTime dateTime = DateTime.parse(timestamp);
    return DateFormat('yyyy-MM-dd').format(dateTime);
  }

  void showProjectDetails(context) {
    final projectInfo = ref.watch(projectInfoProvider)!;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Detail Project"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  "Nama Project: ${projectInfo.name}"), // Replace with your project name variable
              Text(
                  "Tanggal Dibuat: ${_formatDate(projectInfo.dateCreated)}"), // Replace with your project creation date variable
            ],
          ),
          actions: <Widget>[
            TextButton(
              style: ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(Colors.blue[900]),
                  foregroundColor: const WidgetStatePropertyAll(Colors.white)),
              onPressed: () {
                // Function to open Edit dialog
                showEditDialog(context, projectInfo.id, projectInfo.name);
              },
              child: const Text("Edit"),
            ),
            TextButton(
              style: const ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(Colors.red),
                  foregroundColor: WidgetStatePropertyAll(Colors.white)),
              onPressed: () async {
                // Show confirmation dialog before deleting the project
                bool? confirmed = await showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text("Konfirmasi Penhapusan"),
                      content: const Text(
                          "Apakah Anda yakin ingin menghapus data ini"),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context)
                                .pop(false); // Dismiss and return false
                          },
                          child: const Text("Batal"),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context)
                                .pop(true); // Dismiss and return true
                          },
                          child: const Text("Hapus"),
                        ),
                      ],
                    );
                  },
                );

                // If user confirmed deletion, proceed with deleting the project
                if (confirmed == true) {
                  // Call your delete function
                  await deleteProject(projectInfo.id);

                  // Close the detail dialog
                  if (context.mounted) Navigator.of(context).pop();

                  // Navigate back to main.dart after deletion
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/', // Assuming the main page route is "/"
                      (Route<dynamic> route) => false,
                    );
                  }
                }
              },
              child: const Text("Hapus"),
            ),
          ],
        );
      },
    );
  }

  void showEditDialog(BuildContext context, int projectId, String currentName) {
    TextEditingController nameController =
        TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Edit Nama Data"),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: "Nama Data"),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                // Show confirmation dialog before saving
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text("Konfirmasi Perubahan"),
                      content: const Text(
                          "Apakah Anda yakin ingin menyimpan perubahan pada proyek ini?"),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () {
                            updateProjectName(projectId, nameController.text);
                            Navigator.of(context).pop(); // Close confirmation
                            Navigator.of(context).pop(); // Close edit dialog
                          },
                          child: const Text("Ya"),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context)
                                .pop(); // Close confirmation dialog
                          },
                          child: const Text("Tidak"),
                        ),
                      ],
                    );
                  },
                );
              },
              child: const Text("Simpan"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the edit dialog
              },
              child: const Text("Batal"),
            ),
          ],
        );
      },
    );
  }

  Future<void> updateProjectName(int projectId, String newName) async {
    dbHelper.updateProject(projectId, newName);
    final project = await dbHelper.getProjectById(projectId);
    ref.read(projectInfoProvider.notifier).state = ProjectInfo(
        id: project['id'],
        name: project['name'],
        dateCreated: project['created_at']);
  }

  Future<void> deleteProject(int projectId) async {
    dbHelper.deleteProject(projectId);
  }

  String formatCurrency(double value) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(value);
  }

  @override
  Widget build(BuildContext context) {
    final projectInfo = ref.watch(projectInfoProvider)!;
    final inventoryState = ref.watch(inventoryProvider);
    final itemsToDisplay =
        searchController.text.isEmpty ? inventoryState.items : filteredItems;

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        title: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Text(
            projectInfo.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
        ),
      ),
      body: Center(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CartPage(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text("Keranjang"),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HistoryPage(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text("Riwayat Penjualan"),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      showProjectDetails(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text("Detail Data"),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StockRecordsPage(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text("Riwayat Masuk Barang"),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(selectedProductName,
                                style: const TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Text(selectedProductPrice,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            Text(selectedProductStock,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w500)),
                            const Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ElevatedButton(
                                  onPressed: selectedProductName !=
                                          "Nama Produk: Pilih produk"
                                      ? () {
                                          // Assuming you have stored the selected product in a variable
                                          showEditProductDialog(context, {
                                            'id':
                                                selectedProductId, // Assuming you have stored the selectedProductId
                                            'item_name':
                                                selectedProductName.split(": ")[
                                                    1], // Extract product name
                                            'price': double.parse(
                                                selectedProductPrice
                                                    .split(": ")[1]
                                                    .replaceAll("Rp ", "")
                                                    .replaceAll(".", "")),
                                            'stock_quantity': int.parse(
                                                selectedProductStock
                                                    .split(": ")[1]),
                                          });
                                        }
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Edit'),
                                ),
                                ElevatedButton(
                                  onPressed: selectedProductName !=
                                          "Nama Produk: Pilih produk"
                                      ? () {
                                          // Assuming you have stored the selected product id in a variable
                                          deleteProduct(selectedProductId);
                                        }
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Hapus'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: searchController,
                              onChanged: _searchItems,
                              decoration: const InputDecoration(
                                hintText: "Pencarian Produk",
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              addingProductOption(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child: Row(
                                children: [
                                  Icon(Icons.add, size: 24),
                                  SizedBox(width: 8),
                                  Text('Tambahkan Produk'),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: inventoryState.isLoading
                                  ? const Center(
                                      child: Text(
                                        "Data Kosong",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: itemsToDisplay.length,
                                      itemBuilder: (context, index) {
                                        final item = itemsToDisplay[index];
                                        return ListTile(
                                          title: Text(
                                            item['item_name'],
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w500),
                                          ),
                                          subtitle: Text(
                                            "${formatCurrency(item['price'])} - Jumlah Barang: ${item['stock_quantity']}",
                                          ),
                                          onTap: () {
                                            setState(() {
                                              selectedProductName =
                                                  "Nama Produk: ${item['item_name']}";
                                              selectedProductPrice =
                                                  "Harga: ${formatCurrency(item['price'])}";
                                              selectedProductStock =
                                                  "Jumlah Barang: ${item['stock_quantity']}";
                                              selectedProductId = item['id'];
                                            });
                                          },
                                        );
                                      }, // Closing bracket for the itemBuilder
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
