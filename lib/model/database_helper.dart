import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;

    // Initialize the FFI for desktop platforms
    if (isDesktop()) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    // Initialize the database
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'cartapp_data.db');
    print('Database path: $path');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Create the 'projects' table
        await db.execute('''
        CREATE TABLE projects (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');

        // Create the 'inventory' table with ON DELETE CASCADE
        await db.execute('''
        CREATE TABLE inventory (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          project_id INTEGER,
          item_name TEXT NOT NULL,
          price REAL NOT NULL,
          stock_quantity INTEGER NOT NULL,
          FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
        )
      ''');

        // Create the 'checkout_history' table with ON DELETE CASCADE
        await db.execute('''
        CREATE TABLE checkout_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER,  -- Optional, if user management is implemented
          project_id INTEGER,
          checkout_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          total_amount REAL NOT NULL,
          FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
        )
      ''');

        // Create the 'checkout_items' table with ON DELETE CASCADE
        await db.execute('''
        CREATE TABLE checkout_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          checkout_history_id INTEGER,
          item_id INTEGER,
          quantity INTEGER NOT NULL,
          price REAL NOT NULL,
          FOREIGN KEY (checkout_history_id) REFERENCES checkout_history (id) ON DELETE CASCADE,
          FOREIGN KEY (item_id) REFERENCES inventory (id) ON DELETE CASCADE
        )
      ''');
      },
    );
  }

  // Helper function to check if the app is running on desktop
  bool isDesktop() {
    return identical(0, 0.0); // Hacky way to check desktop platforms
  }

  // ---------- CRUD for Projects Table ---------- //

  Future<int> insertProject(String name) async {
    final db = await database;

    return await db.insert(
      'projects',
      {'name': name},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>> getProjectById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'projects',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : {};
  }

  Future<List<Map<String, dynamic>>> getProjects() async {
    final db = await database;

    return await db.query('projects', orderBy: 'created_at DESC');
  }

  Future<int> updateProject(int id, String newName) async {
    final db = await database;

    return await db.update(
      'projects',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteProject(int id) async {
    final db = await database;

    return await db.delete(
      'projects',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------- CRUD for Inventory Table ---------- //

  Future<int> insertInventoryItem(
      int projectId, String itemName, double price, int stockQuantity) async {
    final db = await database;

    return await db.insert(
      'inventory',
      {
        'project_id': projectId,
        'item_name': itemName,
        'price': price,
        'stock_quantity': stockQuantity,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getInventoryByProject(
      int projectId) async {
    final db = await database;

    return await db.query(
      'inventory',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'item_name ASC',
    );
  }

  Future<int> updateInventoryItem(
      int id, String itemName, double price, int stockQuantity) async {
    final db = await database;

    return await db.update(
      'inventory',
      {
        'item_name': itemName,
        'price': price,
        'stock_quantity': stockQuantity,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteInventoryItem(int id) async {
    final db = await database;

    return await db.delete(
      'inventory',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------- CRUD for Checkout History Table ---------- //

  Future<int> insertCheckoutHistory(int projectId, double totalAmount) async {
    final db = await database;

    String currentDate =
        DateTime.now().toIso8601String(); // Insert current date

    return await db.insert(
      'checkout_history',
      {
        'project_id': projectId,
        'total_amount': totalAmount,
        'checkout_date': currentDate, // Store the current date
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getCheckoutHistoryByProject(
      int projectId) async {
    final db = await database;

    return await db.query(
      'checkout_history',
      columns: [
        'id',
        'project_id',
        'total_amount',
        'checkout_date'
      ], // Ensure date is selected
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'checkout_date DESC',
    );
  }

  // ---------- CRUD for Checkout Items Table ---------- //

  Future<int> insertCheckoutItem(
      int checkoutHistoryId, int itemId, int quantity, double price) async {
    final db = await database;

    return await db.insert(
      'checkout_items',
      {
        'checkout_history_id': checkoutHistoryId,
        'item_id': itemId,
        'quantity': quantity,
        'price': price,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getCheckoutItemsByHistory(
      int checkoutHistoryId) async {
    final db = await database;

    // Join checkout_items with inventory to get item names
    return await db.rawQuery('''
    SELECT ci.*, i.item_name 
    FROM checkout_items ci
    JOIN inventory i ON ci.item_id = i.id
    WHERE ci.checkout_history_id = ?
    ORDER BY ci.id ASC
  ''', [checkoutHistoryId]);
  }

  // ---------- Checkout Process ---------- //

  Future<void> processCheckout(int projectId,
      List<Map<String, dynamic>> cartItems, double totalAmount) async {
    final db = await database;

    // Insert a new checkout history record
    int checkoutHistoryId = await insertCheckoutHistory(projectId, totalAmount);

    // Insert each item from the cart into the checkout_items table and update inventory stock
    for (var item in cartItems) {
      await insertCheckoutItem(
          checkoutHistoryId, item['id'], item['quantity'], item['price']);

      // Update stock quantity in the inventory
      int newStock = item['stock_quantity'] - item['quantity'];
      await updateInventoryItem(
          item['id'], item['name'], item['price'], newStock);
    }
  }

  Future<void> updateInventoryStock(int itemId, int quantity) async {
    final db = await database;

    // Fetch the current stock quantity first
    final List<Map<String, dynamic>> result = await db.query(
      'inventory',
      columns: ['stock_quantity'],
      where: 'id = ?',
      whereArgs: [itemId],
    );

    if (result.isNotEmpty) {
      int currentStock = result[0]['stock_quantity'];
      int newStock = currentStock - quantity;

      // Update the stock quantity in the inventory
      await db.update(
        'inventory',
        {'stock_quantity': newStock},
        where: 'id = ?',
        whereArgs: [itemId],
      );
    }
  }

  // ---------- Search Functionality for Inventory Table ---------- //

  Future<List<Map<String, dynamic>>> searchInventoryItems(String query) async {
    final db = await database;

    return await db.query(
      'inventory',
      where: 'item_name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'item_name ASC',
    );
  }
}
