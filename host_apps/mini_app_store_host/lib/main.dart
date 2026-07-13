import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'mini_program/mini_program.dart';
import 'mini_program/mini_program_endpoints.dart';
import 'mini_program/mini_program_registry.dart';

const _artifactEndpointOverride = String.fromEnvironment(
  'MINI_PROGRAM_ARTIFACT_URL',
  defaultValue: '',
);
const _calculatorEndpointOverride = String.fromEnvironment(
  'MINI_PROGRAM_CALCULATOR_URL',
  defaultValue: '',
);
const _brainTestEndpointOverride = String.fromEnvironment(
  'MINI_PROGRAM_BRAIN_TEST_URL',
  defaultValue: '',
);

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

  final supportDirectory = await getApplicationSupportDirectory();
  final cacheBundle = MiniProgramCacheBundle.fileBacked(
    rootDirectory: Directory(
      '${supportDirectory.path}${Platform.pathSeparator}mini_program_cache',
    ),
  );

  runApp(
    MiniProgramScope(
      config: buildMiniProgramConfig(
        endpoints: _buildEndpoints(),
        cacheBundle: cacheBundle,
      ),
      child: const MiniAppStoreHost(),
    ),
  );
}

Map<String, MiniProgramEndpoint> _buildEndpoints() {
  final endpoints = buildMiniProgramEndpoints();
  final sharedOverride = _artifactEndpointOverride.trim();
  _overrideEndpoint(
    endpoints,
    MiniPrograms.calculator.appId,
    _calculatorEndpointOverride.trim().isEmpty
        ? sharedOverride
        : _calculatorEndpointOverride.trim(),
  );
  _overrideEndpoint(
    endpoints,
    MiniPrograms.brainTest.appId,
    _brainTestEndpointOverride.trim().isEmpty
        ? sharedOverride
        : _brainTestEndpointOverride.trim(),
  );
  return endpoints;
}

void _overrideEndpoint(
  Map<String, MiniProgramEndpoint> endpoints,
  String appId,
  String override,
) {
  if (override.isEmpty) {
    return;
  }

  final current = endpoints[appId]!;
  endpoints[appId] = MiniProgramEndpoint.public(
    apiBaseUri: Uri.parse(override),
    headers: current.headers,
    requestTimeout: current.requestTimeout,
    enableLocalLoopbackFallback: current.enableLocalLoopbackFallback,
    backend: current.backend,
    cachePolicy: current.cachePolicy,
    liveStatePolicy: current.liveStatePolicy,
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
        onTap: () => openAppMiniProgram<void>(
          context,
          appId: app.appId,
          title: app.title,
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
