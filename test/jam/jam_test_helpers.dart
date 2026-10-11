import 'package:busster/jam/jam_model.dart';

JamVehicle bus(
  String id,
  JamColor color,
  JamFacing facing,
  int x,
  int y, {
  int length = 2,
  int? capacity,
}) => JamVehicle(
  id: id,
  color: color,
  facing: facing,
  head: JamCell(x, y),
  length: length,
  capacity: capacity,
);

List<JamColor> crowd(List<(JamColor, int)> groups) => [
  for (final (color, count) in groups) ...List.filled(count, color),
];

const red = JamColor.red;
const blue = JamColor.blue;
const green = JamColor.green;
const yellow = JamColor.yellow;
const purple = JamColor.purple;
const orange = JamColor.orange;

const up = JamFacing.up;
const right = JamFacing.right;
const down = JamFacing.down;
const left = JamFacing.left;

/// Three free buses in a row on a 3x2 lot, all facing up.
JamLevel rowLevel({
  required int bays,
  required List<JamColor> passengers,
  List<(String, JamColor, int)> buses = const [
    ('r1', red, 4),
    ('b1', blue, 4),
    ('g1', green, 4),
  ],
}) => JamLevel(
  id: 'row',
  width: buses.length,
  height: 2,
  bayCount: bays,
  vehicles: [
    for (var i = 0; i < buses.length; i++)
      bus(buses[i].$1, buses[i].$2, up, i, 0, capacity: buses[i].$3),
  ],
  passengers: passengers,
);
