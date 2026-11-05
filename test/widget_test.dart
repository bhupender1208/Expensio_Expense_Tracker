import 'package:expensio/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expensio/models/expense.dart';
import 'package:expensio/services/app_auth_service.dart';
import 'package:expensio/services/expense_repository.dart';

class _FakeAuthService implements AppAuthService {
  @override
  Stream<String?> get userIdChanges => Stream.value('test-user');

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signOut() async {}
}

class _FakeExpenseRepository implements ExpenseRepository {
  final List<Expense> expenses = [];
  final List<Expense> deletedExpenses = [];
  int _nextId = 0;

  @override
  Future<List<Expense>> loadExpenses(String userId) async => List.of(expenses);

  @override
  Future<List<Expense>> loadDeletedExpenses(String userId) async =>
      List.of(deletedExpenses);

  @override
  Future<Expense> addExpense(String userId, Expense expense) async {
    final saved = expense.copyWith(id: 'test-${_nextId++}');
    expenses.insert(0, saved);
    return saved;
  }

  @override
  Future<void> updateExpense(String userId, Expense expense) async {
    final index = expenses.indexWhere((saved) => saved.id == expense.id);
    if (index >= 0) expenses[index] = expense;
  }

  @override
  Future<void> deleteExpense(String userId, Expense expense) async {
    final index = expenses.indexWhere((saved) => saved.id == expense.id);
    if (index >= 0) deletedExpenses.add(expenses.removeAt(index));
  }

  @override
  Future<void> restoreExpense(String userId, Expense expense) async {
    final index = deletedExpenses.indexWhere((saved) => saved.id == expense.id);
    if (index >= 0) expenses.insert(0, deletedExpenses.removeAt(index));
  }

  @override
  Future<void> permanentlyDeleteExpense(String userId, Expense expense) async {
    deletedExpenses.removeWhere((saved) => saved.id == expense.id);
  }
}

Widget _testApp(_FakeExpenseRepository repository) =>
    MyApp(authService: _FakeAuthService(), expenseRepository: repository);

void main() {
  testWidgets('expense rows fit common mobile widths', (
    WidgetTester tester,
  ) async {
    for (final width in [375.0, 430.0]) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      await tester.pumpWidget(_testApp(_FakeExpenseRepository()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Mobile expense',
      );
      await tester.enterText(find.byType(TextFormField).at(1), '100');
      await tester.tap(find.text('Category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Transport').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Expense').last);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Width: $width');
      expect(find.text('Mobile expense'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('keeps expenses after the app is restarted', (
    WidgetTester tester,
  ) async {
    final repository = _FakeExpenseRepository();
    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Groceries');
    await tester.enterText(find.byType(TextFormField).at(1), '250');
    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Expense').last);
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('₹250.00'), findsNWidgets(2));
  });

  testWidgets('adds and deletes an expense from the dashboard', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp(_FakeExpenseRepository()));
    await tester.pumpAndSettle();

    expect(find.text('My Expenses'), findsOneWidget);
    expect(find.text('₹0.00'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Metro');
    await tester.enterText(find.byType(TextFormField).at(1), '600');
    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transport').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Expense').last);
    await tester.pumpAndSettle();

    expect(find.text('Metro'), findsOneWidget);
    expect(find.text('₹600.00'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Delete expense'));
    await tester.pumpAndSettle();

    expect(find.text('Metro'), findsNothing);
    expect(find.text('₹0.00'), findsOneWidget);

    await tester.tap(find.byTooltip('Recycle bin'));
    await tester.pumpAndSettle();
    expect(find.text('Metro'), findsOneWidget);
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(find.text('Recycle Bin is empty'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Metro'), findsOneWidget);
    expect(find.text('₹600.00'), findsNWidgets(2));
  });

  testWidgets('restores a deleted expense from the bin on mobile', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 800));
    final repository = _FakeExpenseRepository()
      ..deletedExpenses.add(
        Expense(
          id: 'deleted-expense',
          title: 'Grocery',
          amount: 350,
          category: 'Food',
        ),
      );

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Recycle bin'));
    await tester.pumpAndSettle();

    expect(find.text('Grocery'), findsOneWidget);
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(find.text('Recycle Bin is empty'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Grocery'), findsOneWidget);
    expect(repository.deletedExpenses, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('permanently deletes a selected item from the recycle bin', (
    WidgetTester tester,
  ) async {
    final repository = _FakeExpenseRepository()
      ..deletedExpenses.add(
        Expense(
          id: 'deleted-expense',
          title: 'Old expense',
          amount: 120,
          category: 'Other',
        ),
      );
    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Recycle bin'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete permanently'));
    await tester.pumpAndSettle();
    expect(find.text('Delete permanently?'), findsOneWidget);
    await tester.tap(find.text('Delete permanently').last);
    await tester.pumpAndSettle();

    expect(repository.deletedExpenses, isEmpty);
    expect(find.text('Recycle Bin is empty'), findsOneWidget);
  });

  testWidgets('editing an expense keeps its original date and time', (
    WidgetTester tester,
  ) async {
    final createdAt = DateTime(2024, 1, 2, 15, 4);
    final repository = _FakeExpenseRepository()
      ..expenses.add(
        Expense(
          id: 'existing-expense',
          title: 'Coffee',
          amount: 80,
          category: 'Food',
          createdAt: createdAt,
        ),
      );

    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('02 Jan 2024 · 3:04 PM'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit expense'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Expense'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Coffee beans');
    await tester.enterText(find.byType(TextFormField).at(1), '120');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Coffee beans'), findsOneWidget);
    expect(find.text('₹120.00'), findsNWidgets(2));
    expect(find.text('02 Jan 2024 · 3:04 PM'), findsOneWidget);
    expect(repository.expenses.single.createdAt, createdAt);
  });
}
