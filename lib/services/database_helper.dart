import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/product.dart';
import '../models/receipt.dart';
import 'package:flutter/foundation.dart';

extension DatabaseExceptionHelper on DatabaseException {
  bool isForeignKeyConstraintError() {
    final message = toString().toLowerCase();
    return message.contains('foreign key constraint failed') ||
        message.contains('constraint failed') ||
        message.contains('foreign key');
  }
}

class DatabaseHelper {
  static const _databaseName = "CashierApp.db";
  static const _databaseVersion = 2;

  static const tableProducts = 'products';
  static const tableReceipts = 'receipts';
  static const tableReceiptItems = 'receipt_items';

  static const colProductId = 'id';
  static const colProductName = 'name';
  static const colProductCategory = 'category';
  static const colProductPrice = 'price';
  static const colProductImageUrl = 'imageUrl';
  static const colProductStock = 'stock';
  static const colProductBuyingPrice = 'buyingPrice';

  static const colReceiptId = 'id';
  static const colReceiptTotalAmount = 'totalAmount';
  static const colReceiptPaymentMethod = 'paymentMethod';
  static const colReceiptAmountPaid = 'amountPaid';
  static const colReceiptChangeGiven = 'changeGiven';
  static const colReceiptTimestamp = 'timestamp';

  static const colReceiptItemId = 'id';
  static const colReceiptItemReceiptId = 'receiptId';
  static const colReceiptItemProductId = 'productId';
  static const colReceiptItemQuantity = 'quantity';
  static const colReceiptItemPriceAtSale = 'priceAtTimeOfSale';

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableProducts (
        $colProductId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colProductName TEXT NOT NULL,
        $colProductCategory TEXT NOT NULL,
        $colProductPrice REAL NOT NULL,
        $colProductImageUrl TEXT,
        $colProductStock INTEGER NOT NULL DEFAULT 0,
        $colProductBuyingPrice REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableReceipts (
        $colReceiptId TEXT PRIMARY KEY,
        $colReceiptTotalAmount REAL NOT NULL,
        $colReceiptPaymentMethod TEXT NOT NULL,
        $colReceiptAmountPaid REAL,
        $colReceiptChangeGiven REAL,
        $colReceiptTimestamp INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableReceiptItems (
        $colReceiptItemId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colReceiptItemReceiptId TEXT NOT NULL,
        $colReceiptItemProductId INTEGER NOT NULL,
        $colReceiptItemQuantity INTEGER NOT NULL,
        $colReceiptItemPriceAtSale REAL NOT NULL,
        FOREIGN KEY ($colReceiptItemReceiptId) REFERENCES $tableReceipts ($colReceiptId) ON DELETE CASCADE,
        FOREIGN KEY ($colReceiptItemProductId) REFERENCES $tableProducts ($colProductId) ON DELETE RESTRICT
      )
    ''');

    await _insertInitialProducts(db);
    if (kDebugMode) {
      print("Database tables created and initial products inserted.");
    }
  }

  Future<void> _insertInitialProducts(Database db) async {
    List<Product> initialProducts = [
      Product(id: 0, name: 'Cola', category: 'Drinks', price: 10000, stock: 100, buyingPrice: 3000),
      Product(id: 0, name: 'Water', category: 'Drinks', price: 5000, stock: 150, buyingPrice: 1500),
      Product(id: 0, name: 'Orange Juice', category: 'Drinks', price: 12000, stock: 70, buyingPrice: 4000),
      Product(id: 0, name: 'Chips', category: 'Snacks', price: 8000, stock: 80, buyingPrice: 3500),
      Product(id: 0, name: 'Chocolate Bar', category: 'Snacks', price: 15000, stock: 60, buyingPrice: 7000),
      Product(id: 0, name: 'Sandwich', category: 'Food', price: 25000, stock: 20, buyingPrice: 15000),
      Product(id: 0, name: 'Salad', category: 'Food', price: 30000, stock: 15, buyingPrice: 18000),
      Product(id: 0, name: 'Coffee', category: 'Hot Drinks', price: 18000, stock: 50, buyingPrice: 8000),
      Product(id: 0, name: 'Tea', category: 'Hot Drinks', price: 15000, stock: 50, buyingPrice: 7000),
    ];

    for (Product product in initialProducts) {
      await db.insert(tableProducts, product.toMapForDb(), conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (kDebugMode) print("Upgrading database from version $oldVersion to $newVersion");
    if (oldVersion < 2) {
      if (kDebugMode) print("Applying version 2 upgrade: Adding stock and buyingPrice columns");
      try {
        await db.execute("ALTER TABLE $tableProducts ADD COLUMN $colProductStock INTEGER NOT NULL DEFAULT 0;");
        await db.execute("ALTER TABLE $tableProducts ADD COLUMN $colProductBuyingPrice REAL;");
        if (kDebugMode) print("Columns added successfully.");
      } catch (e) {
        if (kDebugMode) print("Error adding columns during upgrade: $e");
      }
    }
  }

  Future<int> insertProduct(Product product) async {
    Database db = await instance.database;
    return await db.insert(tableProducts, product.toMapForDb(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateProduct(Product product) async {
    Database db = await instance.database;
    return await db.update(
      tableProducts,
      product.toMapForDb(),
      where: '$colProductId = ?',
      whereArgs: [product.id],
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  Future<List<Product>> getAllProducts() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(tableProducts, orderBy: '$colProductCategory, $colProductName');
    if (maps.isEmpty) return [];
    return List.generate(maps.length, (i) {
      return Product(
        id: maps[i][colProductId],
        name: maps[i][colProductName],
        category: maps[i][colProductCategory],
        price: maps[i][colProductPrice],
        imageUrl: maps[i][colProductImageUrl],
        stock: maps[i][colProductStock] ?? 0,
        buyingPrice: maps[i][colProductBuyingPrice],
      );
    });
  }

  Future<Product?> getProductById(int id) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(
      tableProducts,
      where: '$colProductId = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Product(
        id: maps[0][colProductId],
        name: maps[0][colProductName],
        category: maps[0][colProductCategory],
        price: maps[0][colProductPrice],
        imageUrl: maps[0][colProductImageUrl],
        stock: maps[0][colProductStock] ?? 0,
        buyingPrice: maps[0][colProductBuyingPrice],
      );
    }
    return null;
  }

  Future<int> deleteProduct(int id) async {
    Database db = await instance.database;
    try {
      int result = await db.delete(
        tableProducts,
        where: '$colProductId = ?',
        whereArgs: [id],
      );
      if (result > 0) {
        if (kDebugMode) print("Deleted product with ID: $id");
      } else {
        if (kDebugMode) print("Product with ID: $id not found for deletion.");
      }
      return result;
    } on DatabaseException catch (e) {
      if (e.isForeignKeyConstraintError()) {
        if (kDebugMode) print("Could not delete product $id due to foreign key constraint.");
        throw Exception('Cannot delete product: It is used in past receipts.');
      } else {
        if (kDebugMode) print("Database error deleting product $id: $e");
        rethrow;
      }
    }
  }

  Future<void> insertReceipt(Receipt receipt) async {
    Database db = await instance.database;
    await db.transaction((txn) async {
      await txn.insert(tableReceipts, {
        colReceiptId: receipt.id,
        colReceiptTotalAmount: receipt.totalAmount,
        colReceiptPaymentMethod: receipt.paymentMethod.name,
        colReceiptAmountPaid: receipt.amountPaid,
        colReceiptChangeGiven: receipt.changeGiven,
        colReceiptTimestamp: receipt.timestamp.millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      for (var entry in receipt.items.entries) {
        Product product = entry.key;
        int quantity = entry.value;
        await txn.insert(tableReceiptItems, {
          colReceiptItemReceiptId: receipt.id,
          colReceiptItemProductId: product.id,
          colReceiptItemQuantity: quantity,
          colReceiptItemPriceAtSale: product.price,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await _updateProductStock(product.id, -quantity, txn);
      }
    });
    print("Receipt ${receipt.id} and items inserted into DB.");
  }

  Future<List<Receipt>> getAllReceipts() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> receiptMaps = await db.query(tableReceipts, orderBy: '$colReceiptTimestamp DESC');
    List<Receipt> receipts = [];
    for (var receiptMap in receiptMaps) {
      final String receiptId = receiptMap[colReceiptId];
      final List<Map<String, dynamic>> itemMaps = await db.query(
        tableReceiptItems,
        where: '$colReceiptItemReceiptId = ?',
        whereArgs: [receiptId],
      );
      Map<Product, int> items = {};
      if (itemMaps.isNotEmpty) {
        for (var itemMap in itemMaps) {
          int productId = itemMap[colReceiptItemProductId];
          int quantity = itemMap[colReceiptItemQuantity];
          double priceAtSale = itemMap[colReceiptItemPriceAtSale];
          Product? product = await getProductById(productId);
          if (product != null) {
            Product productAtSale = Product(
              id: product.id,
              name: product.name,
              category: product.category,
              price: priceAtSale,
              imageUrl: product.imageUrl,
            );
            items[productAtSale] = quantity;
          } else {
            print("Warning: Product with ID $productId not found for receipt $receiptId");
          }
        }
      }
      receipts.add(Receipt(
        id: receiptId,
        items: items,
        totalAmount: receiptMap[colReceiptTotalAmount],
        paymentMethod: PaymentMethod.values.firstWhere(
          (e) => e.name == receiptMap[colReceiptPaymentMethod],
          orElse: () => PaymentMethod.other,
        ),
        amountPaid: receiptMap[colReceiptAmountPaid],
        changeGiven: receiptMap[colReceiptChangeGiven],
        timestamp: DateTime.fromMillisecondsSinceEpoch(receiptMap[colReceiptTimestamp]),
      ));
    }
    return receipts;
  }

  Future<int> updateReceiptHeader(Receipt receipt) async {
    Database db = await instance.database;
    return await db.update(
      tableReceipts,
      {
        colReceiptPaymentMethod: receipt.paymentMethod.name,
        colReceiptAmountPaid: receipt.amountPaid,
        colReceiptChangeGiven: receipt.changeGiven,
      },
      where: '$colReceiptId = ?',
      whereArgs: [receipt.id],
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  Future<List<Product>> getProductsForStockReport() async {
    return await getAllProducts();
  }

  Future<List<Map<String, dynamic>>> getSalesData({
    required DateTime startDate,
    required DateTime endDate,
    List<String>? categories,
  }) async {
    Database db = await instance.database;
    DateTime inclusiveEndDate = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
    String categoriesFilter = '';
    List<dynamic> whereArgs = [startDate.millisecondsSinceEpoch, inclusiveEndDate.millisecondsSinceEpoch];
    if (categories != null && categories.isNotEmpty) {
      String placeholders = List.filled(categories.length, '?').join(', ');
      categoriesFilter = "AND p.$colProductCategory IN ($placeholders)";
      whereArgs.addAll(categories);
    }
    final String sql = '''
      SELECT
        p.$colProductName AS productName,
        p.$colProductId AS productId,
        p.$colProductCategory AS category,
        SUM(ri.$colReceiptItemQuantity) AS quantitySold,
        SUM(ri.$colReceiptItemQuantity * ri.$colReceiptItemPriceAtSale) AS totalRevenue,
        SUM(ri.$colReceiptItemQuantity * p.$colProductBuyingPrice) AS totalCost
      FROM $tableReceipts r
      JOIN $tableReceiptItems ri ON r.$colReceiptId = ri.$colReceiptItemReceiptId
      JOIN $tableProducts p ON ri.$colReceiptItemProductId = p.$colProductId
      WHERE r.$colReceiptTimestamp BETWEEN ? AND ?
      $categoriesFilter
      GROUP BY p.$colProductId, p.$colProductName, p.$colProductCategory
      ORDER BY p.$colProductCategory, p.$colProductName;
    ''';
    if (kDebugMode) {
      print("SQL for Sales Data: $sql");
      print("Args for Sales Data: $whereArgs");
    }
    List<Map<String, dynamic>> result = await db.rawQuery(sql, whereArgs);
    return result;
  }

  Future<List<String>> getAllProductCategories() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableProducts,
      distinct: true,
      columns: [colProductCategory],
      orderBy: colProductCategory,
    );
    return maps.map((map) => map[colProductCategory] as String).toList();
  }

  Future<bool> isCategoryInUseByProducts(String categoryName) async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> result = await db.query(
      tableProducts,
      where: '$colProductCategory = ?',
      whereArgs: [categoryName],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<int> updateCategoryForProducts(String oldCategory, String newCategory) async {
    Database db = await instance.database;
    return await db.update(
      tableProducts,
      {colProductCategory: newCategory},
      where: '$colProductCategory = ?',
      whereArgs: [oldCategory],
    );
  }

  Future<bool> ensureCategoryIsDeletable(String categoryName) async {
    bool inUse = await isCategoryInUseByProducts(categoryName);
    if (inUse) {
      throw Exception('Cannot delete category "$categoryName": It is currently assigned to one or more products.');
    }
    return true;
  }

  Future<bool> isCategoryReferencedInSales(String categoryName) async {
    Database db = await instance.database;
    final String sql = '''
      SELECT 1
      FROM $tableReceiptItems ri
      JOIN $tableProducts p ON ri.$colReceiptItemProductId = p.$colProductId
      WHERE p.$colProductCategory = ?
      LIMIT 1;
    ''';
    final List<Map<String, dynamic>> result = await db.rawQuery(sql, [categoryName]);
    return result.isNotEmpty;
  }

  Future<void> _updateProductStock(int productId, int quantityChange, DatabaseExecutor txn) async {
    final List<Map<String, dynamic>> productData = await txn.query(
      tableProducts,
      columns: [colProductStock],
      where: '$colProductId = ?',
      whereArgs: [productId],
    );
    if (productData.isNotEmpty) {
      int currentStock = productData.first[colProductStock] as int? ?? 0;
      int newStock = currentStock + quantityChange;
      await txn.update(
        tableProducts,
        {colProductStock: newStock},
        where: '$colProductId = ?',
        whereArgs: [productId],
      );
      if (kDebugMode) {
        print("Stock updated for product $productId: Old $currentStock, Change $quantityChange, New $newStock");
      }
    } else {
      if (kDebugMode) {
        print("Warning: Product ID $productId not found during stock update.");
      }
    }
  }

  Future<int> _deleteReceiptItemsForReceipt(String receiptId, DatabaseExecutor txn) async {
    return await txn.delete(
      tableReceiptItems,
      where: '$colReceiptItemReceiptId = ?',
      whereArgs: [receiptId],
    );
  }

  Future<int> _updateMainReceiptRecord(String receiptId, double newTotalAmount, DatabaseExecutor txn) async {
    return await txn.update(
      tableReceipts,
      {colReceiptTotalAmount: newTotalAmount},
      where: '$colReceiptId = ?',
      whereArgs: [receiptId],
    );
  }

  Future<void> updateSavedReceipt(Receipt editedReceipt, Map<Product, int> originalItemsSnapshot) async {
    Database db = await instance.database;
    await db.transaction((txn) async {
      Map<int, int> stockQuantityChanges = {};
      originalItemsSnapshot.forEach((product, originalQuantity) {
        stockQuantityChanges[product.id] = (stockQuantityChanges[product.id] ?? 0) + originalQuantity;
      });
      editedReceipt.items.forEach((product, newQuantity) {
        stockQuantityChanges[product.id] = (stockQuantityChanges[product.id] ?? 0) - newQuantity;
      });
      for (var entry in stockQuantityChanges.entries) {
        int productId = entry.key;
        int netChange = entry.value;
        if (netChange != 0) {
          await _updateProductStock(productId, netChange, txn);
        }
      }
      if (kDebugMode) {
        print("Applied stock adjustments for edited receipt: ${editedReceipt.id}");
      }
      await txn.delete(
        tableReceiptItems,
        where: '$colReceiptItemReceiptId = ?',
        whereArgs: [editedReceipt.id],
      );
      if (kDebugMode) {
        print("Deleted old items for receipt: ${editedReceipt.id}");
      }
      for (var entry in editedReceipt.items.entries) {
        Product product = entry.key;
        int quantity = entry.value;
        await txn.insert(tableReceiptItems, {
          colReceiptItemReceiptId: editedReceipt.id,
          colReceiptItemProductId: product.id,
          colReceiptItemQuantity: quantity,
          colReceiptItemPriceAtSale: product.price,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      if (kDebugMode) {
        print("Inserted new items for receipt: ${editedReceipt.id}");
      }
      await txn.update(
        tableReceipts,
        {
          colReceiptTotalAmount: editedReceipt.totalAmount,
          colReceiptPaymentMethod: editedReceipt.paymentMethod.name,
          colReceiptAmountPaid: editedReceipt.amountPaid,
          colReceiptChangeGiven: editedReceipt.changeGiven,
        },
        where: '$colReceiptId = ?',
        whereArgs: [editedReceipt.id],
      );
      if (kDebugMode) {
        print("Updated main receipt record for: ${editedReceipt.id} with new payment details.");
      }
    });
    if (kDebugMode) {
      print("Receipt ${editedReceipt.id} fully updated (items, total, payment, stock) in DB.");
    }
  }

  Future<Map<int, int>> _getOriginalItemQuantities(String receiptId, DatabaseExecutor txn) async {
    final List<Map<String, dynamic>> itemsData = await txn.query(
      tableReceiptItems,
      columns: [colReceiptItemProductId, colReceiptItemQuantity],
      where: '$colReceiptItemReceiptId = ?',
      whereArgs: [receiptId],
    );
    return {for (var item in itemsData) item[colReceiptItemProductId] as int: item[colReceiptItemQuantity] as int};
  }
}

extension ProductDbExtension on Product {
  Map<String, dynamic> toMapForDb() {
    return {
      DatabaseHelper.colProductName: name,
      DatabaseHelper.colProductCategory: category,
      DatabaseHelper.colProductPrice: price,
      DatabaseHelper.colProductImageUrl: imageUrl,
      DatabaseHelper.colProductStock: stock,
      DatabaseHelper.colProductBuyingPrice: buyingPrice,
    };
  }
}
