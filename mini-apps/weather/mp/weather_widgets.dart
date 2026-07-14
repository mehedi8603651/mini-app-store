import 'package:mini_program_ui/mini_program_ui.dart';

import 'weather_actions.dart';
import 'weather_theme.dart';

MpNode weatherConditionIcon(
  String root, {
  num size = 56,
  String semanticLabel = 'Weather condition',
}) {
  MpNode icon(String name, String color) =>
      Mp.icon(name, size: size, color: color, semanticLabel: semanticLabel);

  return Mp.condition(
    condition: '{{$root.isStorm}}',
    whenTrue: icon('thunderstorm', weatherCoral),
    whenFalse: Mp.condition(
      condition: '{{$root.isSnow}}',
      whenTrue: icon('snow', weatherCyan),
      whenFalse: Mp.condition(
        condition: '{{$root.isRain}}',
        whenTrue: icon('rain', weatherBlue),
        whenFalse: Mp.condition(
          condition: '{{$root.isFog}}',
          whenTrue: icon('fog', weatherMuted),
          whenFalse: Mp.condition(
            condition: '{{$root.isCloudy}}',
            whenTrue: icon('cloudy', weatherText),
            whenFalse: icon('sunny', weatherYellow),
          ),
        ),
      ),
    ),
  );
}

MpNode weatherMetric({
  required String icon,
  required String value,
  required String label,
  required String color,
}) {
  return Mp.column(
    children: <MpNode>[
      Mp.icon(icon, semanticLabel: label, color: color, size: 24),
      Mp.sizedBox(height: 8),
      Mp.text(
        value,
        color: weatherText,
        size: 17,
        weight: 'semibold',
        align: 'center',
        maxLines: 1,
        overflow: 'ellipsis',
      ),
      Mp.sizedBox(height: 3),
      Mp.text(label, color: weatherMuted, size: 11, align: 'center'),
    ],
  );
}

MpNode weatherLocationResult({required bool local}) {
  return Mp.container(
    backgroundColor: weatherSurface,
    borderColor: weatherSurfaceStrong,
    borderWidth: 1,
    borderRadius: 8,
    child: Mp.listTile(
      title: '{{item.name}}',
      subtitle: '{{item.subtitle}}',
      leadingIcon: 'location',
      trailingIcon: 'chevronRight',
      action: selectWeatherLocation(local: local),
    ),
  );
}
