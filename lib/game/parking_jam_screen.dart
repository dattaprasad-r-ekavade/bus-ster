import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'parking_jam_model.dart';

const _ink = Color(0xFF20364B);
const _paper = Color(0xFFF7F4E8);
const _coral = Color(0xFFF27968);
const _blue = Color(0xFF62BBD5);
const _mint = Color(0xFF77C98C);
const _gold = Color(0xFFF1BE4E);
const _purple = Color(0xFFAB8BD5);

JamLevel createParkingJamTutorialLevel() => JamLevel(
  width: 5,
  height: 5,
  bayCount: 1,
  vehicles: const [
    JamVehicle(
      id: 'coral-bus',
      origin: JamCell(2, 2),
      facing: JamFacing.up,
      length: 2,
      route: JamRoute.coral,
      capacity: 1,
    ),
    JamVehicle(
      id: 'blue-bus',
      origin: JamCell(0, 4),
      facing: JamFacing.right,
      length: 2,
      route: JamRoute.blue,
      capacity: 1,
    ),
    JamVehicle(
      id: 'coral-blocker',
      origin: JamCell(1, 1),
      facing: JamFacing.left,
      length: 2,
    ),
    JamVehicle(
      id: 'lower-blocker',
      origin: JamCell(0, 0),
      facing: JamFacing.down,
      length: 2,
    ),
    JamVehicle(
      id: 'top-car',
      origin: JamCell(3, 0),
      facing: JamFacing.left,
      length: 2,
    ),
    JamVehicle(
      id: 'upper-car',
      origin: JamCell(3, 1),
      facing: JamFacing.left,
      length: 2,
    ),
    JamVehicle(
      id: 'middle-car',
      origin: JamCell(3, 2),
      facing: JamFacing.left,
      length: 2,
    ),
    JamVehicle(
      id: 'lower-car',
      origin: JamCell(3, 3),
      facing: JamFacing.left,
      length: 2,
    ),
  ],
  passengers: const [JamRoute.blue, JamRoute.coral],
);

JamLevel createParkingJamDemoLevel() => JamLevel(
  width: 6,
  height: 6,
  bayCount: 2,
  vehicles: const [
    JamVehicle(
      id: 'coral-bus',
      origin: JamCell(2, 2),
      facing: JamFacing.up,
      length: 2,
      route: JamRoute.coral,
      capacity: 2,
    ),
    JamVehicle(
      id: 'blue-bus',
      origin: JamCell(0, 4),
      facing: JamFacing.right,
      length: 2,
      route: JamRoute.blue,
      capacity: 2,
    ),
    JamVehicle(
      id: 'mint-bus',
      origin: JamCell(5, 0),
      facing: JamFacing.down,
      length: 2,
      route: JamRoute.mint,
      capacity: 1,
    ),
    JamVehicle(
      id: 'gold-bus',
      origin: JamCell(4, 5),
      facing: JamFacing.left,
      length: 2,
      route: JamRoute.gold,
      capacity: 1,
    ),
    JamVehicle(
      id: 'coral-blocker',
      origin: JamCell(1, 1),
      facing: JamFacing.left,
      length: 2,
    ),
    JamVehicle(
      id: 'top-car',
      origin: JamCell(1, 0),
      facing: JamFacing.right,
      length: 2,
    ),
    JamVehicle(
      id: 'left-car',
      origin: JamCell(0, 0),
      facing: JamFacing.down,
      length: 2,
    ),
    JamVehicle(
      id: 'lower-car',
      origin: JamCell(1, 2),
      facing: JamFacing.down,
      length: 2,
    ),
    JamVehicle(
      id: 'upper-car',
      origin: JamCell(3, 0),
      facing: JamFacing.right,
      length: 2,
    ),
    JamVehicle(
      id: 'blue-blocker',
      origin: JamCell(2, 4),
      facing: JamFacing.right,
      length: 2,
    ),
    JamVehicle(
      id: 'middle-car',
      origin: JamCell(3, 2),
      facing: JamFacing.down,
      length: 2,
    ),
    JamVehicle(
      id: 'mint-blocker',
      origin: JamCell(4, 1),
      facing: JamFacing.up,
      length: 2,
    ),
  ],
  passengers: const [
    JamRoute.gold,
    JamRoute.mint,
    JamRoute.blue,
    JamRoute.blue,
    JamRoute.coral,
    JamRoute.coral,
  ],
);

