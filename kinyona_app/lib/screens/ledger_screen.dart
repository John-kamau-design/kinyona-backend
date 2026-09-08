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
  List<dynamic> _payouts = [];
  bool _isLoading = true;
  String _errorMessage = '';

  final String payoutUrl =
      "https://kinyona-backend.onrender.com/api/v1/payouts/generate/";

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
      final String? token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse(payoutUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token != null ? 'Bearer $token' : '',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _payouts = data is List ? data : (data['results'] ?? []);
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to fetch ledger (${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection failed. Check network or server.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_errorMessage),
                  const SizedBox(height: 12),
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
                itemCount: _payouts.length,
                itemBuilder: (context, index) {
                  final item = _payouts[index];
                  return ListTile(
                    leading: const Icon(Icons.receipt_long, color: Colors.teal),
                    title: Text(
                      'Batch #${item['batch_id'] ?? item['id'] ?? index + 1}',
                    ),
                    subtitle: Text(
                      'Amount: KES ${item['total_amount'] ?? '0.00'}',
                    ),
                    trailing: Text(item['status'] ?? 'PENDING'),
                  );
                },
              ),
            ),
    );
  }
}
