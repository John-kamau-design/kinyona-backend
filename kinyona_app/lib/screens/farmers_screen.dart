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
  List<dynamic> _farmers = [];
  bool _isLoading = true;
  String _errorMessage = '';

  final String farmersUrl =
      "https://kinyona-backend.onrender.com/api/v1/auth/farmers/";

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
      final String? token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse(farmersUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token != null ? 'Bearer $token' : '',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _farmers = data is List ? data : (data['results'] ?? []);
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load farmers (${response.statusCode})';
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
                    onPressed: _fetchFarmers,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchFarmers,
              child: ListView.builder(
                itemCount: _farmers.length,
                itemBuilder: (context, index) {
                  final farmer = _farmers[index];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(
                      farmer['username'] ?? farmer['first_name'] ?? 'Farmer',
                    ),
                    subtitle: Text(
                      farmer['phone_number'] ??
                          farmer['email'] ??
                          'No contact info',
                    ),
                  );
                },
              ),
            ),
    );
  }
}
