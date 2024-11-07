import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/acquisition_tab.dart';
import '../widgets/models_tab.dart';
import '../widgets/settings_tab.dart';

// Define BulbSettings as a ChangeNotifier to manage shared state
class BulbSettings extends ChangeNotifier {
  String _bulbState;

  BulbSettings({String bulbState = 'off'}) : _bulbState = bulbState;

  String get bulbState => _bulbState;

  set bulbState(String value) {
    if (_bulbState != value) {
      _bulbState = value;
      notifyListeners();
    }
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<BulbSettings>(
      create: (_) => BulbSettings(),
      child: DefaultTabController(
        length: 3,
        initialIndex: 1, // Default to 'acquisition' tab
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: const CustomAppBar(),
          body: const TabBarView(
            children: [
              // Models Tab
              ModelsTab(),
              // Acquisition Tab
              AcquisitionTab(),
              // Settings Tab
              SettingsTab(),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom AppBar Widget with TabBar
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({Key? key}) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(130.0);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 80,
      title: Row(
        children: [
          // Title and Subtitle
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'SoilSense DevKit',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Beta Version 1.3 (not the final version)',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          // User Picture
          const CircleAvatar(
            backgroundColor: Colors.grey,
            radius: 20,
            child: Icon(
              Icons.person,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
      bottom: const TabBar(
        tabs: [
          Tab(icon: Icon(Icons.storage)), // Icon for 'models'
          Tab(icon: Icon(Icons.sensors)), // Icon for 'acquisition'
          Tab(icon: Icon(Icons.settings)), // Icon for 'settings'
        ],
      ),
    );
  }
}
