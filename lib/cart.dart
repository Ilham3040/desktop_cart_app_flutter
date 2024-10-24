import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/inventory_provider.dart';
import 'providers/projectinfo_provider.dart';
import 'model/database_helper.dart';

class CartPage extends ConsumerStatefulWidget {
  const CartPage({super.key});

  @override
  CartPageState createState() => CartPageState();
}

class CartPageState extends ConsumerState<CartPage> {
  List<Map<String, dynamic>> cartItems = [];
  List<Map<String, dynamic>> filteredItems = [];
  double totalAmount = 0.0;
  final dbHelper = DatabaseHelper();
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(inventoryProvider.notifier).fetchInventory());
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

  void _addToCart(Map<String, dynamic> item) {
    final inventoryState = ref.read(inventoryProvider).items;
    setState(() {
      int index =
          cartItems.indexWhere((cartItem) => cartItem['id'] == item['id']);
      int stateIndex =
          inventoryState.indexWhere((cartItem) => cartItem['id'] == item['id']);
      if (index != -1) {
        if (cartItems[index]['stock_quantity'] <
            inventoryState[stateIndex]['stock_quantity']) {
          cartItems[index]['stock_quantity'] += 1;
          cartItems[index]['totalPrice'] += item['price'];
          totalAmount += item['price'];
        }
      } else {
        cartItems.add({
          'id': item['id'],
          'name': item['item_name'],
          'price': item['price'],
          'stock_quantity': 1,
          'totalPrice': item['price'],
        });
        totalAmount += item['price'];
      }
    });
  }

  void _removeFromCart(Map<String, dynamic> item) {
    setState(() {
      int index =
          cartItems.indexWhere((cartItem) => cartItem['id'] == item['id']);
      if (index != -1 && cartItems[index]['stock_quantity'] > 0) {
        cartItems[index]['stock_quantity'] -= 1;
        cartItems[index]['totalPrice'] -= item['price'];
        totalAmount -= item['price'];

        if (cartItems[index]['stock_quantity'] == 0) {
          cartItems.removeAt(index);
        }
      }
    });
  }

  Future<void> _checkout() async {
    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keranjang kosong, tidak bisa checkout')),
      );
      return;
    }

    // Show confirmation dialog before proceeding
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Konfirmasi Checkout'),
          content: const Text('Apakah Anda yakin ingin melanjutkan checkout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Cancel action
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () async {
                final projectInfo = ref.read(projectInfoProvider)!;

                // Insert checkout history (saves current timestamp)
                int checkoutId = await dbHelper.insertCheckoutHistory(
                  projectInfo.id,
                  totalAmount,
                );

                // Insert checkout items and update stock quantity
                for (var item in cartItems) {
                  await dbHelper.insertCheckoutItem(
                    checkoutId,
                    item['id'],
                    item['stock_quantity'],
                    item['price'],
                  );

                  // Update the inventory stock quantity
                  await dbHelper.updateInventoryStock(
                    item['id'],
                    item['stock_quantity'],
                  );
                }

                ref.read(inventoryProvider.notifier).fetchInventory();

                // Clear cart after checkout
                setState(() {
                  cartItems.clear();
                  totalAmount = 0.0;
                });

                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Checkout berhasil!')),
                );
                }


              },
              child: const Text('Checkout'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final inventoryState = ref.watch(inventoryProvider);
    final itemsToDisplay =
        searchController.text.isEmpty ? inventoryState.items : filteredItems;
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
          backgroundColor: Colors.blue[900],
          foregroundColor: Colors.white,
          title: const Text(
            "Keranjang",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          )),
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
                            backgroundColor: Colors.blue[900],
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
                                  icon: const Icon(Icons.remove),
                                  onPressed: () => _removeFromCart(cartItem),
                                ),
                                Text(cartItem['stock_quantity'].toString()),
                                IconButton(
                                  icon: const Icon(Icons.add),
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
                        controller: searchController,
                        onChanged: _searchItems,
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
                        itemCount: itemsToDisplay.length,
                        itemBuilder: (context, index) {
                          final item = itemsToDisplay[index];
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
