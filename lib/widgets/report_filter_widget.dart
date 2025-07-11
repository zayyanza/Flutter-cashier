import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';

class ReportFilterWidget extends StatefulWidget {
  final Function(DateTime startDate, DateTime endDate, List<String> selectedCategories) onFilterApplied;
  const ReportFilterWidget({super.key, required this.onFilterApplied});

  @override
  State<ReportFilterWidget> createState() => _ReportFilterWidgetState();
}

class _ReportFilterWidgetState extends State<ReportFilterWidget> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  List<String> _allCategories = [];
  Map<String, bool> _selectedCategoriesMap = {};
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      final categories = await DatabaseHelper.instance.getAllProductCategories();
      setState(() {
        _allCategories = categories;
        _selectedCategoriesMap = {for (var cat in categories) cat: true};
        _isLoadingCategories = false;
      });
    } catch (e) {
      print("Error loading categories: $e");
      setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_startDate.isAfter(_endDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }

  void _applyFilters() {
    final selected = _selectedCategoriesMap.entries.where((entry) => entry.value).map((entry) => entry.key).toList();
    widget.onFilterApplied(_startDate, _endDate, selected);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, true),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Start Date', border: OutlineInputBorder()),
                      child: Text(dateFormat.format(_startDate)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, false),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'End Date', border: OutlineInputBorder()),
                      child: Text(dateFormat.format(_endDate)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Filter by Category:', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _isLoadingCategories
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _allCategories.isEmpty
                    ? const Text('No categories found.', style: TextStyle(color: Colors.grey))
                    : Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: _allCategories.map((category) {
                          return FilterChip(
                            label: Text(category),
                            selected: _selectedCategoriesMap[category] ?? false,
                            onSelected: (bool selected) {
                              setState(() {
                                _selectedCategoriesMap[category] = selected;
                              });
                            },
                            checkmarkColor: Theme.of(context).primaryColor,
                            selectedColor: Theme.of(context).primaryColorLight.withOpacity(0.3),
                          );
                        }).toList(),
                      ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.filter_alt_outlined),
              label: const Text('Apply Filters & Generate Report'),
              onPressed: _applyFilters,
            ),
          ],
        ),
      ),
    );
  }
}
