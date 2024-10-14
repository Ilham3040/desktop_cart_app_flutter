import 'package:flutter/material.dart';
import './model/database_helper.dart'; // Make sure to import your DatabaseHelper
import 'package:intl/intl.dart';
import 'cart.dart';
import 'history.dart';

class InventoryPage extends StatefulWidget {
  final int projectId;
  final String projectName;

  const InventoryPage({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  _InventoryPageState createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  String? editableProjectName;
  String selectedProductName = "Nama Produk: Pilih produk";
  String selectedProductPrice = "Harga: -";
  String selectedProductStock = "Jumlah Barang: -";
  TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> inventoryItems = [];
  DatabaseHelper dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    editableProjectName =
        widget.projectName; // Initialize with the project name
    fetchInventory();
  }

  void fetchProjectName() async {
    final project = await dbHelper.getProjectById(widget.projectId);
    setState(() {
      editableProjectName = project['name']; // Update the state variable
    });
  }

  void fetchInventory() async {
    inventoryItems = await dbHelper.getInventoryByProject(widget.projectId);
    setState(() {});
  }

  void _search(String query) async {
    final results = await DatabaseHelper().searchInventoryItems(query);
    setState(() {
      inventoryItems = results; // Update the displayed products
    });
  }

  void showAddProductDialog(BuildContext context) {
    String productName = "";
    String productPrice = "";
    String productStock = "";

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tambahkan Produk Baru'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Nama Produk'),
                onChanged: (value) {
                  productName = value;
                },
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Harga Produk'),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  productPrice = value;
                },
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Jumlah Barang'),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  productStock = value;
                },
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
                if (productName.isNotEmpty &&
                    productPrice.isNotEmpty &&
                    productStock.isNotEmpty) {
                  await dbHelper.insertInventoryItem(
                    widget.projectId,
                    productName,
                    double.parse(productPrice),
                    int.parse(productStock),
                  );
                  fetchInventory();
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Tambahkan'),
            ),
          ],
        );
      },
    );
  }

  void showEditProductDialog(BuildContext context, int itemId,
      String currentName, String currentPrice, String currentStock) {
    String productName = currentName;
    String productPrice = currentPrice;
    String productStock = currentStock;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Produk'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Nama Produk'),
                controller: TextEditingController(text: productName),
                onChanged: (value) {
                  productName = value;
                },
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Harga Produk'),
                controller: TextEditingController(text: productPrice),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  productPrice = value;
                },
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Jumlah Barang'),
                controller: TextEditingController(text: productStock),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  productStock = value;
                },
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
                await dbHelper.updateInventoryItem(
                  itemId,
                  productName,
                  double.parse(productPrice),
                  int.parse(productStock),
                );
                fetchInventory();
                Navigator.of(context).pop();
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void deleteProduct(int itemId) async {
    await dbHelper.deleteInventoryItem(itemId);
    fetchInventory();
  }

  void showProjectDetailDialog(BuildContext context, int projectId) async {
    // Fetch project details from the database
    final dbHelper = DatabaseHelper();
    final project = await dbHelper.getProjectById(projectId);

    String projectName = project['name'];
    String projectDateCreated = project['created_at'];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(projectName),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Tanggal Dibuat: $projectDateCreated"),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      // Show edit project name popup
                      showEditProjectDialog(context, projectId, projectName);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Edit'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      // Show confirmation dialog
                      final confirmDelete = await showDialog<bool>(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('Konfirmasi Hapus'),
                            content: const Text(
                                'Apakah Anda yakin ingin menghapus proyek ini?'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false), // Cancel
                                child: const Text('Batal'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true), // Confirm
                                child: const Text('Hapus'),
                              ),
                            ],
                          );
                        },
                      );

                      // Proceed with deletion if confirmed
                      if (confirmDelete == true) {
                        await dbHelper.deleteProject(projectId);
                        Navigator.of(context).pop(); // Close the dialog
                        Navigator.of(context)
                            .pop(); // Navigate back to the main page
                      }
                    },
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
        );
      },
    );
  }

// Function to show edit popup for the project name
  void showEditProjectDialog(
      BuildContext context, int projectId, String currentName) {
    String updatedProjectName = currentName;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Project Name'),
          content: TextField(
            controller: TextEditingController(text: currentName),
            decoration: const InputDecoration(labelText: 'Project Name'),
            onChanged: (value) {
              updatedProjectName = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () async {
                if (updatedProjectName.isNotEmpty) {
                  await dbHelper.updateProject(projectId, updatedProjectName);
                  fetchProjectName(); // Call the new function here
                  Navigator.of(context).pop(); // Close the edit popup
                  Navigator.of(context)
                      .pop(); // Close the project details dialog
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
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
    return Scaffold(
      backgroundColor: Colors.grey[300],
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Text(
            editableProjectName ?? widget.projectName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CartPage(
                          projectName: editableProjectName ??
                              widget.projectName, // Passing the project name
                          projectId: widget.projectId, // Passing the project ID
                        ),
                      ),
                    );

                    // Refetch the inventory once returning from the cart page
                    fetchInventory();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text("Keranjang"),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HistoryPage(
                          projectId: widget.projectId,
                          projectName:
                              editableProjectName ?? widget.projectName,
                        ),
                      ),
                    );

                    // Refetch inventory after returning from history
                    fetchInventory();
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
                    showProjectDetailDialog(context, widget.projectId);
                    fetchInventory();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text("Detail Project"),
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
                                onPressed: () {
                                  showEditProductDialog(
                                    context,
                                    1,
                                    selectedProductName.replaceAll(
                                        "Nama Produk: ", ""),
                                    selectedProductPrice
                                        .replaceAll("Harga: Rp ", "")
                                        .replaceAll('.', ''),
                                    selectedProductStock.replaceAll(
                                        "Jumlah Barang: ", ""),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Edit'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  deleteProduct(1);
                                },
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
                            controller: _searchController,
                            onChanged: _search,
                            decoration: const InputDecoration(
                              hintText: "Pencarian Produk",
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            showAddProductDialog(context);
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
                            child: ListView.builder(
                              itemCount: inventoryItems.length,
                              itemBuilder: (context, index) {
                                final item = inventoryItems[index];
                                return ListTile(
                                  title: Text(
                                    item['item_name'],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500),
                                  ),
                                  subtitle: Text(
                                      "${formatCurrency(item['price'])} - Jumlah Barang: ${item['stock_quantity']}"),
                                  onTap: () {
                                    setState(() {
                                      selectedProductName =
                                          "Nama Produk: ${item['item_name']}";
                                      selectedProductPrice =
                                          "Harga: ${formatCurrency(item['price'])}";
                                      selectedProductStock =
                                          "Jumlah Barang: ${item['stock_quantity']}";
                                    });
                                  },
                                );
                              },
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
    );
  }
}
