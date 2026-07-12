import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'mini_program/mini_program.dart';
import 'mini_program/mini_program_endpoints.dart';
import 'mini_program/mini_program_registry.dart';

const _calculatorEndpointOverride = String.fromEnvironment(
  'MINI_PROGRAM_CALCULATOR_URL',
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
  if (_calculatorEndpointOverride.trim().isEmpty) {
    return endpoints;
  }

  final current = endpoints[MiniPrograms.calculator.appId]!;
  endpoints[MiniPrograms.calculator.appId] = MiniProgramEndpoint.public(
    apiBaseUri: Uri.parse(_calculatorEndpointOverride),
    headers: current.headers,
    requestTimeout: current.requestTimeout,
    enableLocalLoopbackFallback: current.enableLocalLoopbackFallback,
    backend: current.backend,
    cachePolicy: current.cachePolicy,
    liveStatePolicy: current.liveStatePolicy,
  );
  return endpoints;
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
          Material(
            color: const Color(0xFF1D1D1D),
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => openAppMiniProgram<void>(
                context,
                appId: MiniPrograms.calculator.appId,
                title: MiniPrograms.calculator.title,
                options: const MiniProgramLaunchOptions(
                  showAppBar: false,
                  backgroundColor: Colors.black,
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: <Widget>[
                    _CalculatorMark(),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Calculator',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Offline math, memory and saved history',
                            style: TextStyle(color: Color(0xFFAAAAAA)),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalculatorMark extends StatelessWidget {
  const _CalculatorMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFFF5258),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.calculate_outlined, color: Colors.white),
    );
  }
}