class ParkingJamScreen extends StatefulWidget {
  const ParkingJamScreen({super.key, this.level});

  final JamLevel? level;

  @override
  State<ParkingJamScreen> createState() => _ParkingJamScreenState();
}

class _ParkingJamScreenState extends State<ParkingJamScreen> {
  late final List<JamLevel> _levels;
  late JamSession _session;
  var _levelIndex = 0;
  String? _departingId;
  String? _blockedId;
  String? _hintedId;
  String _message = 'Tap the clear blue bus to board the first riders.';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _levels = widget.level == null
        ? [createParkingJamTutorialLevel(), createParkingJamDemoLevel()]
        : [widget.level!];
    _session = JamSession(_levels.first);
    _message = _instructionFor(_session.state);
  }

  JamLevel get _level => _levels[_levelIndex];

  Future<void> _release(JamVehicle vehicle) async {
    if (_busy || !_session.state.activeVehicleIds.contains(vehicle.id)) return;
    final move = _session.rules.release(_session.state, vehicle.id);
    if (!move.moved) {
      setState(() {
        _blockedId = move.blockingVehicleId;
        _hintedId = null;
        _message = switch (move.block) {
          JamBlock.vehicle =>
            'Blocked by ${move.blockingVehicleId}. Clear it first.',
          JamBlock.fullBays => 'Both boarding spaces are full. Free one first.',
          JamBlock.alreadyGone || null => 'That vehicle has already left.',
        };
      });
      return;
    }

    setState(() {
      _busy = true;
      _departingId = vehicle.id;
      _blockedId = null;
      _hintedId = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    final result = _session.release(vehicle.id);
    final count = result.boarded;
    setState(() {
      _busy = false;
      _departingId = null;
      final boarding = count == 0
          ? ''
          : '$count passenger${count == 1 ? '' : 's'} boarded. ';
      _message = '$boarding${_instructionFor(result.state)}';
    });
  }

  String _instructionFor(JamState state) {
    if (state.status == JamStatus.won) {
      return 'Great work! Every rider and vehicle is clear.';
    }
    if (state.status == JamStatus.stuck) {
      return 'No clear move. Undo or retry the lot.';
    }
    if (_levels.length > 1 && _levelIndex == 0) {
      if (state.passengerIndex == 0) {
        return 'Tap the clear blue bus to board the first riders.';
      }
      if (state.passengerIndex == 1) {
        if (state.activeVehicleIds.contains('lower-blocker')) {
          return 'Move the green car down to free the orange blocker.';
        }
        if (state.activeVehicleIds.contains('coral-blocker')) {
          return 'Send the orange blocker left to free the coral bus.';
        }
        if (state.activeVehicleIds.contains('coral-bus')) {
          return 'The coral bus is clear. Tap it for the last rider.';
        }
      }
      return 'All riders are aboard. Clear the remaining cars to finish.';
    }
    return 'Clear a lane, then bring the matching bus to the riders.';
  }

  void _showHint() {
    final solution = _session.rules.solve(from: _session.state);
    if (solution == null || solution.isEmpty) {
      setState(() {
        _hintedId = null;
        _message = 'No clear sequence from here. Undo or retry the lot.';
      });
      return;
    }
    final vehicle = _level.vehicle(solution.first);
    setState(() {
      _hintedId = solution.first;
      _blockedId = null;
      _message = 'Try ${vehicle.id} first. Follow its arrow.';
    });
  }

  void _undo() {
    if (_session.undo()) {
      setState(() {
        _blockedId = null;
        _hintedId = null;
        _message = 'Move undone. Choose another vehicle.';
      });
    }
  }

  void _retry() {
    _session.retry();
    setState(() {
      _blockedId = null;
      _hintedId = null;
      _message = _instructionFor(_session.state);
    });
  }

  void _continueAfterWin() {
    if (_levelIndex + 1 < _levels.length) {
      setState(() {
        _levelIndex++;
        _session = JamSession(_level);
        _blockedId = null;
        _hintedId = null;
        _message = _instructionFor(_session.state);
      });
    } else {
      _retry();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _session.state;
    final pending = _level.passengers.skip(state.passengerIndex).toList();
    return Scaffold(
      backgroundColor: _paper,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxHeight < 690 || constraints.maxWidth < 350;
            final gap = compact ? 5.0 : 9.0;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 10 : 16,
                7,
                compact ? 10 : 16,
                8,
              ),
              child: Column(
                children: [
                  _Header(
                    compact: compact,
                    levelNumber: _levelIndex + 1,
                    onRetry: _retry,
                  ),
                  SizedBox(height: gap),
                  _GoalCard(message: _message, compact: compact),
                  SizedBox(height: gap),
                  _PassengerPanel(passengers: pending, compact: compact),
                  SizedBox(height: gap),
                  _BoardingBays(
                    level: _level,
                    parked: state.parked,
                    compact: compact,
                  ),
                  SizedBox(height: gap),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: math.min(constraints.maxWidth, 470),
                          maxHeight: constraints.maxHeight,
                        ),
                        child: AspectRatio(
                          aspectRatio: _level.width / _level.height,
                          child: _ParkingLot(
                            level: _level,
                            state: state,
                            departingId: _departingId,
                            blockedId: _blockedId,
                            hintedId: _hintedId,
                            enabled:
                                !_busy && state.status == JamStatus.playing,
                            onTapVehicle: _release,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: gap),
                  if (state.status == JamStatus.won)
                    _WinBar(
                      onContinue: _continueAfterWin,
                      canAdvance: _levelIndex + 1 < _levels.length,
                      compact: compact,
                    )
                  else if (state.status == JamStatus.stuck)
                    _StuckBar(onUndo: _undo, onRetry: _retry, compact: compact)
                  else
                    _Actions(
                      canUndo: _session.canUndo,
                      onUndo: _undo,
                      onRetry: _retry,
                      onHint: _showHint,
                      compact: compact,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.compact,
    required this.levelNumber,
    required this.onRetry,
  });
  final bool compact;
  final int levelNumber;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 13,
          vertical: compact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: _gold,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x334A432A),
              blurRadius: 0,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          'BUS·STER',
          style: TextStyle(
            color: _ink,
            fontSize: compact ? 12 : 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Text(
        'LEVEL ${levelNumber.toString().padLeft(2, '0')}',
        style: TextStyle(
          color: _ink.withValues(alpha: 0.8),
          fontSize: compact ? 12 : 13,
          fontWeight: FontWeight.w900,
        ),
      ),
      const Spacer(),
      IconButton(
        tooltip: 'Restart puzzle',
        onPressed: onRetry,
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.refresh_rounded, color: _ink),
      ),
    ],
  );
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.message, required this.compact});
  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(horizontal: 13, vertical: compact ? 8 : 11),
    decoration: BoxDecoration(
      color: const Color(0xFFE7E9D7),
      borderRadius: BorderRadius.circular(17),
    ),
    child: Row(
      children: [
        const Icon(Icons.alt_route_rounded, color: Color(0xFF478B76), size: 21),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _ink,
              fontSize: compact ? 12 : 14,
              height: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _PassengerPanel extends StatelessWidget {
  const _PassengerPanel({required this.passengers, required this.compact});
  final List<JamRoute> passengers;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.fromLTRB(12, compact ? 7 : 9, 12, compact ? 6 : 8),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFCF1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFC3D3C6), width: 2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x222A4B51),
          offset: Offset(0, 3),
          blurRadius: 0,
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Text(
              'WAITING FOR A RIDE',
              style: TextStyle(
                color: _ink,
                fontWeight: FontWeight.w900,
                fontSize: 10,
                letterSpacing: 1.1,
              ),
            ),
            const Spacer(),
            Text(
              '${passengers.length} LEFT',
              style: TextStyle(
                color: _ink.withValues(alpha: .55),
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 4 : 7),
        SizedBox(
          height: compact ? 39 : 45,
          child: passengers.isEmpty
              ? const Center(
                  child: Text(
                    'All riders are on their way!',
                    style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    for (final route in passengers.take(8))
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _Rider(route: route, compact: compact),
                      ),
                  ],
                ),
        ),
      ],
    ),
  );
}

