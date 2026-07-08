import 'package:flutter/material.dart';
import 'package:rni_project_app/models/building.dart';
import 'package:rni_project_app/services/api_service.dart';
import 'package:rni_project_app/ble_home.dart';
import '../server_switch.dart';

class BuildingSelectScreen extends StatefulWidget {
  const BuildingSelectScreen({super.key});

  @override
  State<BuildingSelectScreen> createState() => _BuildingSelectScreenState();
}

class _BuildingSelectScreenState extends State<BuildingSelectScreen> {
  late Future<List<Building>> _futureBuildings;

  @override
  void initState() {
    super.initState();
    _futureBuildings = ApiService.fetchBuildings();
  }

  void _retry() {
    setState(() {
      _futureBuildings = ApiService.fetchBuildings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Building"),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ServerSwitch(onChanged: _retry),
          ),
        ],
      ),
      body: FutureBuilder<List<Building>>(
        future: _futureBuildings,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load buildings.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _retry, child: const Text('Retry')),
                  ],
                ),
              ),
            );
          }

          final buildings = snapshot.data ?? [];
          if (buildings.isEmpty) {
            return const Center(child: Text('No buildings found for this API key.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: buildings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final b = buildings[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.apartment),
                  title: Text(b.name),
                  subtitle: Text(b.venueName),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    print('TAPPED BUILDING: name=${b.name}, venueName=${b.venueName}, id=${b.id}');
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BLEHome(venueName: b.venueName, buildingId: b.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}