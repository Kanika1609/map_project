import 'package:flutter/material.dart';
import 'app_config.dart';

class ServerSwitch extends StatefulWidget {
  final VoidCallback? onChanged;

  const ServerSwitch({super.key, this.onChanged});

  @override
  State<ServerSwitch> createState() => _ServerSwitchState();
}

class _ServerSwitchState extends State<ServerSwitch> {
  late bool _isMaps;

  @override
  void initState() {
    super.initState();
    _isMaps = AppConfig.selectedServer == server.maps;
  }

  void _onToggle(bool value) {
    setState(() {
      _isMaps = value;
      AppConfig.setBaseUrl(value ? server.maps : server.dev);
    });
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Dev',
          style: TextStyle(
            fontWeight: _isMaps ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        Switch(
          value: _isMaps,
          onChanged: _onToggle,
        ),
        Text(
          'Maps',
          style: TextStyle(
            fontWeight: _isMaps ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}