class _Rider extends StatelessWidget {
  const _Rider({required this.route, required this.compact});
  final JamRoute route;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = _routeColor(route);
    return SizedBox(
      width: compact ? 28 : 35,
      height: compact ? 37 : 43,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: compact ? 24 : 28,
            height: compact ? 22 : 25,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          Positioned(
            top: 0,
            child: Container(
              width: compact ? 14 : 16,
              height: compact ? 14 : 16,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: _ink, width: 1.4),
              ),
            ),
          ),
          Positioned(
            bottom: 2,
            child: Text(
              _routeSymbol(route),
              style: TextStyle(
                color: _ink,
                fontSize: compact ? 10 : 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardingBays extends StatelessWidget {
  const _BoardingBays({
    required this.level,
    required this.parked,
    required this.compact,
  });
  final JamLevel level;
  final List<JamParkedBus> parked;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 10, vertical: compact ? 6 : 8),
    decoration: BoxDecoration(
      color: const Color(0xFFE3E4C8),
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: const Color(0xFFB5C193), width: 2),
    ),
    child: Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Text(
            'BAYS',
            style: TextStyle(
              color: _ink.withValues(alpha: .72),
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
        for (var index = 0; index < level.bayCount; index++) ...[
          if (index > 0) const SizedBox(width: 7),
          Expanded(
            child: _BaySlot(
              level: level,
              parked: index < parked.length ? parked[index] : null,
              compact: compact,
            ),
          ),
        ],
      ],
    ),
  );
}

