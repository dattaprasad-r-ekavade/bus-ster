// Driver for integration tests. Perf runs (integration_test/perf_test.dart)
// report timelines and FrameTiming stats; both are written to build/perf/.
//
//   flutter drive --profile --driver=test_driver/integration_test.dart \
//     --target=integration_test/perf_test.dart -d <device>
import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null) return;
    final dir = Directory('build/perf')..createSync(recursive: true);
    for (final entry in data.entries) {
      final value = entry.value;
      if (entry.key.startsWith('timeline_') && value is Map<String, dynamic>) {
        final timeline = driver.Timeline.fromJson(value);
        final summary = driver.TimelineSummary.summarize(timeline);
        await summary.writeTimelineToFile(
          entry.key,
          pretty: true,
          destinationDirectory: dir.path,
        );
      } else {
        File(
          '${dir.path}/${entry.key}.json',
        ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(value));
      }
    }
  },
);
