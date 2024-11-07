import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/capture_data_model.dart';
import '../widgets/models_tab.dart';
import '../widgets/acquisition_tab.dart';
import '../widgets/settings_tab.dart';

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

class CaptureDataNotifier extends ChangeNotifier {
  List<CaptureData> _captures = [];

  List<CaptureData> get captures => _captures;

  void addCapture(CaptureData capture) {
    _captures.add(capture);
    notifyListeners();
  }

  void resetCaptures() {
    _captures.clear();
    notifyListeners();
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<BulbSettings>(create: (_) => BulbSettings()),
        ChangeNotifierProvider<CaptureDataNotifier>(
            create: (_) => CaptureDataNotifier()),
      ],
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
                'Beta Version 1.5 (not the final version)',
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