class _BaySlot extends StatelessWidget {
  const _BaySlot({
    required this.level,
    required this.parked,
    required this.compact,
  });
  final JamLevel level;
  final JamParkedBus? parked;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bus = parked == null ? null : level.vehicle(parked!.id);
    return Container(
      height: compact ? 42 : 50,
      decoration: BoxDecoration(
        color: bus == null ? const Color(0xFFB8C8B0) : _routeColor(bus.route!),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF819B84), width: 2),
      ),
      child: bus == null
          ? Center(
              child: Text(
                'EMPTY',
                style: TextStyle(
                  color: _ink.withValues(alpha: .55),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                ),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _routeSymbol(bus.route!),
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${parked!.loaded}/${bus.capacity}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _ink,
                      fontSize: compact ? 10 : 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ParkingLot extends StatelessWidget {
  const _ParkingLot({
    required this.level,
    required this.state,
    required this.departingId,
    required this.blockedId,
    required this.hintedId,
    required this.enabled,
    required this.onTapVehicle,
  });
  final JamLevel level;
  final JamState state;
  final String? departingId;
  final String? blockedId;
  final String? hintedId;
  final bool enabled;
  final ValueChanged<JamVehicle> onTapVehicle;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth <= 20 + level.width * 4) {
        return const SizedBox.shrink();
      }
      final cell = (constraints.maxWidth - 20) / level.width;
      final width = cell * level.width;
      final height = cell * level.height;
      return ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFAFBFBA),
            border: Border.all(color: const Color(0xFF829993), width: 4),
            borderRadius: BorderRadius.circular(23),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33283E44),
                offset: Offset(0, 5),
                blurRadius: 0,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _LotPainter(level.width, level.height),
                  ),
                ),
                for (final vehicle in level.vehicles)
                  if (state.activeVehicleIds.contains(vehicle.id))
                    _positionVehicle(vehicle, cell, width, height),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _positionVehicle(
    JamVehicle vehicle,
    double cell,
    double boardWidth,
    double boardHeight,
  ) {
    final horizontal =
        vehicle.facing == JamFacing.left || vehicle.facing == JamFacing.right;
    var left = vehicle.origin.x * cell + 2;
    var top = vehicle.origin.y * cell + 2;
    if (vehicle.id == departingId) {
      switch (vehicle.facing) {
        case JamFacing.left:
          left = -cell * vehicle.length;
        case JamFacing.right:
          left = boardWidth;
        case JamFacing.up:
          top = -cell * vehicle.length;
        case JamFacing.down:
          top = boardHeight;
      }
    }
    final color = vehicle.isBus
        ? _routeColor(vehicle.route!)
        : _carColor(vehicle.id);
    final highlighted = vehicle.id == hintedId;
    final blocked = vehicle.id == blockedId;
    return AnimatedPositioned(
      key: ValueKey(vehicle.id),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInCubic,
      left: left,
      top: top,
      width: (horizontal ? vehicle.length : 1) * cell - 4,
      height: (horizontal ? 1 : vehicle.length) * cell - 4,
      child: GestureDetector(
        onTap: enabled ? () => onTapVehicle(vehicle) : null,
        child: Semantics(
          button: true,
          label:
              '${vehicle.isBus ? 'Bus' : 'Car'} ${vehicle.id}, facing ${vehicle.facing.name}',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(math.max(10, cell * .19)),
              border: Border.all(
                color: blocked ? const Color(0xFFB84036) : _ink,
                width: blocked ? 4 : 2.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x5530464C),
                  offset: Offset(0, cell * .07),
                  blurRadius: 1,
                ),
                if (highlighted)
                  const BoxShadow(
                    color: Color(0xFFFFE879),
                    spreadRadius: 3,
                    blurRadius: 5,
                  ),
              ],
            ),
            child: _VehicleArtwork(vehicle: vehicle, cell: cell),
          ),
        ),
      ),
    );
  }
}

