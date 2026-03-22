import 'package:flutter/material.dart';
import '../widgets/item_card.dart';
import '../services/api_services.dart';
import '../models/academic_models.dart';
import '../models/dashboard_models.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<AcademicItem>> _focusItems;

  @override
  void initState() {
    super.initState();
    _focusItems = BackendService.fetchUnifiedDashboard().then((data) {
      final parsed = UnifiedDashboardData.fromJson(data);
      return parsed.focus;
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _focusItems = BackendService.fetchUnifiedDashboard().then((data) {
        final parsed = UnifiedDashboardData.fromJson(data);
        return parsed.focus;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UniDash'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Focus Today',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              FutureBuilder<List<AcademicItem>>(
                future: _focusItems,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 120,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }
                  final items = snapshot.data ?? [];
                  final top = items.take(3).toList();
                  if (top.isEmpty) {
                    return const Text('No high-priority items.');
                  }
                  return Column(
                    children: top
                        .map((it) => ItemCard.fromAcademic(item: it))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Upcoming',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              // Render upcoming items provided by backend (flattened groups)
              FutureBuilder<Map<String, dynamic>>(
                future: BackendService.fetchUnifiedDashboard(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 80,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) return const SizedBox.shrink();
                  final data = snapshot.data ?? {};
                  final parsed = UnifiedDashboardData.fromJson(data);
                  final flattened = <AcademicItem>[];
                  for (final key in [
                    'ASSIGNMENT',
                    'EXAM',
                    'ACADEMIC_ADMIN',
                    'OPPORTUNITY',
                    'INFORMATION',
                  ]) {
                    flattened.addAll(parsed.grouped[key] ?? []);
                  }
                  return Column(
                    children: flattened
                        .map((it) => ItemCard.fromAcademic(item: it))
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
