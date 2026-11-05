import 'package:flutter/material.dart';
import '../models/expense.dart';

const _ink = Color(0xFF173B69);
const _blue = Color(0xFF2878E8);
const _muted = Color(0xFF8AA7CE);

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({this.expense, super.key});

  final Expense? expense;

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  late String? _selectedCategory;

  static const _categories = [
    'Food',
    'Transport',
    'Shopping',
    'Entertainment',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    _titleController.text = expense?.title ?? '';
    _amountController.text = expense?.amount.toString() ?? '';
    _selectedCategory = expense?.category;
  }

  void _saveExpense() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.pop(
      context,
      widget.expense?.copyWith(
            title: _titleController.text.trim(),
            amount: double.parse(_amountController.text.trim()),
            category: _selectedCategory!,
          ) ??
          Expense(
            title: _titleController.text.trim(),
            amount: double.parse(_amountController.text.trim()),
            category: _selectedCategory!,
            createdAt: DateTime.now(),
          ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF3FF),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/background.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 615),
                  child: _buildFormCard(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FCFF).withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF397AC5).withValues(alpha: 0.14),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: _ink, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFDCEAFF),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.expense == null ? 'Add Expense' : 'Edit Expense',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(
                  Icons.account_balance_wallet,
                  color: _blue,
                  size: 21,
                ),
              ],
            ),
            const SizedBox(height: 17),
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: _fieldDecoration(label: 'Title', icon: Icons.title),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: _fieldDecoration(
                label: 'Amount',
                icon: Icons.currency_rupee,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an amount';
                }
                if (double.tryParse(value.trim()) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: _blue),
              decoration: _fieldDecoration(
                label: 'Category',
                icon: Icons.grid_view_rounded,
              ),
              dropdownColor: const Color(0xFFF9FBFF),
              borderRadius: BorderRadius.circular(14),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Row(
                    children: [
                      _categoryBadge(category),
                      const SizedBox(width: 10),
                      Text(category, style: const TextStyle(color: _ink)),
                    ],
                  ),
                );
              }).toList(),
              selectedItemBuilder: (context) => _categories
                  .map(
                    (category) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        category,
                        style: const TextStyle(color: _ink),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedCategory = value);
              },
              validator: (value) {
                if (value == null) return 'Please select a category';
                return null;
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3979F6), Color(0xFF6655F4)],
                  ),
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4B69ED).withValues(alpha: 0.22),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _saveExpense,
                    borderRadius: BorderRadius.circular(11),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.save_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 9),
                        Text(
                          widget.expense == null
                              ? 'Add Expense'
                              : 'Save Changes',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _muted, fontSize: 14),
      prefixIcon: Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            color: Color(0xFFF0F5FD),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 17, color: _blue),
        ),
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Color(0xFFE9F0FB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Color(0xFF82A7FF), width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Color(0xFFE45C73)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Color(0xFFE45C73), width: 1.4),
      ),
    );
  }

  Widget _categoryBadge(String category) {
    final (icon, color) = switch (category) {
      'Food' => (Icons.restaurant, const Color(0xFF16A085)),
      'Transport' => (Icons.directions_bus, const Color(0xFF1678E8)),
      'Shopping' => (Icons.shopping_bag, const Color(0xFFEE5267)),
      'Entertainment' => (Icons.sports_esports, const Color(0xFF8C58DE)),
      _ => (Icons.more_horiz, const Color(0xFF7697B9)),
    };

    return Container(
      width: 29,
      height: 29,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }
}