class _VehicleArtwork extends StatelessWidget {
  const _VehicleArtwork({required this.vehicle, required this.cell});
  final JamVehicle vehicle;
  final double cell;

  @override
  Widget build(BuildContext context) {
    final horizontal =
        vehicle.facing == JamFacing.left || vehicle.facing == JamFacing.right;
    final forward = switch (vehicle.facing) {
      JamFacing.up => Icons.keyboard_arrow_up_rounded,
      JamFacing.right => Icons.keyboard_arrow_right_rounded,
      JamFacing.down => Icons.keyboard_arrow_down_rounded,
      JamFacing.left => Icons.keyboard_arrow_left_rounded,
    };
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _VehicleDetailsPainter(
              horizontal: horizontal,
              isBus: vehicle.isBus,
              facing: vehicle.facing,
              cell: cell,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(math.max(3, cell * .07)),
          child: horizontal
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (vehicle.isBus) _WindowStrip(vertical: false),
                    Icon(forward, color: _ink, size: cell * .46),
                    if (vehicle.isBus)
                      _RouteBadge(route: vehicle.route!, cell: cell),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (vehicle.isBus) _WindowStrip(vertical: true),
                    Icon(forward, color: _ink, size: cell * .46),
                    if (vehicle.isBus)
                      _RouteBadge(route: vehicle.route!, cell: cell),
                  ],
                ),
        ),
      ],
    );
  }
}

