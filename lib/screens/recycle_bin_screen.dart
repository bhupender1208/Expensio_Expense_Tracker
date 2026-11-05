import 'package:flutter/material.dart';

import '../models/expense.dart';
import '../services/expense_repository.dart';

const _ink = Color(0xFF173B69);
const _blue = Color(0xFF1678E8);
const _muted = Color(0xFF87A4CC);

class RecycleBinScreen extends StatefulWidget {
  const RecycleBinScreen({
    required this.userId,
    required this.expenseRepository,
    required this.onExpenseRestored,
    super.key,
  });

  final String userId;
  final ExpenseRepository expenseRepository;
  final ValueChanged<Expense> onExpenseRestored;

  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen> {
  List<Expense> _deletedExpenses = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDeletedExpenses();
  }

  Future<void> _loadDeletedExpenses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final expenses = await widget.expenseRepository.loadDeletedExpenses(
        widget.userId,
      );
      if (!mounted) return;
      setState(() {
        _deletedExpenses = expenses;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to load deleted expenses: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load deleted expenses. Please try again.';
      });
    }
  }

  Future<void> _restoreExpense(Expense expense) async {
    try {
      await widget.expenseRepository.restoreExpense(widget.userId, expense);
      if (!mounted) return;
      setState(() {
        _deletedExpenses.removeWhere((item) => item.id == expense.id);
      });
      widget.onExpenseRestored(expense);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('"${expense.title}" restored')));
    } catch (error, stackTrace) {
      debugPrint('Failed to restore expense: $error\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not restore this expense. Check your connection and try again.',
          ),
        ),
      );
    }
  }

  Future<void> _permanentlyDeleteExpense(Expense expense) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete permanently?'),
        content: Text(
          '"${expense.title}" will be permanently deleted and cannot be restored.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;

    try {
      await widget.expenseRepository.permanentlyDeleteExpense(
        widget.userId,
        expense,
      );
      if (!mounted) return;
      setState(() {
        _deletedExpenses.removeWhere((item) => item.id == expense.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${expense.title}" permanently deleted')),
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to permanently delete expense: $error\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not permanently delete this expense. Check your connection and try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF3FF),
      appBar: AppBar(
        title: const Text('Recycle Bin'),
        foregroundColor: _ink,
        backgroundColor: const Color(0xFFEAF3FF),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _blue));
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loadDeletedExpenses,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    if (_deletedExpenses.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline, size: 48, color: _muted),
              SizedBox(height: 12),
              Text(
                'Recycle Bin is empty',
                style: TextStyle(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Expenses you delete will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _deletedExpenses.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final expense = _deletedExpenses[index];
        return Card(
          color: const Color(0xFFF9FCFF),
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_outlined, color: _muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${expense.category} · ₹${expense.amount.toStringAsFixed(2)}',
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _restoreExpense(expense),
                  icon: const Icon(Icons.restore),
                  label: const Text('Restore'),
                  style: TextButton.styleFrom(foregroundColor: _blue),
                ),
                IconButton(
                  tooltip: 'Delete permanently',
                  onPressed: () => _permanentlyDeleteExpense(expense),
                  icon: const Icon(Icons.delete_forever_outlined),
                  color: Colors.red,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
