import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/database_helper.dart';
import 'projectinfo_provider.dart'; // Import your project info provider

// Define a state class to hold the inventory items
class InventoryState {
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> filteredItems; // Add filtered items list
  final bool isLoading;

  InventoryState({
    this.items = const [],
    this.filteredItems = const [],
    this.isLoading = false,
  });

  InventoryState copyWith({
    List<Map<String, dynamic>>? items,
  }) {
    return InventoryState(
      items: items ?? this.items,
    );
  }
}

// Create a notifier for managing the inventory state
class InventoryNotifier extends StateNotifier<InventoryState> {
  final DatabaseHelper dbHelper;
  final Ref ref; // Add Ref object to access other providers

  InventoryNotifier(this.ref, this.dbHelper) : super(InventoryState());

  // Fetch inventory based on the project ID
  Future<void> fetchInventory() async {
    state = InventoryState(isLoading: true);
    final projectId = ref.read(projectInfoProvider)!.id; // Use ref here

    List<Map<String, dynamic>> inventoryItems =
        await dbHelper.getInventoryByProject(projectId);

    state = InventoryState(items: inventoryItems, isLoading: false);
  }

  Future<void> addInventoryItem(
      String productName, double price, int stockQuantity) async {
    final projectId = ref.read(projectInfoProvider)!.id;
    await dbHelper.insertInventoryItem(
        projectId, productName, price, stockQuantity);
    await fetchInventory(); // Fetch updated inventory
  }

  // InventoryProvider methods

Future<void> updateInventoryItem(int itemId, String name, double price, int stock) async {
  await dbHelper.updateInventoryItem(itemId, name, price, stock);
  state = state.copyWith(
    items: state.items.map((item) {
      if (item['id'] == itemId) {
        return {
          'id': itemId,
          'item_name': name,
          'price': price,
          'stock_quantity': stock,
        };
      }
      return item;
    }).toList(),
  );
}

Future<void> deleteInventoryItem(int itemId) async {
  await dbHelper.deleteInventoryItem(itemId);
  state = state.copyWith(
    items: state.items.where((item) => item['id'] != itemId).toList(),
  );
}

}

final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper(); // Return an instance of DatabaseHelper
});

// Create a provider for the inventory notifier
final inventoryProvider =
    StateNotifierProvider<InventoryNotifier, InventoryState>(
  (ref) =>
      InventoryNotifier(ref, ref.read(databaseHelperProvider)), // Pass ref here
);