class _VehicleDetailsPainter extends CustomPainter {
  const _VehicleDetailsPainter({
    required this.horizontal,
    required this.isBus,
    required this.facing,
    required this.cell,
  });

  final bool horizontal;
  final bool isBus;
  final JamFacing facing;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final tirePaint = Paint()..color = const Color(0xFF40525B);
    final tireLong = cell * .2;
    final tireShort = cell * .11;
    final radius = Radius.circular(tireShort / 2);
    if (horizontal) {
      for (final x in [cell * .22, size.width - cell * .42]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, 1, tireLong, tireShort),
            radius,
          ),
          tirePaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, size.height - tireShort - 1, tireLong, tireShort),
            radius,
          ),
          tirePaint,
        );
      }
    } else {
      for (final y in [cell * .22, size.height - cell * .42]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(1, y, tireShort, tireLong),
            radius,
          ),
          tirePaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width - tireShort - 1, y, tireShort, tireLong),
            radius,
          ),
          tirePaint,
        );
      }
    }

    if (isBus) return;
    final glassPaint = Paint()
      ..color = const Color(0xFFDFF4EC)
      ..style = PaintingStyle.fill;
    final outlinePaint = Paint()
      ..color = const Color(0xFF47636B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    late final Rect glass;
    if (horizontal) {
      final x = facing == JamFacing.right
          ? size.width - cell * .48
          : cell * .19;
      glass = Rect.fromLTWH(
        x,
        size.height * .29,
        cell * .25,
        size.height * .42,
      );
    } else {
      final y = facing == JamFacing.down
          ? size.height - cell * .48
          : cell * .19;
      glass = Rect.fromLTWH(size.width * .29, y, size.width * .42, cell * .25);
    }
    final rrect = RRect.fromRectAndRadius(glass, const Radius.circular(5));
    canvas.drawRRect(rrect, glassPaint);
    canvas.drawRRect(rrect, outlinePaint);
  }

  @override
  bool shouldRepaint(covariant _VehicleDetailsPainter oldDelegate) =>
      oldDelegate.horizontal != horizontal ||
      oldDelegate.isBus != isBus ||
      oldDelegate.facing != facing ||
      oldDelegate.cell != cell;
}

class _WindowStrip extends StatelessWidget {
  const _WindowStrip({required this.vertical});
  final bool vertical;

  @override
  Widget build(BuildContext context) => Flexible(
    child: Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFFDFF4EC),
        border: Border.all(color: const Color(0xFF47636B), width: 1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: vertical
          ? const SizedBox(width: double.infinity)
          : const SizedBox(height: double.infinity),
    ),
  );
}

class _RouteBadge extends StatelessWidget {
  const _RouteBadge({required this.route, required this.cell});
  final JamRoute route;
  final double cell;

  @override
  Widget build(BuildContext context) => Container(
    width: cell * .35,
    height: cell * .35,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7DA),
      shape: BoxShape.circle,
      border: Border.all(color: _ink, width: 1.2),
    ),
    child: Text(
      _routeSymbol(route),
      style: TextStyle(
        color: _ink,
        fontWeight: FontWeight.w900,
        fontSize: cell * .19,
      ),
    ),
  );
}

