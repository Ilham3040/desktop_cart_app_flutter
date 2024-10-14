import 'package:flutter/material.dart';
import 'model/database_helper.dart';
import 'package:intl/intl.dart'; // Import intl package for date formatting

class CartPage extends StatefulWidget {
  final String projectName;
  final int projectId;

  const CartPage({
    Key? key,
    required this.projectName,
    required this.projectId,
  }) : super(key: key);

  @override
  _CartPageState createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  List<Map<String, dynamic>> inventoryItems = [];
  List<Map<String, dynamic>> cartItems = [];
  double totalAmount = 0.0;
  final dbHelper = DatabaseHelper();
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInventoryItems();
  }

  void _search(String query) async {
    final results = await DatabaseHelper().searchInventoryItems(query);
    setState(() {
      inventoryItems = results; // Update the displayed products
    });
  }

  Future<void> _loadInventoryItems() async {
    List<Map<String, dynamic>> items =
        await dbHelper.getInventoryByProject(widget.projectId);
    setState(() {
      inventoryItems = items;
    });
  }

  void _addToCart(Map<String, dynamic> item) {
    setState(() {
      int index =
          cartItems.indexWhere((cartItem) => cartItem['id'] == item['id']);
      if (index != -1) {
        cartItems[index]['quantity'] += 1;
        cartItems[index]['totalPrice'] += item['price'];
      } else {
        cartItems.add({
          'id': item['id'],
          'name': item['item_name'],
          'price': item['price'],
          'quantity': 1,
          'totalPrice': item['price'],
        });
      }
      totalAmount += item['price'];
    });
  }

  void _removeFromCart(Map<String, dynamic> item) {
    setState(() {
      int index =
          cartItems.indexWhere((cartItem) => cartItem['id'] == item['id']);
      if (index != -1 && cartItems[index]['quantity'] > 0) {
        cartItems[index]['quantity'] -= 1;
        cartItems[index]['totalPrice'] -= item['price'];
        totalAmount -= item['price'];

        if (cartItems[index]['quantity'] == 0) {
          cartItems.removeAt(index);
        }
      }
    });
  }

  // Checkout logic
  Future<void> _checkout() async {
    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Keranjang kosong, tidak bisa checkout')),
      );
      return;
    }

    // Show confirmation dialog before proceeding
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Konfirmasi Checkout'),
          content: Text('Apakah Anda yakin ingin melanjutkan checkout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Cancel action
              child: Text('Batal'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close the dialog

                // Insert checkout history (saves current timestamp)
                int checkoutId = await dbHelper.insertCheckoutHistory(
                  widget.projectId,
                  totalAmount,
                );

                // Insert checkout items and update stock quantity
                for (var item in cartItems) {
                  await dbHelper.insertCheckoutItem(
                    checkoutId,
                    item['id'],
                    item['quantity'],
                    item['price'],
                  );

                  // Update the inventory stock quantity
                  await dbHelper.updateInventoryStock(
                    item['id'],
                    item['quantity'],
                  );
                }

                // Clear cart after checkout
                setState(() {
                  cartItems.clear();
                  totalAmount = 0.0;
                });

                // Reload the inventory after checkout
                await _loadInventoryItems(); // Refetch inventory after checkout

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Checkout berhasil!')),
                );
              },
              child: Text('Checkout'),
            ),
          ],
        );
      },
    );
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
            "Keranjang - ${widget.projectName}",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Row(
          children: [
            // Left side: Total and Cart Items
            Expanded(
              child: Column(
                children: [
                  // Total Purchase and Checkout Button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text("Total Pembelian",
                            style: TextStyle(fontSize: 18)),
                        Text(
                          "Rp ${NumberFormat.currency(locale: 'id', symbol: '', decimalDigits: 0).format(totalAmount)}",
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _checkout, // Trigger checkout
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10.0),
                            child: Text("Checkout"),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Cart Items List
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: ListView.builder(
                        itemCount: cartItems.length,
                        itemBuilder: (context, index) {
                          final cartItem = cartItems[index];
                          return ListTile(
                            title: Text(cartItem['name']),
                            subtitle: Text(
                                "Rp ${NumberFormat.currency(locale: 'id', symbol: '', decimalDigits: 0).format(cartItem['totalPrice'])}"),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.remove),
                                  onPressed: () => _removeFromCart(cartItem),
                                ),
                                Text(cartItem['quantity'].toString()),
                                IconButton(
                                  icon: Icon(Icons.add),
                                  onPressed: () => _addToCart(cartItem),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 32),
            // Right side: Inventory Items List
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Expanded(
                    flex: 1,
                    child: Container(
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
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    flex: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: ListView.builder(
                        itemCount: inventoryItems.length,
                        itemBuilder: (context, index) {
                          final item = inventoryItems[index];
                          return ListTile(
                            title: Text(item['item_name']),
                            subtitle: Text(
                                "Rp ${NumberFormat.currency(locale: 'id', symbol: '', decimalDigits: 0).format(item['price'])} | Stok: ${item['stock_quantity']}"),
                            trailing: IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () => _addToCart(item),
                            ),
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
    );
  }
}
