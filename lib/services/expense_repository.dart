import '../models/expense.dart';

abstract interface class ExpenseRepository {
  Future<List<Expense>> loadExpenses(String userId);

  Future<List<Expense>> loadDeletedExpenses(String userId);

  Future<Expense> addExpense(String userId, Expense expense);

  Future<void> updateExpense(String userId, Expense expense);

  Future<void> deleteExpense(String userId, Expense expense);

  Future<void> restoreExpense(String userId, Expense expense);

  Future<void> permanentlyDeleteExpense(String userId, Expense expense);
}
