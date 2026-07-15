import 'package:flutter/widgets.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

import 'mini_program_registry.dart';

Future<T?> openAppMiniProgram<T>(
  BuildContext context, {
  required String appId,
  String? title,
  Map<String, dynamic>? initialData,
  String? version,
  Uri? source,
  MiniProgramLaunchOptions options = const MiniProgramLaunchOptions(),
}) {
  return MiniProgramScope.of(context).openMiniProgram<T>(
    appId: appId,
    title: title,
    initialData: initialData,
    version: version,
    source: source,
    options: options,
  );
}

Future<T?> openRegisteredMiniProgram<T>(
  BuildContext context,
  MiniProgramInfo miniProgram, {
  Map<String, dynamic>? initialData,
  String? version,
  Uri? source,
  MiniProgramLaunchOptions options = const MiniProgramLaunchOptions(),
}) {
  return openAppMiniProgram<T>(
    context,
    appId: miniProgram.appId,
    title: miniProgram.title,
    initialData: initialData,
    version: version,
    source: source,
    options: options,
  );
}

class AppMiniProgramLauncher extends StatelessWidget {
  const AppMiniProgramLauncher({
    super.key,
    required this.appId,
    required this.child,
    this.title,
    this.initialData,
    this.version,
    this.source,
    this.options = const MiniProgramLaunchOptions(),
  });

  final String appId;
  final Widget child;
  final String? title;
  final Map<String, dynamic>? initialData;
  final String? version;
  final Uri? source;
  final MiniProgramLaunchOptions options;

  @override
  Widget build(BuildContext context) {
    return MiniProgramLauncher(
      appId: appId,
      title: title,
      initialData: initialData,
      version: version,
      source: source,
      options: options,
      child: child,
    );
  }
}

class RegisteredMiniProgramLauncher extends StatelessWidget {
  const RegisteredMiniProgramLauncher({
    super.key,
    required this.miniProgram,
    required this.child,
    this.initialData,
    this.version,
    this.source,
    this.options = const MiniProgramLaunchOptions(),
  });

  final MiniProgramInfo miniProgram;
  final Widget child;
  final Map<String, dynamic>? initialData;
  final String? version;
  final Uri? source;
  final MiniProgramLaunchOptions options;

  @override
  Widget build(BuildContext context) {
    return MiniProgramLauncher(
      appId: miniProgram.appId,
      title: miniProgram.title,
      initialData: initialData,
      version: version,
      source: source,
      options: options,
      child: child,
    );
  }
}
