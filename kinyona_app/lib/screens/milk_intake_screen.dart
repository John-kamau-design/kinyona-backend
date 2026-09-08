import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MilkIntakeScreen extends StatefulWidget {
  const MilkIntakeScreen({super.key});

  @override
  State<MilkIntakeScreen> createState() => _MilkIntakeScreenState();
}

class _MilkIntakeScreenState extends State<MilkIntakeScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _farmerIdController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

  String _selectedSession = 'MORNING';
  bool _isSubmitting = false;

  final String syncUrl =
      "https://kinyona-backend.onrender.com/api/v1/intake/sync/";

  Future<void> _submitIntake() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('jwt_token');

      final response = await http.post(
        Uri.parse(syncUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token != null ? 'Bearer $token' : '',
        },
        body: jsonEncode({
          'farmer_id': _farmerIdController.text.trim(),
          'quantity_liters': double.parse(_quantityController.text.trim()),
          'session': _selectedSession,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Milk intake logged successfully!')),
        );
        _farmerIdController.clear();
        _quantityController.clear();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to log intake (${response.statusCode})'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network error. Check server connectivity.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _farmerIdController,
              decoration: const InputDecoration(
                labelText: 'Farmer ID / Username',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Please enter Farmer ID' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _quantityController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Quantity (Liters)',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Please enter quantity' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedSession,
              decoration: const InputDecoration(
                labelText: 'Session',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'MORNING', child: Text('Morning')),
                DropdownMenuItem(value: 'EVENING', child: Text('Evening')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedSession = val);
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitIntake,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Submit Intake', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
