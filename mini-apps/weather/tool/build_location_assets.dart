import 'dart:convert';
import 'dart:io';

const _thanaSource =
    'https://raw.githubusercontent.com/mehedi8603651/'
    'bangladesh-geocode-all-area/main/bangladesh_thana_area.json';
const _upazilaSource =
    'https://raw.githubusercontent.com/mehedi8603651/'
    'bangladesh-geocode-all-area/main/bangladesh_upzila_area.json';

Future<void> main() async {
  final outputDirectory = Directory('assets/data');
  await outputDirectory.create(recursive: true);

  final thanaRoot = await _downloadJson(_thanaSource);
  final upazilaRoot = await _downloadJson(_upazilaSource);
  final thanaLocations = _flattenThanaLocations(thanaRoot);
  final upazilaLocations = _flattenUpazilaLocations(upazilaRoot);

  await _writeIndex(
    File('${outputDirectory.path}/bangladesh_thana_area.json'),
    source: _thanaSource,
    locations: thanaLocations,
  );
  await _writeIndex(
    File('${outputDirectory.path}/bangladesh_upzila_area.json'),
    source: _upazilaSource,
    locations: upazilaLocations,
  );

  stdout.writeln('Thana and area locations: ${thanaLocations.length}');
  stdout.writeln('Upazila and union locations: ${upazilaLocations.length}');
}

Future<Map<String, dynamic>> _downloadJson(String url) async {
  final client = HttpClient()..userAgent = 'mini-app-store-weather-builder/1.0';
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Location source returned HTTP ${response.statusCode}.',
        uri: Uri.parse(url),
      );
    }
    final body = await response.transform(utf8.decoder).join();
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException('Location source root must be an object.');
    }
    return Map<String, dynamic>.from(decoded);
  } finally {
    client.close(force: true);
  }
}

List<Map<String, Object?>> _flattenThanaLocations(Map<String, dynamic> root) {
  final locations = <Map<String, Object?>>[];
  final divisions = _namedChildren(_map(_map(root['Bangladesh'])['divisions']));
  for (final division in divisions) {
    final divisionName = division.key;
    final divisionValue = division.value;
    _addLocation(
      locations,
      name: divisionName,
      kind: 'Division',
      division: divisionName,
      value: divisionValue,
    );
    for (final district in _namedChildren(_map(divisionValue['districts']))) {
      final districtName = district.key;
      final districtValue = district.value;
      _addLocation(
        locations,
        name: districtName,
        kind: 'District',
        division: divisionName,
        district: districtName,
        value: districtValue,
      );
      for (final thana in _namedChildren(_map(districtValue['thanas']))) {
        final thanaName = thana.key;
        final thanaValue = thana.value;
        _addLocation(
          locations,
          name: thanaName,
          kind: 'Thana',
          division: divisionName,
          district: districtName,
          parent: districtName,
          value: thanaValue,
        );
        for (final area in _namedChildren(_map(thanaValue['areas']))) {
          _addLocation(
            locations,
            name: area.key,
            kind: 'Area',
            division: divisionName,
            district: districtName,
            parent: thanaName,
            value: area.value,
          );
        }
      }
    }
  }
  return locations;
}

List<Map<String, Object?>> _flattenUpazilaLocations(Map<String, dynamic> root) {
  final locations = <Map<String, Object?>>[];
  final divisions = _namedChildren(_map(_map(root['Bangladesh'])['divisions']));
  for (final division in divisions) {
    final divisionName = division.key;
    for (final district in _namedChildren(_map(division.value['districts']))) {
      final districtName = district.key;
      for (final upazila in _namedChildren(_map(district.value['upazilas']))) {
        final upazilaName = upazila.key;
        final upazilaValue = upazila.value;
        _addLocation(
          locations,
          name: upazilaName,
          kind: 'Upazila',
          division: divisionName,
          district: districtName,
          parent: districtName,
          value: upazilaValue,
        );
        for (final union in _namedChildren(_map(upazilaValue['unions']))) {
          _addLocation(
            locations,
            name: union.key,
            kind: 'Union',
            division: divisionName,
            district: districtName,
            parent: upazilaName,
            value: union.value,
          );
        }
      }
    }
  }
  return locations;
}

void _addLocation(
  List<Map<String, Object?>> output, {
  required String name,
  required String kind,
  required String division,
  required Map<String, dynamic> value,
  String? district,
  String? parent,
}) {
  final latitude = value['lat'];
  final longitude = value['lon'];
  if (latitude is! num || longitude is! num) {
    return;
  }
  final hierarchy = <String>[
    if (parent != null && parent != name) parent,
    if (district != null && district != name && district != parent) district,
    if (division != name && division != district) division,
    'Bangladesh',
  ];
  output.add(<String, Object?>{
    'name': name,
    'kind': kind,
    'division': division,
    if (district != null) 'district': district,
    if (parent != null) 'parent': parent,
    'latitude': latitude,
    'longitude': longitude,
    'subtitle': '$kind - ${hierarchy.join(', ')}',
  });
}

List<MapEntry<String, Map<String, dynamic>>> _namedChildren(
  Map<String, dynamic> map,
) {
  final entries = map.entries
      .map((entry) => MapEntry(entry.key, _map(entry.value)))
      .toList();
  entries.sort((left, right) => left.key.compareTo(right.key));
  return entries;
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) {
    return const <String, dynamic>{};
  }
  return Map<String, dynamic>.from(value);
}

Future<void> _writeIndex(
  File file, {
  required String source,
  required List<Map<String, Object?>> locations,
}) async {
  final document = <String, Object?>{
    'schemaVersion': 1,
    'source': source,
    'country': 'Bangladesh',
    'locations': locations,
  };
  await file.writeAsString(jsonEncode(document), flush: true);
}
