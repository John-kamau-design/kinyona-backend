import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FarmersScreen extends StatefulWidget {
  const FarmersScreen({super.key});

  @override
  State<FarmersScreen> createState() => _FarmersScreenState();
}

class _FarmersScreenState extends State<FarmersScreen> {
  final String farmersUrl =
      "https://kinyona-backend.onrender.com/api/v1/auth/farmers/";

  List<dynamic> _farmers = [];
  List<dynamic> _filteredFarmers = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchFarmers();
  }

  Future<void> _fetchFarmers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';

      final response = await http.get(
        Uri.parse(farmersUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _farmers = data;
          _filteredFarmers = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load farmers (${response.statusCode})';
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

  void _filterFarmers(String query) {
    setState(() {
      _filteredFarmers = _farmers.where((farmer) {
        final name = (farmer['full_name'] ?? farmer['name'] ?? '')
            .toString()
            .toLowerCase();
        final memberId = (farmer['member_id'] ?? farmer['id'] ?? '')
            .toString()
            .toLowerCase();
        final phone = (farmer['phone'] ?? '').toString();
        final q = query.toLowerCase();
        return name.contains(q) || memberId.contains(q) || phone.contains(q);
      }).toList();
    });
  }

  void _showAddFarmerDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final routeController = TextEditingController();
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
            Future<void> submitFarmer() async {
              if (!formKey.currentState!.validate()) return;
              setModalState(() => isSubmitting = true);

              try {
                final prefs = await SharedPreferences.getInstance();
                final token = prefs.getString('jwt_token') ?? '';

                final response = await http.post(
                  Uri.parse(farmersUrl),
                  headers: {
                    'Content-Type': 'application/json',
                    if (token.isNotEmpty) 'Authorization': 'Bearer $token',
                  },
                  body: jsonEncode({
                    'full_name': nameController.text.trim(),
                    'phone': phoneController.text.trim(),
                    'route': routeController.text.trim(),
                  }),
                );

                if (response.statusCode == 201 || response.statusCode == 200) {
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  _fetchFarmers();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Farmer registered successfully!'),
                    ),
                  );
                } else {
                  setModalState(() => isSubmitting = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${response.statusCode}')),
                  );
                }
              } catch (e) {
                setModalState(() => isSubmitting = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Submission failed')),
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
                      'Register New Farmer',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: routeController,
                      decoration: const InputDecoration(
                        labelText: 'Collection Route/Zone',
                        prefixIcon: Icon(Icons.alt_route),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: isSubmitting ? null : submitFarmer,
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
                          : const Text('REGISTER FARMER'),
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
        onPressed: _showAddFarmerDialog,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Farmer'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: _filterFarmers,
              decoration: InputDecoration(
                hintText: 'Search by name, Member ID, or phone...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterFarmers('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage.isNotEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_errorMessage),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _fetchFarmers,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchFarmers,
                      child: _filteredFarmers.isEmpty
                          ? const Center(child: Text('No farmers found'))
                          : ListView.builder(
                              itemCount: _filteredFarmers.length,
                              itemBuilder: (context, index) {
                                final farmer = _filteredFarmers[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.teal.shade100,
                                      child: Text(
                                        (farmer['full_name'] ??
                                                farmer['name'] ??
                                                'F')[0]
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.teal,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      farmer['full_name'] ??
                                          farmer['name'] ??
                                          'Unknown',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'ID: ${farmer['member_id'] ?? farmer['id']} | Phone: ${farmer['phone'] ?? 'N/A'}',
                                    ),
                                    trailing: Chip(
                                      label: Text(
                                        farmer['route'] ?? 'Main Route',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      backgroundColor: Colors.grey.shade200,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
