import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../models/expense.dart';
import '../services/app_auth_service.dart';
import '../services/expense_repository.dart';
import 'add_expense_screen.dart';
import 'recycle_bin_screen.dart';

const _ink = Color(0xFF173B69);
const _blue = Color(0xFF1678E8);
const _muted = Color(0xFF87A4CC);

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.userId,
    required this.authService,
    required this.expenseRepository,
    super.key,
  });

  final String userId;
  final AppAuthService authService;
  final ExpenseRepository expenseRepository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Expense> _expenses = [];
  bool _isLoadingExpenses = true;
  bool _failedToLoadExpenses = false;
  String _loadErrorMessage = 'Could not load your expenses from Firebase.';
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() {
      _isLoadingExpenses = true;
      _failedToLoadExpenses = false;
    });

    try {
      final expenses = await widget.expenseRepository.loadExpenses(
        widget.userId,
      );

      if (!mounted) return;
      setState(() {
        _expenses
          ..clear()
          ..addAll(expenses);
        _isLoadingExpenses = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to load Firestore expenses: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _isLoadingExpenses = false;
        _failedToLoadExpenses = true;
        _loadErrorMessage = _loadErrorMessageFor(error);
      });
    }
  }

  String _loadErrorMessageFor(Object error) {
    if (error is FirebaseException && error.code == 'unavailable') {
      return 'Firestore cannot reach its server. Check your internet '
          'connection and make sure a Firestore database has been created.';
    }
    if (error is FirebaseException && error.code == 'permission-denied') {
      return 'Firestore denied access. Deploy the app Firestore security rules '
          'and check that you are signed in.';
    }
    return 'Could not load your expenses from Firebase. Please try again.';
  }

  void _showStorageError(String action) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Could not $action. Check your connection and try again.',
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await widget.authService.signOut();
    } catch (error, stackTrace) {
      debugPrint('Failed to sign out: $error\n$stackTrace');
      _showStorageError('sign out');
    }
  }

  double get totalAmount =>
      _expenses.fold(0, (sum, expense) => sum + expense.amount);

  List<Expense> get filteredExpenses {
    if (_selectedFilter == 'All') return _expenses;
    return _expenses
        .where((expense) => expense.category == _selectedFilter)
        .toList();
  }

  Future<void> _addExpense() async {
    final newExpense = await Navigator.push<Expense>(
      context,
      MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
    );

    if (newExpense != null && mounted) {
      try {
        final savedExpense = await widget.expenseRepository.addExpense(
          widget.userId,
          newExpense,
        );
        if (!mounted) return;
        setState(() => _expenses.insert(0, savedExpense));
      } catch (error, stackTrace) {
        debugPrint('Failed to add Firestore expense: $error\n$stackTrace');
        _showStorageError('add this expense');
      }
    }
  }

  Future<void> _editExpense(Expense expense) async {
    final updatedExpense = await Navigator.push<Expense>(
      context,
      MaterialPageRoute(
        builder: (context) => AddExpenseScreen(expense: expense),
      ),
    );

    if (updatedExpense == null || !mounted) return;
    try {
      await widget.expenseRepository.updateExpense(
        widget.userId,
        updatedExpense,
      );
      if (!mounted) return;
      setState(() {
        final index = _expenses.indexWhere((item) => item.id == expense.id);
        if (index >= 0) _expenses[index] = updatedExpense;
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to update Firestore expense: $error\n$stackTrace');
      _showStorageError('update this expense');
    }
  }

  Future<void> _deleteExpense(Expense expense) async {
    try {
      await widget.expenseRepository.deleteExpense(widget.userId, expense);
      if (!mounted) return;
      setState(() => _expenses.remove(expense));
    } catch (error, stackTrace) {
      debugPrint('Failed to delete Firestore expense: $error\n$stackTrace');
      _showStorageError('delete this expense');
    }
  }

  void _openRecycleBin() {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => RecycleBinScreen(
          userId: widget.userId,
          expenseRepository: widget.expenseRepository,
          onExpenseRestored: (expense) {
            if (!mounted) return;
            setState(() {
              _expenses.removeWhere((item) => item.id == expense.id);
              _expenses.insert(0, expense);
            });
          },
        ),
      ),
    );
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (_isLoadingExpenses) {
                  return const Center(
                    child: CircularProgressIndicator(color: _blue),
                  );
                }
                if (_failedToLoadExpenses) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _loadErrorMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _loadExpenses,
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final compact = constraints.maxWidth <= 450;
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 8 : 16,
                    12,
                    compact ? 8 : 16,
                    24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1164),
                      child: _buildDashboard(compact: compact),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard({required bool compact}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FCFF).withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF397AC5).withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 12 : 20,
          compact ? 12 : 14,
          compact ? 12 : 20,
          8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(compact: compact),
            SizedBox(height: compact ? 12 : 14),
            _buildTotalCard(),
            SizedBox(height: compact ? 12 : 16),
            _buildFilter(),
            SizedBox(height: compact ? 12 : 16),
            if (filteredExpenses.isEmpty)
              _buildEmptyState()
            else
              ...filteredExpenses.map(
                (expense) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildExpenseTile(expense, compact: compact),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 44,
                height: 44,
                child: FloatingActionButton(
                  heroTag: 'add-expense',
                  onPressed: _addExpense,
                  backgroundColor: const Color(0xFF5C5CF5),
                  foregroundColor: Colors.white,
                  elevation: 5,
                  child: const Icon(Icons.add, size: 25),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({required bool compact}) {
    final now = DateTime.now();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final title = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Expenses',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _ink,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'Track · Manage · Save',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _ink.withValues(alpha: 0.66),
              fontSize: 12,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
    final date = Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 11, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF667BD9).withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_month, size: 15, color: _ink),
          const SizedBox(width: 7),
          Text(
            compact
                ? 'Today · ${now.day} ${months[now.month - 1]}'
                : 'Today · ${now.day} ${months[now.month - 1]} ${now.year}',
            style: const TextStyle(
              color: _ink,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    final signOutButton = IconButton(
      tooltip: 'Sign out',
      onPressed: _signOut,
      icon: const Icon(Icons.logout, color: _ink, size: 20),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.55),
      ),
    );
    final recycleBinButton = IconButton(
      tooltip: 'Recycle bin',
      onPressed: _openRecycleBin,
      icon: const Icon(Icons.delete_sweep_outlined, color: _ink, size: 22),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.55),
      ),
    );

    final heading = Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.account_balance_wallet, color: _blue),
        ),
        SizedBox(width: compact ? 10 : 13),
        title,
        if (!compact) ...[
          const SizedBox(width: 10),
          date,
          const SizedBox(width: 4),
          recycleBinButton,
          const SizedBox(width: 4),
          signOutButton,
        ],
      ],
    );

    if (!compact) return heading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading,
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            date,
            const SizedBox(width: 4),
            recycleBinButton,
            const SizedBox(width: 4),
            signOutButton,
          ],
        ),
      ],
    );
  }

  Widget _buildTotalCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF16A9EE), Color(0xFF9A72F2)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5C8DF3).withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.24),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.white,
              size: 29,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Spent',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '₹${totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.savings_rounded,
            size: 54,
            color: Colors.white.withValues(alpha: 0.78),
          ),
        ],
      ),
    );
  }

  Widget _buildFilter() {
    const categories = [
      'All',
      'Food',
      'Transport',
      'Shopping',
      'Entertainment',
      'Other',
    ];

    return DropdownButtonFormField<String>(
      initialValue: _selectedFilter,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down, color: _blue),
      decoration: InputDecoration(
        labelText: 'Filter by Category',
        labelStyle: const TextStyle(color: _blue, fontSize: 12),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(9),
          child: _iconBadge(_categoryIcon(_selectedFilter), _blue),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFBFDAFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF6698FF), width: 1.4),
        ),
      ),
      dropdownColor: const Color(0xFFF9FBFF),
      borderRadius: BorderRadius.circular(14),
      items: categories
          .map(
            (category) => DropdownMenuItem(
              value: category,
              child: Text(category, style: const TextStyle(color: _ink)),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) setState(() => _selectedFilter = value);
      },
    );
  }

  Widget _buildExpenseTile(Expense expense, {required bool compact}) {
    final iconColor = _categoryColor(expense.category);
    final date = expense.createdAt;
    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
    final timeLabel = '$hour:$minute $period';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 10 : 11,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4784D1).withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: compact
          ? _buildCompactExpenseContent(
              expense,
              iconColor,
              dateLabel,
              timeLabel,
            )
          : Row(
              children: [
                _iconBadge(
                  _categoryIcon(expense.category),
                  iconColor,
                  size: 44,
                ),
                const SizedBox(width: 14),
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
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            expense.category,
                            style: const TextStyle(color: _muted, fontSize: 12),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 9),
                            child: Icon(
                              Icons.chevron_right,
                              size: 15,
                              color: _muted,
                            ),
                          ),
                          const Icon(Icons.schedule, size: 13, color: _muted),
                          const SizedBox(width: 4),
                          Text(
                            '$dateLabel · $timeLabel',
                            style: const TextStyle(color: _muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '₹${expense.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 9),
                IconButton(
                  tooltip: 'Edit expense',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _editExpense(expense),
                  icon: const Icon(Icons.edit_outlined, color: _blue),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFE7F0FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Delete expense',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _deleteExpense(expense),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFF04D68),
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFFFE9ED),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCompactExpenseContent(
    Expense expense,
    Color iconColor,
    String dateLabel,
    String timeLabel,
  ) {
    return Column(
      children: [
        Row(
          children: [
            _iconBadge(_categoryIcon(expense.category), iconColor, size: 42),
            const SizedBox(width: 10),
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
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    expense.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '₹${expense.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                color: _ink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            const Icon(Icons.schedule, size: 12, color: _muted),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '$dateLabel · $timeLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
            ),
            IconButton(
              tooltip: 'Edit expense',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 38, height: 38),
              padding: EdgeInsets.zero,
              onPressed: () => _editExpense(expense),
              icon: const Icon(Icons.edit_outlined, color: _blue),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFE7F0FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(width: 5),
            IconButton(
              tooltip: 'Delete expense',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 38, height: 38),
              padding: EdgeInsets.zero,
              onPressed: () => _deleteExpense(expense),
              icon: const Icon(Icons.delete_outline, color: Color(0xFFF04D68)),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFFFE9ED),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 27, horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 35, color: _muted),
          SizedBox(height: 8),
          Text(
            'No expenses yet',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 3),
          Text(
            'Tap + to add your first expense',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

Widget _iconBadge(IconData icon, Color color, {double size = 34}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      shape: BoxShape.circle,
    ),
    child: Icon(icon, size: size * 0.52, color: color),
  );
}

IconData _categoryIcon(String category) {
  switch (category) {
    case 'Food':
      return Icons.restaurant;
    case 'Transport':
      return Icons.directions_bus;
    case 'Shopping':
      return Icons.shopping_bag;
    case 'Entertainment':
      return Icons.sports_esports;
    case 'Other':
      return Icons.more_horiz;
    default:
      return Icons.grid_view_rounded;
  }
}

Color _categoryColor(String category) {
  switch (category) {
    case 'Food':
      return const Color(0xFF16A085);
    case 'Transport':
      return const Color(0xFF1678E8);
    case 'Shopping':
      return const Color(0xFFEE5267);
    case 'Entertainment':
      return const Color(0xFF8C58DE);
    default:
      return const Color(0xFF7697B9);
  }
}
