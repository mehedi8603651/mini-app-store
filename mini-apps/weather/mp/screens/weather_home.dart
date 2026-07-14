import 'package:mini_program_ui/mini_program_ui.dart';

import '../weather_actions.dart';
import '../weather_theme.dart';
import '../weather_widgets.dart';

MpNode buildWeatherHome() {
  return Mp.refreshIndicator(
    action: refreshWeather(forceRefresh: true),
    semanticsLabel: 'Refresh weather forecast',
    child: Mp.initialize(
      actions: initializeWeather(),
      loading: weatherMessage('Preparing Bangladesh locations'),
      error: weatherMessage(
        'Weather resources could not be prepared',
        color: weatherCoral,
      ),
      statusState: 'weather.startup_status',
      errorState: 'weather.startup_error',
      retry: 1,
      child: Mp.container(
        backgroundColor: weatherBackground,
        child: Mp.safeArea(
          child: Mp.padding(
            horizontal: 18,
            top: 12,
            bottom: 28,
            child: Mp.center(
              child: Mp.container(
                width: 520,
                child: Mp.column(
                  children: <MpNode>[
                    _weatherHeader(),
                    Mp.sizedBox(height: 18),
                    _forecastBuilder(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

MpNode _weatherHeader() {
  return Mp.stateBuilder(
    keys: const <String>['weather.location'],
    child: Mp.row(
      children: <MpNode>[
        Mp.iconButton(
          'search',
          semanticLabel: 'Search location',
          action: Mp.router.push('weather_search'),
          size: 46,
          iconSize: 24,
          color: weatherText,
          backgroundColor: weatherSurface,
          borderColor: weatherSurfaceStrong,
          borderWidth: 1,
          borderRadius: 8,
        ),
        Mp.sizedBox(width: 12),
        Mp.expanded(
          child: Mp.column(
            children: <MpNode>[
              Mp.text(
                '{{state.weather.location.name}}',
                color: weatherText,
                size: 20,
                weight: 'semibold',
                align: 'center',
                maxLines: 1,
                overflow: 'ellipsis',
              ),
              Mp.text(
                '{{state.weather.location.country}}',
                color: weatherMuted,
                size: 12,
                align: 'center',
                maxLines: 1,
                overflow: 'ellipsis',
              ),
            ],
          ),
        ),
        Mp.sizedBox(width: 12),
        Mp.iconButton(
          'refresh',
          semanticLabel: 'Refresh weather',
          action: refreshWeather(forceRefresh: true),
          size: 46,
          iconSize: 24,
          color: weatherCyan,
          backgroundColor: weatherSurface,
          borderColor: weatherSurfaceStrong,
          borderWidth: 1,
          borderRadius: 8,
        ),
      ],
    ),
  );
}

MpNode _forecastBuilder() {
  return Mp.backendBuilder(
    requestId: weatherForecastRequest,
    endpoint: 'forecast',
    method: 'POST',
    body: const <String, Object?>{
      'latitude': '{{state.weather.location.latitude}}',
      'longitude': '{{state.weather.location.longitude}}',
      'locationName': '{{state.weather.location.name}}',
    },
    cacheTtlSeconds: 600,
    loading: _forecastLoading(),
    error: _forecastError(),
    empty: _forecastError(),
    child: _forecastContent(),
  );
}

MpNode _forecastLoading() {
  return Mp.column(
    children: <MpNode>[
      Mp.skeleton.box(height: 250, radius: 8),
      Mp.sizedBox(height: 16),
      Mp.skeleton.box(height: 180, radius: 8),
    ],
  );
}

MpNode _forecastError() {
  return Mp.container(
    paddingHorizontal: 24,
    paddingVertical: 32,
    backgroundColor: weatherSurface,
    borderColor: weatherSurfaceStrong,
    borderWidth: 1,
    borderRadius: 8,
    child: Mp.column(
      children: <MpNode>[
        Mp.icon(
          'cloudy',
          semanticLabel: 'Forecast unavailable',
          size: 56,
          color: weatherCoral,
        ),
        Mp.sizedBox(height: 16),
        Mp.text(
          'Forecast unavailable',
          color: weatherText,
          size: 21,
          weight: 'semibold',
          align: 'center',
        ),
        Mp.sizedBox(height: 8),
        Mp.text(
          '{{backend.weather_forecast.message}}',
          color: weatherMuted,
          size: 14,
          align: 'center',
          maxLines: 4,
          overflow: 'ellipsis',
        ),
        Mp.sizedBox(height: 6),
        Mp.text(
          'Error: {{backend.weather_forecast.errorCode}}',
          color: weatherCoral,
          size: 12,
          align: 'center',
          maxLines: 2,
          overflow: 'ellipsis',
        ),
        Mp.sizedBox(height: 20),
        Mp.button(
          label: 'Retry',
          action: refreshWeather(forceRefresh: true),
          height: 48,
          backgroundColor: weatherCyan,
          foregroundColor: weatherBackground,
          borderColor: weatherCyan,
          borderRadius: 8,
          fontSize: 16,
          fontWeight: 'semibold',
        ),
      ],
    ),
  );
}

MpNode _forecastContent() {
  return Mp.column(
    children: <MpNode>[
      _currentConditions(),
      Mp.sizedBox(height: 18),
      _metricBand(),
      Mp.sizedBox(height: 24),
      weatherSectionTitle('Temperature', trailing: 'Next 24 hours'),
      Mp.sizedBox(height: 10),
      Mp.container(
        paddingHorizontal: 10,
        paddingVertical: 14,
        backgroundColor: weatherSurface,
        borderColor: weatherSurfaceStrong,
        borderWidth: 1,
        borderRadius: 8,
        child: Mp.lineChart(
          source: '{{backend.weather_forecast.data.hourly}}',
          valueField: 'temperature',
          labelField: 'timeLabel',
          height: 210,
          unit: '°C',
          color: weatherYellow,
          curved: true,
          showPoints: true,
          showGrid: true,
          showArea: true,
          maxPoints: 24,
          semanticLabel: 'Hourly temperature forecast',
          empty: weatherMessage('Hourly chart is unavailable'),
        ),
      ),
      Mp.sizedBox(height: 24),
      weatherSectionTitle('7-day forecast'),
      Mp.sizedBox(height: 10),
      Mp.repeat(
        source: '{{backend.weather_forecast.data.daily}}',
        direction: 'horizontal',
        height: 168,
        spacing: 10,
        limit: 7,
        itemTemplate: _dailyCard(),
      ),
      Mp.sizedBox(height: 24),
      weatherSectionTitle('Hourly details'),
      Mp.sizedBox(height: 10),
      Mp.repeat(
        source: '{{backend.weather_forecast.data.hourly}}',
        direction: 'horizontal',
        height: 154,
        spacing: 10,
        limit: 24,
        itemTemplate: _hourlyCard(),
      ),
      Mp.sizedBox(height: 18),
      Mp.text(
        'Weather data by Open-Meteo',
        color: weatherMuted,
        size: 11,
        align: 'center',
      ),
    ],
  );
}

MpNode _currentConditions() {
  const current = 'backend.weather_forecast.data.current';
  return Mp.container(
    height: 246,
    paddingHorizontal: 18,
    paddingVertical: 18,
    backgroundColor: weatherSurface,
    borderColor: weatherSurfaceStrong,
    borderWidth: 1,
    borderRadius: 8,
    child: Mp.column(
      children: <MpNode>[
        Mp.text(
          '{{$current.condition}}',
          color: weatherText,
          size: 18,
          weight: 'medium',
          align: 'center',
        ),
        Mp.spacer(),
        Mp.row(
          children: <MpNode>[
            Mp.expanded(
              child: weatherConditionIcon(
                current,
                size: 92,
                semanticLabel: 'Current weather',
              ),
            ),
            Mp.expanded(
              child: Mp.column(
                children: <MpNode>[
                  Mp.text(
                    '{{$current.temperatureRounded}}°',
                    color: weatherText,
                    size: 66,
                    weight: 'bold',
                    align: 'center',
                    maxLines: 1,
                    overflow: 'ellipsis',
                  ),
                  Mp.text(
                    'Feels like {{$current.apparentTemperatureRounded}}°',
                    color: weatherMuted,
                    size: 13,
                    align: 'center',
                  ),
                ],
              ),
            ),
          ],
        ),
        Mp.spacer(),
        Mp.text(
          '{{$current.dateLabel}}',
          color: weatherMuted,
          size: 13,
          align: 'center',
        ),
      ],
    ),
  );
}

MpNode _metricBand() {
  return Mp.container(
    paddingHorizontal: 12,
    paddingVertical: 16,
    backgroundColor: weatherSurfaceStrong,
    borderRadius: 8,
    child: Mp.row(
      children: <MpNode>[
        Mp.expanded(
          child: weatherMetric(
            icon: 'rain',
            value: '{{backend.weather_forecast.data.current.precipitation}} mm',
            label: 'Precipitation',
            color: weatherBlue,
          ),
        ),
        Mp.expanded(
          child: weatherMetric(
            icon: 'waterDrop',
            value: '{{backend.weather_forecast.data.current.humidity}}%',
            label: 'Humidity',
            color: weatherCyan,
          ),
        ),
        Mp.expanded(
          child: weatherMetric(
            icon: 'wind',
            value: '{{backend.weather_forecast.data.current.windSpeed}} km/h',
            label: 'Wind',
            color: weatherGreen,
          ),
        ),
      ],
    ),
  );
}

MpNode _dailyCard() {
  return Mp.container(
    width: 112,
    paddingHorizontal: 10,
    paddingVertical: 12,
    backgroundColor: weatherSurface,
    borderColor: weatherSurfaceStrong,
    borderWidth: 1,
    borderRadius: 8,
    child: Mp.column(
      children: <MpNode>[
        Mp.text(
          '{{item.dayLabel}}',
          color: weatherText,
          size: 14,
          weight: 'semibold',
          align: 'center',
        ),
        Mp.sizedBox(height: 10),
        weatherConditionIcon('item', size: 38),
        Mp.spacer(),
        Mp.text(
          '{{item.temperatureMaxRounded}}°  {{item.temperatureMinRounded}}°',
          color: weatherText,
          size: 14,
          align: 'center',
        ),
        Mp.text(
          '{{item.precipitationProbability}}% rain',
          color: weatherCyan,
          size: 10,
          align: 'center',
        ),
      ],
    ),
  );
}

MpNode _hourlyCard() {
  return Mp.container(
    width: 94,
    paddingHorizontal: 8,
    paddingVertical: 10,
    backgroundColor: weatherSurface,
    borderColor: weatherSurfaceStrong,
    borderWidth: 1,
    borderRadius: 8,
    child: Mp.column(
      children: <MpNode>[
        Mp.text(
          '{{item.timeLabel}}',
          color: weatherMuted,
          size: 12,
          align: 'center',
        ),
        Mp.sizedBox(height: 8),
        weatherConditionIcon('item', size: 30),
        Mp.spacer(),
        Mp.text(
          '{{item.temperatureRounded}}°',
          color: weatherText,
          size: 17,
          weight: 'semibold',
          align: 'center',
        ),
        Mp.text(
          '{{item.precipitationProbability}}%',
          color: weatherCyan,
          size: 10,
          align: 'center',
        ),
      ],
    ),
  );
}
