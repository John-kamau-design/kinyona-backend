import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  final String ledgerUrl =
      "https://kinyona-backend.onrender.com/api/v1/payouts/generate/";
  final String creditIssueUrl =
      "https://kinyona-backend.onrender.com/api/v1/agrovet/issue/";

  List<dynamic> _transactions = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchLedger();
  }

  Future<void> _fetchLedger() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';

      final response = await http.get(
        Uri.parse(ledgerUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _transactions = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to fetch ledger (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network connection error';
        _isLoading = false;
      });
    }
  }

  void _showIssueAgrovetCreditDialog() {
    final formKey = GlobalKey<FormState>();
    final memberIdController = TextEditingController();
    final amountController = TextEditingController();
    final itemController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> submitCredit() async {
              if (!formKey.currentState!.validate()) return;
              setModalState(() => isSubmitting = true);

              try {
                final prefs = await SharedPreferences.getInstance();
                final token = prefs.getString('jwt_token') ?? '';

                final response = await http.post(
                  Uri.parse(creditIssueUrl),
                  headers: {
                    'Content-Type': 'application/json',
                    if (token.isNotEmpty) 'Authorization': 'Bearer $token',
                  },
                  body: jsonEncode({
                    'member_id': memberIdController.text.trim(),
                    'amount_kes': double.parse(amountController.text.trim()),
                    'item_description': itemController.text.trim(),
                  }),
                );

                if (response.statusCode == 201 || response.statusCode == 200) {
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  _fetchLedger();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Agrovet credit issued successfully!'),
                    ),
                  );
                } else {
                  setModalState(() => isSubmitting = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: ${response.statusCode}')),
                  );
                }
              } catch (e) {
                setModalState(() => isSubmitting = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Submission error')),
                );
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Issue Agrovet Store Credit',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: memberIdController,
                      decoration: const InputDecoration(
                        labelText: 'Farmer Member ID',
                        prefixIcon: Icon(Icons.badge),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: itemController,
                      decoration: const InputDecoration(
                        labelText: 'Item Description (e.g., Feed, Fertilizer)',
                        prefixIcon: Icon(Icons.shopping_bag),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount (KES)',
                        prefixIcon: Icon(Icons.payments),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: isSubmitting ? null : submitCredit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('ISSUE DEDUCTION CREDIT'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showIssueAgrovetCreditDialog,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Issue Credit'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_errorMessage),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _fetchLedger,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchLedger,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _transactions.length,
                itemBuilder: (context, index) {
                  final item = _transactions[index];
                  final bool isDeduction =
                      item['type'] == 'AGROVET_CREDIT' ||
                      item['is_deduction'] == true;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isDeduction
                            ? Colors.orange.shade100
                            : Colors.green.shade100,
                        child: Icon(
                          isDeduction
                              ? Icons.shopping_basket
                              : Icons.attach_money,
                          color: isDeduction
                              ? Colors.orange.shade800
                              : Colors.green.shade800,
                        ),
                      ),
                      title: Text(
                        item['farmer_name'] ??
                            'Member #${item['member_id'] ?? 'N/A'}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${item['description'] ?? (isDeduction ? 'Agrovet Purchase' : 'Milk Payout')}\nDate: ${item['created_at'] ?? 'Today'}',
                      ),
                      isThreeLine: true,
                      trailing: Text(
                        '${isDeduction ? '-' : '+'} KES ${item['amount_kes']}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDeduction
                              ? Colors.orange.shade900
                              : Colors.green.shade900,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
