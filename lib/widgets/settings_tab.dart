import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/home_screen.dart'; // Import BulbSettings and CaptureDataNotifier

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Consumer<BulbSettings>(
        builder: (context, bulbSettings, child) {
          return Consumer<CaptureDataNotifier>(
            builder: (context, captureDataNotifier, child) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 10.0), // Horizontal 20, Vertical 10
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Acquisition',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Use bulb',
                          style: TextStyle(fontSize: 16),
                        ),
                        Switch(
                          value: bulbSettings.bulbState == 'on',
                          onChanged: (bool newValue) {
                            bulbSettings.bulbState = newValue ? 'on' : 'off';
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    SizedBox(
                      width: double
                          .infinity, // Makes the button take the full width
                      child: ElevatedButton(
                        onPressed: () {
                          captureDataNotifier.resetCaptures();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Captured data reset')),
                          );
                        },
                        child: const Text('Reset Captured Data'),
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
