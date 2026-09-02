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

  // Controllers
  final TextEditingController _farmerIdController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // State Variables
  String _selectedShift = 'MORNING';
  bool _isVerifyingFarmer = false;
  bool _isSubmitting = false;

  // Verified Farmer Data
  Map<String, dynamic>? _verifiedFarmer;
  String _verificationError = '';
  String _submissionStatusMessage = '';

  // Base API URL
  final String baseUrl = "https://kinyona-backend.onrender.com/api/v1";

  // Auto-Timestamp generator
  String get _currentFormattedTimestamp {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} "
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  /// 1. Verify Farmer ID with Django Backend
  Future<void> _verifyFarmerId() async {
    final farmerId = _farmerIdController.text.trim();
    if (farmerId.isEmpty) return;

    setState(() {
      _isVerifyingFarmer = true;
      _verificationError = '';
      _verifiedFarmer = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';

      final response = await http.get(
        Uri.parse('$baseUrl/farmers/$farmerId/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _verifiedFarmer = jsonDecode(response.body);
          _isVerifyingFarmer = false;
        });
      } else {
        setState(() {
          _verificationError = 'Farmer ID not found or inactive.';
          _isVerifyingFarmer = false;
        });
      }
    } catch (e) {
      setState(() {
        _verificationError = 'Network error during farmer lookup.';
        _isVerifyingFarmer = false;
      });
    }
  }

  /// 2. Submit Immutable Milk Intake Log
  Future<void> _submitIntakeRecord() async {
    if (!_formKey.currentState!.validate() || _verifiedFarmer == null) return;

    setState(() {
      _isSubmitting = true;
      _submissionStatusMessage = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';
      final loggedInUser = prefs.getString('username') ?? 'Field Collector';

      final payload = {
        'farmer_id': _verifiedFarmer!['id'] ?? _farmerIdController.text.trim(),
        'quantity_liters': double.parse(_quantityController.text),
        'shift': _selectedShift,
        'recorded_by': loggedInUser,
        'client_timestamp': DateTime.now().toIso8601String(),
        'notes': _notesController.text.trim(),
      };

      final response = await http.post(
        Uri.parse('$baseUrl/intake/sync/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Intake Logged: ${_quantityController.text}L for ${_verifiedFarmer!['name'] ?? 'Farmer'}',
            ),
            backgroundColor: Colors.green[700],
          ),
        );
        _resetForm();
      } else {
        setState(() {
          _submissionStatusMessage =
              'Server rejected record (${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _submissionStatusMessage =
            'Submission failed. Check network connection.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _resetForm() {
    _farmerIdController.clear();
    _quantityController.clear();
    _notesController.clear();
    setState(() {
      _verifiedFarmer = null;
      _verificationError = '';
      _submissionStatusMessage = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Milk Intake Session'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // SESSION METADATA BAR
              Card(
                color: Colors.teal.shade50,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.teal.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.access_time, color: Colors.teal),
                          const SizedBox(width: 8),
                          Text(
                            _currentFormattedTimestamp,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      DropdownButton<String>(
                        value: _selectedShift,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(
                            value: 'MORNING',
                            child: Text('Morning Shift'),
                          ),
                          DropdownMenuItem(
                            value: 'EVENING',
                            child: Text('Evening Shift'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedShift = val);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // FARMER VERIFICATION SECTION
              Text(
                '1. Farmer Verification',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _farmerIdController,
                      decoration: const InputDecoration(
                        labelText: 'Farmer Member No / Phone',
                        prefixIcon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.text,
                      onFieldSubmitted: (_) => _verifyFarmerId(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isVerifyingFarmer ? null : _verifyFarmerId,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 16,
                      ),
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    child: _isVerifyingFarmer
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('VERIFY'),
                  ),
                ],
              ),

              // VERIFIED FARMER CARD / ERROR
              if (_verificationError.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _verificationError,
                  style: const TextStyle(color: Colors.red),
                ),
              ],

              if (_verifiedFarmer != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _verifiedFarmer!['name'] ?? 'Verified Farmer',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Route: ${_verifiedFarmer!['route'] ?? 'Default Route'} | Code: ${_verifiedFarmer!['code'] ?? 'N/A'}',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // QUANTITY & INTAKE DETAILS
              Text(
                '2. Intake Details',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Volume (Liters)',
                  prefixIcon: Icon(Icons.opacity),
                  suffixText: 'L',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Enter recorded liters';
                  }
                  final parsed = double.tryParse(val);
                  if (parsed == null || parsed <= 0) {
                    return 'Enter a valid volume (> 0)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Audit Notes / Can ID (Optional)',
                  prefixIcon: Icon(Icons.note_alt_outlined),
                  border: OutlineInputBorder(),
                ),
              ),

              if (_submissionStatusMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  _submissionStatusMessage,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 24),

              // SUBMIT BUTTON
              ElevatedButton.icon(
                onPressed: (_verifiedFarmer == null || _isSubmitting)
                    ? null
                    : _submitIntakeRecord,
                icon: const Icon(Icons.save_alt),
                label: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'RECORD INTAKE',
                        style: TextStyle(fontSize: 16),
                      ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
