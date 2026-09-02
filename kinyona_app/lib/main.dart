import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Import your feature screens from lib/screens/
import 'package:kinyona_app/screens/milk_intake_screen.dart';
import 'package:kinyona_app/screens/farmers_screen.dart';
import 'package:kinyona_app/screens/ledger_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final String? token = prefs.getString('jwt_token');
  final String? role = prefs.getString('user_role');

  runApp(
    KinyonaApp(
      initialRoute: (token != null && role != null) ? 'home' : 'login',
      initialRole: role ?? 'MANAGER',
    ),
  );
}

class KinyonaApp extends StatelessWidget {
  final String initialRoute;
  final String initialRole;

  const KinyonaApp({
    super.key,
    required this.initialRoute,
    required this.initialRole,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kinyona Dairy & Agrovet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: initialRoute == 'home'
          ? MainNavigationHub(userRole: initialRole)
          : const LoginScreen(),
    );
  }
}

// ==========================================
// 1. AUTHENTICATION / LOGIN SCREEN
// ==========================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';

  final String loginUrl =
      "https://kinyona-backend.onrender.com/api/v1/auth/token/";

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse(loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _usernameController.text.trim(),
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String token = data['access'] ?? data['token'] ?? '';
        final String role = (data['role'] ?? 'MANAGER')
            .toString()
            .toUpperCase();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);
        await prefs.setString('user_role', role);
        await prefs.setString('username', _usernameController.text.trim());

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainNavigationHub(userRole: role),
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'Invalid credentials (${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection failed. Check network or server status.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.water_drop, size: 72, color: Colors.teal),
                  const SizedBox(height: 16),
                  const Text(
                    'Kinyona Dairy System',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to your station account',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username or Member ID',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Required' : null,
                  ),
                  if (_errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('LOG IN', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. DYNAMIC ROLE-BASED NAVIGATION HUB
// ==========================================
class MainNavigationHub extends StatefulWidget {
  final String userRole;

  const MainNavigationHub({super.key, required this.userRole});

  @override
  State<MainNavigationHub> createState() => _MainNavigationHubState();
}

class _MainNavigationHubState extends State<MainNavigationHub> {
  int _selectedIndex = 0;
  late List<NavigationDestinationItem> _navItems;

  @override
  void initState() {
    super.initState();
    _navItems = _buildNavForRole(widget.userRole);
  }

  List<NavigationDestinationItem> _buildNavForRole(String role) {
    switch (role) {
      case 'COLLECTOR':
        return [
          NavigationDestinationItem(
            screen: const MilkIntakeScreen(),
            label: 'Milk Intake',
            icon: Icons.water_drop_outlined,
            activeIcon: Icons.water_drop,
          ),
          NavigationDestinationItem(
            screen: const FarmersScreen(),
            label: 'Farmers',
            icon: Icons.people_outline,
            activeIcon: Icons.people,
          ),
        ];
      case 'AGROVET':
        return [
          NavigationDestinationItem(
            screen: const LedgerScreen(),
            label: 'Agrovet Credit',
            icon: Icons.store_outlined,
            activeIcon: Icons.store,
          ),
          NavigationDestinationItem(
            screen: const FarmersScreen(),
            label: 'Farmers',
            icon: Icons.people_outline,
            activeIcon: Icons.people,
          ),
        ];
      case 'FARMER':
        return [
          NavigationDestinationItem(
            screen: const DashboardScreen(),
            label: 'My Summary',
            icon: Icons.account_circle_outlined,
            activeIcon: Icons.account_circle,
          ),
        ];
      case 'MANAGER':
      default:
        return [
          NavigationDestinationItem(
            screen: const DashboardScreen(),
            label: 'Dashboard',
            icon: Icons.dashboard_outlined,
            activeIcon: Icons.dashboard,
          ),
          NavigationDestinationItem(
            screen: const MilkIntakeScreen(),
            label: 'Milk Intake',
            icon: Icons.water_drop_outlined,
            activeIcon: Icons.water_drop,
          ),
          NavigationDestinationItem(
            screen: const FarmersScreen(),
            label: 'Farmers',
            icon: Icons.people_outline,
            activeIcon: Icons.people,
          ),
          NavigationDestinationItem(
            screen: const LedgerScreen(),
            label: 'Ledger',
            icon: Icons.receipt_long_outlined,
            activeIcon: Icons.receipt_long,
          ),
        ];
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.userRole} Portal'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _navItems.map((item) => item.screen).toList(),
      ),
      bottomNavigationBar: _navItems.length > 1
          ? BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) => setState(() => _selectedIndex = index),
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Colors.teal,
              unselectedItemColor: Colors.grey[600],
              items: _navItems
                  .map(
                    (item) => BottomNavigationBarItem(
                      icon: Icon(item.icon),
                      activeIcon: Icon(item.activeIcon),
                      label: item.label,
                    ),
                  )
                  .toList(),
            )
          : null,
    );
  }
}

class NavigationDestinationItem {
  final Widget screen;
  final String label;
  final IconData icon;
  final IconData activeIcon;

  NavigationDestinationItem({
    required this.screen,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

// ==========================================
// 3. DASHBOARD MODULE SCREEN
// ==========================================
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final String apiUrl =
      "https://kinyona-backend.onrender.com/api/v1/dashboard/stats/";

  Map<String, dynamic>? dashboardData;
  bool isLoading = true;
  String errorMessage = "";

  @override
  void initState() {
    super.initState();
    fetchDashboardStats();
  }

  Future<void> fetchDashboardStats() async {
    setState(() {
      isLoading = true;
      errorMessage = "";
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          dashboardData = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = "Server error: ${response.statusCode}";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Could not connect to Django API backend.";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage.isNotEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    Text(errorMessage, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: fetchDashboardStats,
                      child: const Text('Retry Connection'),
                    ),
                  ],
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount = constraints.maxWidth > 800 ? 3 : 1;
                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 2.2,
                    children: [
                      _buildStatCard(
                        'Total Milk Collected Today',
                        '${dashboardData?['todays_liters_collected'] ?? 0} Liters',
                        Icons.local_shipping,
                        Colors.blue,
                      ),
                      _buildStatCard(
                        'Active Registered Farmers',
                        '${dashboardData?['total_active_farmers'] ?? 0}',
                        Icons.people,
                        Colors.green,
                      ),
                      _buildStatCard(
                        'Agrovet Credit Issued',
                        'KES ${dashboardData?['net_outstanding_agrovet_debt_kes'] ?? 0}',
                        Icons.store,
                        Colors.orange,
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
