import 'game_model.dart';

GridPoint _p(int x, int y) => GridPoint(x, y);

List<GridPoint> _spine() => [_p(2, 0), _p(2, 1), _p(2, 2), _p(2, 3), _p(2, 4)];

List<GridPoint> _horizontal(int row) => [
  for (var x = 0; x < 5; x++) _p(x, row),
];

List<GridPoint> _leftBranch(int row) => [_p(0, row), _p(1, row), _p(2, row)];

List<GridPoint> _rightBranch(int row) => [_p(2, row), _p(3, row), _p(4, row)];

List<GridPoint> _network(List<List<GridPoint>> branches) {
  final roads = <GridPoint>{..._spine()};
  for (final branch in branches) {
    roads.addAll(branch);
  }
  return roads.toList();
}

BusSpec _bus(String id, RouteKind route, int x, int y) =>
    BusSpec(id: id, route: route, position: _p(x, y), capacity: 2);

LevelSpec _level(
  String id,
  String title,
  List<List<GridPoint>> branches,
  List<BusSpec> buses,
  List<RouteKind> riderOrder, {
  required String tutorialPrompt,
  int bayCount = 3,
}) => LevelSpec(
  id: id,
  title: title,
  width: 5,
  height: 5,
  exit: _p(2, 0),
  roads: _network(branches),
  buses: buses,
  tutorialPrompt: tutorialPrompt,
  passengers: [
    for (final route in riderOrder) ...[route, route],
  ],
  bayCount: bayCount,
);

final List<LevelSpec> levels = [
  _level(
    'depot-01',
    'One clear route',
    [_horizontal(2)],
    [
      _bus('blue', RouteKind.blue, 2, 2),
      _bus('coral', RouteKind.coral, 0, 2),
      _bus('mint', RouteKind.mint, 4, 2),
    ],
    [RouteKind.coral, RouteKind.blue, RouteKind.mint],
    tutorialPrompt: 'Tap a bus with a clear road to the EXIT.',
  ),
  _level(
    'depot-02',
    'Two branches',
    [_leftBranch(1), _rightBranch(2)],
    [
      _bus('gold', RouteKind.gold, 2, 2),
      _bus('coral', RouteKind.coral, 0, 1),
      _bus('blue', RouteKind.blue, 4, 2),
      _bus('mint', RouteKind.mint, 2, 4),
    ],
    [RouteKind.coral, RouteKind.blue, RouteKind.gold, RouteKind.mint],
    tutorialPrompt: 'The first rider in the visible queue boards first.',
  ),
  _level(
    'depot-03',
    'Queue order',
    [_horizontal(2)],
    [
      _bus('gold', RouteKind.gold, 2, 3),
      _bus('coral', RouteKind.coral, 0, 2),
      _bus('blue', RouteKind.blue, 4, 2),
      _bus('mint', RouteKind.mint, 2, 4),
    ],
    [RouteKind.blue, RouteKind.coral, RouteKind.mint, RouteKind.gold],
    tutorialPrompt:
        'A mismatched bus can wait in a bay while you serve the next rider.',
    bayCount: 2,
  ),
  _level(
    'depot-04',
    'The center stop',
    [_horizontal(3)],
    [
      _bus('gold', RouteKind.gold, 2, 3),
      _bus('coral', RouteKind.coral, 0, 3),
      _bus('blue', RouteKind.blue, 4, 3),
      _bus('mint', RouteKind.mint, 2, 4),
    ],
    [RouteKind.gold, RouteKind.coral, RouteKind.blue, RouteKind.mint],
    tutorialPrompt: 'A bus on the road blocks every route through its tile.',
    bayCount: 2,
  ),
  _level(
    'depot-05',
    'Hold the right bus',
    [_horizontal(1)],
    [
      _bus('coral', RouteKind.coral, 2, 1),
      _bus('gold', RouteKind.gold, 0, 1),
      _bus('blue', RouteKind.blue, 4, 1),
      _bus('mint', RouteKind.mint, 2, 4),
    ],
    [RouteKind.gold, RouteKind.blue, RouteKind.coral, RouteKind.mint],
    tutorialPrompt:
        'Queue order and road access both shape a good dispatch order.',
    bayCount: 2,
  ),
  _level(
    'depot-06',
    'Open the junction',
    [_horizontal(2)],
    [
      _bus('blue', RouteKind.blue, 2, 2),
      _bus('coral', RouteKind.coral, 0, 2),
      _bus('gold', RouteKind.gold, 4, 2),
      _bus('mint', RouteKind.mint, 2, 4),
    ],
    [RouteKind.blue, RouteKind.gold, RouteKind.mint, RouteKind.coral],
    tutorialPrompt: 'A full bus leaves and opens a bay for the next bus.',
    bayCount: 2,
  ),
  _level(
    'depot-07',
    'Clear the upper lane',
    [_horizontal(3)],
    [
      _bus('gold', RouteKind.gold, 2, 3),
      _bus('coral', RouteKind.coral, 0, 3),
      _bus('blue', RouteKind.blue, 4, 3),
      _bus('mint', RouteKind.mint, 2, 1),
    ],
    [RouteKind.mint, RouteKind.gold, RouteKind.coral, RouteKind.blue],
    tutorialPrompt: 'Branches rejoin the shared road leading to the EXIT.',
    bayCount: 2,
  ),
  _level(
    'depot-08',
    'A bus in reserve',
    [_leftBranch(1), _rightBranch(1)],
    [
      _bus('gold', RouteKind.gold, 2, 1),
      _bus('coral', RouteKind.coral, 0, 1),
      _bus('mint', RouteKind.mint, 4, 1),
      _bus('blue', RouteKind.blue, 2, 3),
    ],
    [RouteKind.coral, RouteKind.blue, RouteKind.gold, RouteKind.mint],
    tutorialPrompt:
        'Think ahead: sending a bus opens road tiles but may fill a bay.',
    bayCount: 2,
  ),
  _level(
    'depot-09',
    'Two free bays',
    [_horizontal(2)],
    [
      _bus('coral', RouteKind.coral, 2, 2),
      _bus('gold', RouteKind.gold, 0, 2),
      _bus('mint', RouteKind.mint, 4, 2),
      _bus('blue', RouteKind.blue, 2, 4),
    ],
    [RouteKind.gold, RouteKind.mint, RouteKind.coral, RouteKind.blue],
    tutorialPrompt: 'Use the bays to stage buses while following the queue.',
    bayCount: 2,
  ),
  _level(
    'depot-10',
    'Depot master',
    [_horizontal(3)],
    [
      _bus('mint', RouteKind.mint, 2, 3),
      _bus('coral', RouteKind.coral, 0, 3),
      _bus('gold', RouteKind.gold, 4, 3),
      _bus('blue', RouteKind.blue, 2, 1),
    ],
    [RouteKind.blue, RouteKind.gold, RouteKind.mint, RouteKind.coral],
    tutorialPrompt:
        'Depot review: check the road, the next rider, and open bays each move.',
    bayCount: 2,
  ),
];
