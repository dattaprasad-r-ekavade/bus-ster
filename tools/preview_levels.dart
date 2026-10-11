import 'dart:io';

import 'package:busster/game/game_model.dart';
import 'package:busster/game/level_bundle.dart';

Future<void> main(List<String> args) async {
  if (args.length > 2) {
    stderr.writeln(
      'Usage: dart run tools/preview_levels.dart [input.json] [output.html]',
    );
    exitCode = 64;
    return;
  }

  final inputPath = args.isEmpty ? 'assets/levels/levels.json' : args[0];
  final outputPath = args.length < 2 ? 'build/level-preview.html' : args[1];
  final levels = LevelBundleCodec.decode(await File(inputPath).readAsString());
  final cards = <String>[];
  var failures = 0;

  for (final level in levels) {
    final solution = LevelSolver.findSolution(level);
    if (solution == null) failures++;
    cards.add(_levelCard(level, solution));
  }

  final output = File(outputPath);
  await output.parent.create(recursive: true);
  await output.writeAsString(_document(cards), flush: true);
  stdout.writeln('Wrote ${output.path} with ${levels.length} level previews.');
  if (failures > 0) {
    stderr.writeln('$failures levels have no solver path.');
    exitCode = 1;
  }
}

String _levelCard(LevelSpec level, List<String>? solution) {
  final initial = BoardState.initial(level);
  final legalOpeners = level.buses
      .where((bus) => GameRules.routeToExit(level, initial, bus.id) != null)
      .length;
  final junctions = level.roads.where((road) {
    final neighbors = road.neighbors.where(level.roads.contains).length;
    return neighbors >= 3;
  }).length;
  final roads = level.roads;
  final buses = {for (final bus in level.buses) bus.position: bus};
  final cells = StringBuffer();
  for (var y = 0; y < level.height; y++) {
    for (var x = 0; x < level.width; x++) {
      final point = GridPoint(x, y);
      final bus = buses[point];
      if (bus != null) {
        final color = _color(bus.route.colorValue);
        cells.write(
          '<div class="cell road bus" style="--route:$color">'
          '<b>${_escape(bus.route.symbol)}</b><small>${_escape(bus.id)}</small></div>',
        );
      } else if (point == level.exit) {
        cells.write('<div class="cell road exit">EXIT</div>');
      } else if (roads.contains(point)) {
        cells.write('<div class="cell road"></div>');
      } else {
        cells.write('<div class="cell yard"></div>');
      }
    }
  }
  final queue = level.passengers.map((route) {
    final color = _color(route.colorValue);
    return '<span class="chip" style="--route:$color">'
        '${_escape(route.symbol)} ${_escape(route.label)}</span>';
  }).join();
  final tags = level.mechanicTags
      .map((tag) => '<span class="tag">${_escape(tag)}</span>')
      .join();
  final route = solution == null
      ? 'No solution found within the solver limit.'
      : solution.map(_escape).join(' → ');

  return '''
<article class="level">
  <header><div><p class="eyebrow">${_escape(level.id)} · ${_escape(level.difficultyBand)}</p>
  <h2>${_escape(level.title)}</h2></div><span class="bays">${level.bayCount} bays</span></header>
  <p class="prompt">${_escape(level.tutorialPrompt)}</p>
  <div class="board" style="--columns:${level.width}">$cells</div>
  <h3>Rider queue</h3><div class="queue">$queue</div>
  <div class="tags">$tags</div>
  <dl><div><dt>Solver moves</dt><dd>${solution?.length ?? '—'}</dd></div>
  <div><dt>Legal opening buses</dt><dd>$legalOpeners</dd></div>
  <div><dt>Road junctions</dt><dd>$junctions</dd></div></dl>
  <p class="solution"><strong>Solver route:</strong> $route</p>
</article>''';
}

String _document(List<String> cards) => '''
<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Bus-ster level preview</title>
<style>
:root{color-scheme:dark;font:16px/1.45 system-ui,sans-serif;background:#101a2a;color:#edf3fb}
body{max-width:1200px;margin:auto;padding:28px 18px 60px}
h1{margin:0 0 8px;color:#ffc857} .note{color:#a9b8cc;margin:0 0 24px}
.levels{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:18px}
.level{background:#1b2940;border:1px solid #34445d;border-radius:18px;padding:18px;min-width:0}
header{display:flex;justify-content:space-between;gap:12px;align-items:start}
h2{font-size:1.25rem;margin:2px 0 8px}.eyebrow{font-size:.76rem;color:#a9b8cc;text-transform:uppercase;letter-spacing:.09em;margin:0}
.bays,.tag{border-radius:99px;background:#2b3b54;padding:4px 9px;color:#d7e5f7;font-size:.75rem;white-space:nowrap}
.prompt{min-height:2.8em;color:#d2dcea}.board{display:grid;grid-template-columns:repeat(var(--columns),minmax(0,1fr));gap:4px;aspect-ratio:1;margin:16px auto;max-width:340px;background:#131f31;padding:8px;border-radius:14px}
.cell{display:flex;align-items:center;justify-content:center;border-radius:7px;min-width:0;overflow:hidden}
.road{background:#34445b}.yard{background:#1b2940;border:1px solid #2a3950}
.exit{color:#ffc857;font-weight:800;font-size:.7rem;border:2px solid #ffc857}
.bus{background:color-mix(in srgb,var(--route) 22%,#34445b);border:2px solid var(--route);flex-direction:column;gap:1px}
.bus b{font-size:1.15rem;color:var(--route)}.bus small{font-size:.52rem;color:#fff}
h3{font-size:.9rem;margin:14px 0 6px}.queue,.tags{display:flex;flex-wrap:wrap;gap:6px}
.chip{background:color-mix(in srgb,var(--route) 22%,#24344b);border:1px solid var(--route);color:#fff;border-radius:99px;padding:4px 8px;font-size:.75rem}
.tags{margin-top:12px}.tag{background:#29384f}dl{display:flex;gap:12px;margin:14px 0 8px}dl div{flex:1;background:#152238;border-radius:9px;padding:8px}dt{font-size:.65rem;color:#a9b8cc}dd{margin:2px 0 0;font-weight:700}
.solution{font-size:.8rem;color:#becce0;overflow-wrap:anywhere}
</style></head><body><h1>Bus-ster level preview</h1>
<p class="note">Generated from the versioned level JSON. Solver metrics are structural checks; they do not replace human playtests.</p>
<main class="levels">${cards.join('\n')}</main></body></html>''';

String _color(int colorValue) =>
    '#${colorValue.toRadixString(16).padLeft(8, '0').substring(2)}';

String _escape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
