import 'package:mini_program_ui/mini_program_ui.dart';

import '../weather_actions.dart';
import '../weather_theme.dart';
import '../weather_widgets.dart';

MpNode buildWeatherSearch() {
  return Mp.stateScope(
    prefix: 'weather.search',
    clearOnDispose: true,
    child: Mp.initialize(
      actions: initializeWeatherSearch(),
      loading: weatherMessage('Opening location search'),
      error: weatherMessage(
        'Location search is unavailable',
        color: weatherCoral,
      ),
      statusState: 'weather.search.startup_status',
      errorState: 'weather.search.startup_error',
      child: Mp.container(
        backgroundColor: weatherBackground,
        child: Mp.safeArea(
          child: Mp.scrollView(
            paddingHorizontal: 18,
            paddingTop: 12,
            paddingBottom: 28,
            child: Mp.center(
              child: Mp.container(
                width: 520,
                child: Mp.column(
                  children: <MpNode>[
                    _searchHeader(),
                    Mp.sizedBox(height: 18),
                    Mp.searchField(
                      stateKey: 'weather.search.query',
                      label: 'Search location',
                      hint: 'Dhaka or another city',
                      initialValue: '',
                      maxLength: 256,
                      debounce: const Duration(milliseconds: 300),
                      onChanged: searchWeatherLocations(),
                      onSubmitted: searchWeatherLocations(),
                      showClearButton: true,
                    ),
                    Mp.sizedBox(height: 12),
                    _currentLocationControl(),
                    Mp.sizedBox(height: 18),
                    _localResults(),
                    Mp.sizedBox(height: 14),
                    _globalFallback(),
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

MpNode _currentLocationControl() {
  return Mp.stateBuilder(
    keys: const <String>[
      'weather.search.location_status',
      'weather.search.location_error',
    ],
    child: Mp.container(
      backgroundColor: weatherSurface,
      borderColor: weatherSurfaceStrong,
      borderWidth: 1,
      borderRadius: 8,
      child: Mp.column(
        children: <MpNode>[
          Mp.listTile(
            title: 'Use current location',
            subtitle:
                'Approximate device location - {{state.weather.search.location_status}}',
            leadingIcon: 'location',
            trailingIcon: 'chevronRight',
            action: useCurrentWeatherLocation(),
          ),
          Mp.text(
            '{{state.weather.search.location_error.message}}',
            color: weatherCoral,
            size: 12,
            align: 'center',
            maxLines: 2,
            overflow: 'ellipsis',
          ),
        ],
      ),
    ),
  );
}

MpNode _searchHeader() {
  return Mp.row(
    children: <MpNode>[
      Mp.iconButton(
        'arrowBack',
        semanticLabel: 'Back to forecast',
        action: Mp.router.pop(),
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
              'Find a location',
              color: weatherText,
              size: 22,
              weight: 'semibold',
            ),
            Mp.text(
              'Bangladesh first, global fallback',
              color: weatherMuted,
              size: 12,
            ),
          ],
        ),
      ),
    ],
  );
}

MpNode _localResults() {
  return Mp.stateBuilder(
    keys: const <String>[
      'weather.search.thana',
      'weather.search.upazila',
      'weather.search.use_remote',
    ],
    child: Mp.condition(
      condition: '{{state.weather.search.use_remote}}',
      whenTrue: Mp.sizedBox(height: 1),
      whenFalse: Mp.column(
        children: <MpNode>[
          weatherSectionTitle(
            'Bangladesh locations',
            trailing: '{{state.weather.search.local_count}} matches',
          ),
          Mp.sizedBox(height: 10),
          Mp.repeat(
            source: '{{state.weather.search.thana.items}}',
            spacing: 8,
            limit: 8,
            itemTemplate: weatherLocationResult(local: true),
          ),
          Mp.repeat(
            source: '{{state.weather.search.upazila.items}}',
            spacing: 8,
            limit: 8,
            itemTemplate: weatherLocationResult(local: true),
          ),
        ],
      ),
    ),
  );
}

MpNode _globalFallback() {
  return Mp.stateBuilder(
    keys: const <String>['weather.search.use_remote'],
    child: Mp.condition(
      condition: '{{state.weather.search.use_remote}}',
      whenTrue: Mp.column(
        children: <MpNode>[
          weatherSectionTitle('Global results', trailing: 'Open-Meteo'),
          Mp.sizedBox(height: 10),
          Mp.backendBuilder(
            requestId: weatherGeocodingRequest,
            endpoint: 'geocoding',
            method: 'POST',
            body: const <String, Object?>{
              'query': '{{state.weather.search.query}}',
              'count': 10,
            },
            cacheTtlSeconds: 86400,
            loading: weatherMessage('Searching global locations'),
            error: Mp.emptyState(
              title: 'Global search unavailable',
              message: 'Bangladesh search remains available offline.',
              icon: 'public',
            ),
            empty: Mp.emptyState(
              title: 'No global matches',
              message: 'Try a city name with at least two letters.',
              icon: 'search',
            ),
            child: Mp.repeat(
              source: '{{backend.weather_geocoding.data.results}}',
              spacing: 8,
              limit: 10,
              itemTemplate: weatherLocationResult(local: false),
            ),
          ),
        ],
      ),
      whenFalse: Mp.sizedBox(height: 1),
    ),
  );
}
