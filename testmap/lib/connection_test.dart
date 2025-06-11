import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ConnectionTest extends StatefulWidget {
  @override
  _ConnectionTestState createState() => _ConnectionTestState();
}

class _ConnectionTestState extends State<ConnectionTest> {
  String connectionStatus = 'Testing connection...';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    testConnection();
  }

  Future<void> testConnection() async {
    setState(() {
      isLoading = true;
      connectionStatus = 'Testing connection...';
    });

    try {
      // Test basic server connection
      final response = await http.get(
        Uri.parse('http://10.194.7.35:8080'),
        headers: {'Accept': 'application/json'},
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          connectionStatus = '✅ Server accessible! Status: ${response.statusCode}';
        });

        // Test tile endpoint
        await testTileEndpoint();
      } else {
        setState(() {
          connectionStatus = '⚠️ Server responded with status: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        connectionStatus = '❌ Connection failed: $e\n\nTroubleshooting:\n• Check if TileServer GL is running\n• Verify IP address: 10.194.7.35\n• Check port 8080 is open';
      });
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> testTileEndpoint() async {
    try {
      // Test a sample tile
      final tileResponse = await http.get(
        Uri.parse('http://10.194.7.35:8080/data/combined_with_layers/0/0/0.pbf'),
      ).timeout(Duration(seconds: 10));

      setState(() {
        connectionStatus += '\n✅ Tile endpoint status: ${tileResponse.statusCode}';
        if (tileResponse.statusCode == 200) {
          connectionStatus += '\n📊 Tile data size: ${tileResponse.bodyBytes.length} bytes';
          connectionStatus += '\n🎉 Ready to display map!';
        }
      });
    } catch (e) {
      setState(() {
        connectionStatus += '\n⚠️ Tile test failed: $e';
        connectionStatus += '\n\nCheck if MBTiles file "combined_with_layers" exists in TileServer GL';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Connection Test'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TileServer GL Configuration',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('Server URL: http://10.194.7.35:8080'),
                    Text('MBTiles: combined_with_layers'),
                    Text('Format: Vector tiles (.pbf)'),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Connection Status',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (isLoading) ...[
                          SizedBox(width: 10),
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        connectionStatus,
                        style: TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: isLoading ? null : () {
                      testConnection();
                    },
                    child: Text('Test Again'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      _showTroubleshootingDialog();
                    },
                    child: Text('Help'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTroubleshootingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Troubleshooting'),
        content: SingleChildScrollView(
          child: Text(
              'Common Issues:\n\n'
                  '1. TileServer GL not running:\n'
                  '   • Start TileServer GL with your MBTiles\n'
                  '   • Check console for any errors\n\n'
                  '2. Network connection:\n'
                  '   • Ensure device/emulator can reach 10.194.7.35\n'
                  '   • For Android emulator, try 10.0.2.2 instead\n\n'
                  '3. Firewall/Port issues:\n'
                  '   • Check if port 8080 is open\n'
                  '   • Disable firewall temporarily to test\n\n'
                  '4. MBTiles file:\n'
                  '   • Verify "combined_with_layers.mbtiles" exists\n'
                  '   • Check file permissions\n\n'
                  '5. IP Address:\n'
                  '   • Verify 10.194.7.35 is correct\n'
                  '   • Use ipconfig/ifconfig to double-check'
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}