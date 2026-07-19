import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mini_program/mini_program.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF090909),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final miniProgramConfig = await buildHostMiniProgramConfig();

  runApp(
    MiniProgramScope(
      config: miniProgramConfig,
      child: const MiniAppStoreHost(),
    ),
  );
}

class MiniAppStoreHost extends StatelessWidget {
  const MiniAppStoreHost({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mini App Store',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF5258),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF101010),
        useMaterial3: true,
      ),
      home: const MiniAppCatalogPage(),
    );
  }
}

class MiniAppCatalogPage extends StatelessWidget {
  const MiniAppCatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mini App Store'),
        backgroundColor: const Color(0xFF101010),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _MiniProgramCatalogTile(
            app: MiniPrograms.calculator,
            description: 'Offline math, memory and saved history',
            icon: Icons.calculate_outlined,
            iconBackground: const Color(0xFFFF5258),
            launchBackground: Colors.black,
          ),
          const SizedBox(height: 12),
          _MiniProgramCatalogTile(
            app: MiniPrograms.brainTest,
            description: 'Timed true-or-false arithmetic challenges',
            icon: Icons.psychology_alt_outlined,
            iconBackground: const Color(0xFFFFD84A),
            iconForeground: const Color(0xFF10131A),
            launchBackground: const Color(0xFF10131A),
          ),
          const SizedBox(height: 12),
          _MiniProgramCatalogTile(
            app: MiniPrograms.notepad,
            description: 'Private offline notes saved on this device',
            icon: Icons.note_alt_outlined,
            iconBackground: const Color(0xFF8BA779),
            launchBackground: Colors.black,
          ),
          const SizedBox(height: 12),
          _MiniProgramCatalogTile(
            app: MiniPrograms.weather,
            description: 'Bangladesh locations and 7-day global forecasts',
            icon: Icons.cloud_outlined,
            iconBackground: const Color(0xFF00D6D2),
            iconForeground: const Color(0xFF10131A),
            launchBackground: const Color(0xFF10151E),
          ),
        ],
      ),
    );
  }
}

class _MiniProgramCatalogTile extends StatelessWidget {
  const _MiniProgramCatalogTile({
    required this.app,
    required this.description,
    required this.icon,
    required this.iconBackground,
    required this.launchBackground,
    this.iconForeground = Colors.white,
  });

  final MiniProgramInfo app;
  final String description;
  final IconData icon;
  final Color iconBackground;
  final Color iconForeground;
  final Color launchBackground;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1D1D1D),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openRegisteredMiniProgram<void>(
          context,
          app,
          options: MiniProgramLaunchOptions(
            showAppBar: false,
            backgroundColor: launchBackground,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconForeground),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      app.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: const TextStyle(color: Color(0xFFAAAAAA)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
