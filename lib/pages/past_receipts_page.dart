import 'package:cashier_app/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/receipt.dart';
import '../services/database_helper.dart';
import 'receipt_page.dart';
import 'edit_receipt_page.dart'; 
import '../main.dart';
import '../models/user_role.dart';
import 'edit_saved_receipt_page.dart'; 

class PastReceiptsPage extends StatefulWidget {
  const PastReceiptsPage({super.key});

  @override
  State<PastReceiptsPage> createState() => _PastReceiptsPageState();
}

class _PastReceiptsPageState extends State<PastReceiptsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late Future<List<Receipt>> _receiptsFuture;

  @override
  void initState() {
    super.initState();
    _loadReceipts();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadReceipts() {
    setState(() {
      _receiptsFuture = DatabaseHelper.instance.getAllReceipts();
    });
  }

  List<Receipt> _filterReceipts(List<Receipt> allReceipts) {
    if (_searchQuery.isEmpty) {
      return allReceipts;
    } else {
      final query = _searchQuery.toLowerCase();
      final dateFormat = DateFormat('yyyy-MM-dd');

      return allReceipts.where((receipt) {
        final formattedDate = dateFormat.format(receipt.timestamp).toLowerCase();
        final idMatch = receipt.id.toLowerCase().contains(query);
        final dateMatch = formattedDate.contains(query);
        return idMatch || dateMatch;
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy - hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Past Receipts'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by ID or Date (YYYY-MM-DD)...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
                 filled: true,
                 fillColor: Colors.grey[200],
                 contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Receipt>>(
              future: _receiptsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error loading receipts: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                       'No past receipts available.',
                       style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  );
                } else {
                  final allReceipts = snapshot.data!;
                  final filteredReceipts = _filterReceipts(allReceipts);

                  if (filteredReceipts.isEmpty) {
                     return Center(
                       child: Text(
                         'No receipts found matching "$_searchQuery".',
                         style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                         textAlign: TextAlign.center,
                       ),
                     );
                  }

                  return ListView.builder(
                    itemCount: filteredReceipts.length,
                    itemBuilder: (context, index) {
                      final receipt = filteredReceipts[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: ListTile(
                          leading: const Icon(Icons.receipt_long, color: Colors.teal),
                          title: Text(
                            'Receipt ID: ${receipt.id.substring(0, 8)}...',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Date: ${dateFormat.format(receipt.timestamp)}\n'
                            'Total: ${idrFormatter.format(receipt.totalAmount)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (currentUserRole == UserRole.admin)
                                IconButton(
                                  icon: Icon(Icons.edit, color: Colors.orange[700]),
                                  onPressed: () async {
                                  final result = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EditSavedReceiptPage(initialReceipt: receipt),
                                    ),
                                  );
                                  if (result == true && mounted) {
                                    _loadReceipts();
                                  }
                                },
                              ),
                              Icon(Icons.chevron_right, color: Colors.grey[600]),
                            ],
                          ),
                          isThreeLine: true,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ReceiptPage(receipt: receipt,
                                                                  isViewingPastReceipt: true,),
                            ),
                            );
                          },
                        ),
                      );
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
