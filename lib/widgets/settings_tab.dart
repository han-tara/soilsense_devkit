import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/home_screen.dart'; // Import BulbSettings

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Consumer<BulbSettings>(
        builder: (context, bulbSettings, child) {
          return DropdownButton<String>(
            value: bulbSettings.bulbState,
            items: ['on', 'off'].map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text('Built in bulb: $value'),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                bulbSettings.bulbState = newValue;
              }
            },
          );
        },
      ),
    );
  }
}
