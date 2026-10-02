
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const StudentExpenseApp());
}

class Expense {
  final String id;
  final String title;
  final String category;
  final double amount;
  final DateTime date;

  Expense({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'amount': amount,
      'date': date.toIso8601String(),
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'],
      title: json['title'],
      category: json['category'],
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date']),
    );
  }
}

class StudentExpenseApp extends StatelessWidget {
  const StudentExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Student Expense Tracker',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F5FA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6558D3),
        ),
        fontFamily: 'Roboto',
      ),
      home: const ExpenseHomePage(),
    );
  }
}

class ExpenseHomePage extends StatefulWidget {
  const ExpenseHomePage({super.key});

  @override
  State<ExpenseHomePage> createState() => _ExpenseHomePageState();
}

class _ExpenseHomePageState extends State<ExpenseHomePage> {
  final List<Expense> expenses = [];
  final double monthlyBudget = 10000;

  bool isLoading = true;

  final List<String> categories = [
    'Food',
    'Transport',
    'Shopping',
    'Education',
    'Entertainment',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    loadExpenses();
  }

  Future<void> loadExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString('student_expenses');

    if (savedData != null) {
      final List<dynamic> decodedData = jsonDecode(savedData);

      expenses
        ..clear()
        ..addAll(
          decodedData.map(
            (item) => Expense.fromJson(item),
          ),
        );
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> saveExpenses() async {
    final prefs = await SharedPreferences.getInstance();

    final encodedData = jsonEncode(
      expenses.map((expense) => expense.toJson()).toList(),
    );

    await prefs.setString('student_expenses', encodedData);
  }

  double get totalSpent {
    final now = DateTime.now();

    return expenses
        .where(
          (expense) =>
              expense.date.month == now.month &&
              expense.date.year == now.year,
        )
        .fold(0, (total, expense) => total + expense.amount);
  }

  double get remainingBudget {
    return monthlyBudget - totalSpent;
  }

  Map<String, double> get categoryTotals {
    final Map<String, double> totals = {};

    for (final category in categories) {
      totals[category] = 0;
    }

    final now = DateTime.now();

    for (final expense in expenses) {
      if (expense.date.month == now.month &&
          expense.date.year == now.year) {
        totals[expense.category] =
            (totals[expense.category] ?? 0) + expense.amount;
      }
    }

    return totals;
  }

  Future<void> addExpense(Expense expense) async {
    setState(() {
      expenses.insert(0, expense);
    });

    await saveExpenses();
  }

  Future<void> deleteExpense(String id) async {
    setState(() {
      expenses.removeWhere((expense) => expense.id == id);
    });

    await saveExpenses();
  }

  String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  void showAddExpenseDialog() {
    final titleController = TextEditingController();
    final amountController = TextEditingController();

    String selectedCategory = categories.first;
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Add an expense',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Expense name',
                        hintText: 'e.g. Lunch',
                        prefixIcon: Icon(Icons.edit_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount (₹)',
                        hintText: 'e.g. 150',
                        prefixIcon: Icon(Icons.currency_rupee),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.category_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedCategory = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(formatDate(selectedDate)),
                      onPressed: () async {
                        final pickedDate = await showDatePicker(
                          context: dialogContext,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );

                        if (pickedDate != null) {
                          setDialogState(() {
                            selectedDate = pickedDate;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final amount =
                        double.tryParse(amountController.text.trim());

                    if (title.isEmpty || amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Enter a name and a valid amount.',
                          ),
                        ),
                      );
                      return;
                    }

                    final expense = Expense(
                      id: DateTime.now()
                          .microsecondsSinceEpoch
                          .toString(),
                      title: title,
                      category: selectedCategory,
                      amount: amount,
                      date: selectedDate,
                    );

                    Navigator.pop(dialogContext);
                    await addExpense(expense);
                  },
                  child: const Text('Save expense'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  IconData categoryIcon(String category) {
    switch (category) {
      case 'Food':
        return Icons.restaurant_outlined;
      case 'Transport':
        return Icons.directions_bus_outlined;
      case 'Shopping':
        return Icons.shopping_bag_outlined;
      case 'Education':
        return Icons.menu_book_outlined;
      case 'Entertainment':
        return Icons.movie_outlined;
      default:
        return Icons.more_horiz;
    }
  }

  Color categoryColor(String category) {
    switch (category) {
      case 'Food':
        return const Color(0xFFFF9F68);
      case 'Transport':
        return const Color(0xFF5C9DED);
      case 'Shopping':
        return const Color(0xFFB18AE0);
      case 'Education':
        return const Color(0xFF50B99A);
      case 'Entertainment':
        return const Color(0xFFE879A9);
      default:
        return const Color(0xFF8D91A3);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F5FA),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PennyWise',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF29243D),
              ),
            ),
            Text(
              'Your student spending companion',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundColor: const Color(0xFFE7E2FA),
              child: const Icon(
                Icons.person_outline,
                color: Color(0xFF6558D3),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: showAddExpenseDialog,
        backgroundColor: const Color(0xFF6558D3),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add expense'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const Text(
                        'Your finances, at a glance',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF29243D),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Keep track of where your money goes.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 650;
                          final cardWidth = isWide
                              ? (constraints.maxWidth - 24) / 3
                              : constraints.maxWidth;

                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: cardWidth,
                                child: SummaryCard(
                                  title: 'Spent this month',
                                  amount: totalSpent,
                                  icon: Icons.account_balance_wallet_outlined,
                                  color: const Color(0xFF6558D3),
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: SummaryCard(
                                  title: 'Remaining budget',
                                  amount: remainingBudget,
                                  icon: Icons.savings_outlined,
                                  color: const Color(0xFF279B79),
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: SummaryCard(
                                  title: 'Monthly budget',
                                  amount: monthlyBudget,
                                  icon: Icons.calendar_month_outlined,
                                  color: const Color(0xFFE39A3B),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      buildSectionTitle('Spending by category'),
                      const SizedBox(height: 12),
                      buildCategoryCard(),
                      const SizedBox(height: 24),
                      buildSectionTitle('Recent expenses'),
                      const SizedBox(height: 12),
                      buildExpenseHistory(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF29243D),
      ),
    );
  }

  Widget buildCategoryCard() {
    final totals = categoryTotals;
    final maxAmount = totals.values.fold<double>(
      0,
      (currentMax, value) => value > currentMax ? value : currentMax,
    );

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: categories.map((category) {
            final amount = totals[category] ?? 0;
            final progress =
                maxAmount == 0 ? 0.0 : amount / maxAmount;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        categoryIcon(category),
                        color: categoryColor(category),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          category,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '₹${amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 7,
                      backgroundColor: const Color(0xFFF0EFF5),
                      color: categoryColor(category),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget buildExpenseHistory() {
    if (expenses.isEmpty) {
      return Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 42,
                color: Color(0xFFAAA6BB),
              ),
              SizedBox(height: 12),
              Text(
                'No expenses yet',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Tap “Add expense” to record your first expense.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: expenses.take(10).map((expense) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  categoryColor(expense.category).withOpacity(0.15),
              child: Icon(
                categoryIcon(expense.category),
                color: categoryColor(expense.category),
              ),
            ),
            title: Text(
              expense.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${expense.category} • ${formatDate(expense.date)}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '₹${expense.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      deleteExpense(expense.id);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final IconData icon;
  final Color color;

  const SummaryCard({
    super.key,
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '₹${amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF29243D),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}