class _LotPainter extends CustomPainter {
  _LotPainter(this.width, this.height);
  final int width;
  final int height;

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / width;
    final cellH = size.height / height;
    final gridPaint = Paint()
      ..color = const Color(0x63F9FFF3)
      ..strokeWidth = 1.2;
    for (var x = 1; x < width; x++) {
      canvas.drawLine(
        Offset(x * cellW, 0),
        Offset(x * cellW, size.height),
        gridPaint,
      );
    }
    for (var y = 1; y < height; y++) {
      canvas.drawLine(
        Offset(0, y * cellH),
        Offset(size.width, y * cellH),
        gridPaint,
      );
    }
    final edgePaint = Paint()
      ..color = const Color(0x557A938A)
      ..strokeWidth = 4;
    canvas.drawLine(Offset(4, 3), Offset(size.width - 4, 3), edgePaint);
  }

  @override
  bool shouldRepaint(covariant _LotPainter oldDelegate) =>
      oldDelegate.width != width || oldDelegate.height != height;
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.canUndo,
    required this.onUndo,
    required this.onRetry,
    required this.onHint,
    required this.compact,
  });
  final bool canUndo;
  final VoidCallback onUndo;
  final VoidCallback onRetry;
  final VoidCallback onHint;
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _ActionButton(
          icon: Icons.undo_rounded,
          label: 'UNDO',
          onPressed: canUndo ? onUndo : null,
          compact: compact,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _ActionButton(
          icon: Icons.refresh_rounded,
          label: 'RETRY',
          onPressed: onRetry,
          compact: compact,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _ActionButton(
          icon: Icons.lightbulb_outline_rounded,
          label: 'HINT',
          onPressed: onHint,
          compact: compact,
          accent: true,
        ),
      ),
    ],
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.compact,
    this.accent = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool compact;
  final bool accent;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: compact ? 42 : 48,
    child: OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: accent
            ? const Color(0xFFF7D76C)
            : const Color(0xFFFFFCF2),
        foregroundColor: _ink,
        disabledForegroundColor: _ink.withValues(alpha: .35),
        side: const BorderSide(color: Color(0xFFB9C6B9), width: 1.5),
        padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      icon: Icon(icon, size: compact ? 17 : 19),
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: compact ? 10 : 11,
        ),
      ),
    ),
  );
}

class _WinBar extends StatelessWidget {
  const _WinBar({
    required this.onContinue,
    required this.canAdvance,
    required this.compact,
  });
  final VoidCallback onContinue;
  final bool canAdvance;
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(
        child: Text(
          'ALL ABOARD! 🎉',
          style: TextStyle(color: _ink, fontWeight: FontWeight.w900),
        ),
      ),
      FilledButton(
        onPressed: onContinue,
        style: FilledButton.styleFrom(
          backgroundColor: _gold,
          foregroundColor: _ink,
        ),
        child: Text(
          canAdvance ? 'NEXT LEVEL' : (compact ? 'AGAIN' : 'PLAY AGAIN'),
        ),
      ),
    ],
  );
}

class _StuckBar extends StatelessWidget {
  const _StuckBar({
    required this.onUndo,
    required this.onRetry,
    required this.compact,
  });
  final VoidCallback onUndo;
  final VoidCallback onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(
        child: Text(
          'No clear lane. Undo or retry.',
          style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
        ),
      ),
      TextButton(onPressed: onUndo, child: const Text('UNDO')),
      FilledButton(
        onPressed: onRetry,
        style: FilledButton.styleFrom(
          backgroundColor: _gold,
          foregroundColor: _ink,
        ),
        child: Text(compact ? 'RETRY' : 'TRY AGAIN'),
      ),
    ],
  );
}

Color _routeColor(JamRoute route) => switch (route) {
  JamRoute.coral => _coral,
  JamRoute.blue => _blue,
  JamRoute.mint => _mint,
  JamRoute.gold => _gold,
};

String _routeSymbol(JamRoute route) => switch (route) {
  JamRoute.coral => '●',
  JamRoute.blue => '◆',
  JamRoute.mint => '▲',
  JamRoute.gold => '✦',
};

Color _carColor(String id) => switch (id) {
  'coral-blocker' || 'left-car' => const Color(0xFFF7A15E),
  'top-car' || 'upper-car' => _purple,
  'lower-car' || 'middle-car' => const Color(0xFFE6D66D),
  _ => const Color(0xFF7AC5A7),
};
