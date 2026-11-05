import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/expense.dart';
import 'expense_repository.dart';

const _legacyExpensesStorageKey = 'saved_expenses';

class FirestoreExpenseRepository implements ExpenseRepository {
  FirestoreExpenseRepository({
    FirebaseFirestore? firestore,
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  final FirebaseFirestore _firestore;
  final Future<SharedPreferences> Function() _preferencesLoader;

  CollectionReference<Map<String, dynamic>> _expensesFor(String userId) =>
      _firestore.collection('users').doc(userId).collection('expenses');

  DocumentReference<Map<String, dynamic>> _migrationFor(String userId) =>
      _firestore
          .collection('users')
          .doc(userId)
          .collection('metadata')
          .doc('local_expenses_migration');

  @override
  Future<List<Expense>> loadExpenses(String userId) async {
    return _withNetworkRetry(() async {
      await _migrateLocalExpenses(userId);
      final snapshot = await _expensesFor(
        userId,
      ).orderBy('createdAt', descending: true).get();

      return snapshot.docs
          .where((document) => document.data()['deletedAt'] == null)
          .map(_expenseFromDocument)
          .toList();
    });
  }

  @override
  Future<List<Expense>> loadDeletedExpenses(String userId) async {
    return _withNetworkRetry(() async {
      await _migrateLocalExpenses(userId);
      final snapshot = await _expensesFor(userId)
          .where('deletedAt', isNull: false)
          .orderBy('deletedAt', descending: true)
          .get();

      return snapshot.docs.map(_expenseFromDocument).toList();
    });
  }

  Expense _expenseFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final createdAt = data['createdAt'];
    return Expense.fromJson({
      ...data,
      if (createdAt is Timestamp) 'createdAt': createdAt.toDate(),
    }, id: document.id);
  }

  Future<T> _withNetworkRetry<T>(Future<T> Function() operation) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await operation();
      } on FirebaseException catch (error) {
        if (error.code != 'unavailable' || attempt >= 2) rethrow;

        await _firestore.enableNetwork();
        await Future<void>.delayed(Duration(seconds: attempt + 1));
      }
    }
  }

  Future<void> _migrateLocalExpenses(String userId) async {
    final preferences = await _preferencesLoader();
    final migrationReference = _migrationFor(userId);
    final migration = await migrationReference.get();

    if (migration.exists) {
      if (preferences.containsKey(_legacyExpensesStorageKey)) {
        await preferences.remove(_legacyExpensesStorageKey);
      }
      return;
    }

    final encodedExpenses = preferences.getString(_legacyExpensesStorageKey);
    final expenses = encodedExpenses == null
        ? <Expense>[]
        : (jsonDecode(encodedExpenses) as List<dynamic>)
              .map((entry) => Expense.fromJson(entry as Map<String, dynamic>))
              .toList();

    final collection = _expensesFor(userId);
    for (var start = 0; start < expenses.length; start += 450) {
      final batch = _firestore.batch();
      final end = (start + 450).clamp(0, expenses.length);
      for (var index = start; index < end; index++) {
        final expense = expenses[index];
        final documentId = 'legacy_${index.toString().padLeft(6, '0')}';
        batch.set(collection.doc(documentId), {
          ...expense.toJson(),
          'createdAt': Timestamp.fromDate(
            DateTime.now().subtract(Duration(microseconds: index)),
          ),
        });
      }
      await batch.commit();
    }

    await migrationReference.set({
      'completedAt': FieldValue.serverTimestamp(),
      'importedCount': expenses.length,
    });

    if (encodedExpenses != null) {
      await preferences.remove(_legacyExpensesStorageKey);
    }
  }

  @override
  Future<Expense> addExpense(String userId, Expense expense) async {
    final document = await _expensesFor(userId).add({
      ...expense.toJson(),
      'createdAt': Timestamp.fromDate(expense.createdAt),
    });
    return expense.copyWith(id: document.id);
  }

  @override
  Future<void> updateExpense(String userId, Expense expense) async {
    final id = expense.id;
    if (id == null) {
      throw StateError('Cannot update an expense without a Firestore ID.');
    }
    await _expensesFor(userId).doc(id).update({
      ...expense.toJson(),
      'createdAt': Timestamp.fromDate(expense.createdAt),
    });
  }

  @override
  Future<void> deleteExpense(String userId, Expense expense) async {
    final id = expense.id;
    if (id == null) {
      throw StateError('Cannot delete an expense without a Firestore ID.');
    }
    await _expensesFor(
      userId,
    ).doc(id).update({'deletedAt': FieldValue.serverTimestamp()});
  }

  @override
  Future<void> restoreExpense(String userId, Expense expense) async {
    final id = expense.id;
    if (id == null) {
      throw StateError('Cannot restore an expense without a Firestore ID.');
    }
    await _expensesFor(userId).doc(id).update({'deletedAt': null});
  }

  @override
  Future<void> permanentlyDeleteExpense(String userId, Expense expense) async {
    final id = expense.id;
    if (id == null) {
      throw StateError(
        'Cannot permanently delete an expense without a Firestore ID.',
      );
    }
    await _expensesFor(userId).doc(id).delete();
  }
}
