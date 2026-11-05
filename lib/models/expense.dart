class Expense {
  final String? id;
  final String title;
  final double amount;
  final String category;
  final DateTime createdAt;

  Expense({
    this.id,
    required this.title,
    required this.amount,
    required this.category,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, Object> toJson() => {
    'title': title,
    'amount': amount,
    'category': category,
    'createdAt': createdAt.toIso8601String(),
  };

  Expense copyWith({
    String? id,
    String? title,
    double? amount,
    String? category,
    DateTime? createdAt,
  }) => Expense(
    id: id ?? this.id,
    title: title ?? this.title,
    amount: amount ?? this.amount,
    category: category ?? this.category,
    createdAt: createdAt ?? this.createdAt,
  );

  factory Expense.fromJson(Map<String, dynamic> json, {String? id}) {
    final title = json['title'];
    final amount = json['amount'];
    final category = json['category'];
    final savedCreatedAt = json['createdAt'];
    final createdAt = switch (savedCreatedAt) {
      DateTime dateTime => dateTime,
      String value => DateTime.tryParse(value),
      null => null,
      _ => null,
    };

    if (title is! String || amount is! num || category is! String) {
      throw const FormatException('Invalid saved expense data.');
    }
    if (savedCreatedAt != null && createdAt == null) {
      throw const FormatException('Invalid saved expense creation date.');
    }

    return Expense(
      id: id,
      title: title,
      amount: amount.toDouble(),
      category: category,
      createdAt: createdAt,
    );
  }
}
