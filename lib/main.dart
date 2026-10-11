import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/depot_game.dart';
import 'game/game_model.dart';
import 'game/game_session.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BussterApp());
}

class BussterApp extends StatelessWidget {
  const BussterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bus-ster',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101A2A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFC857),
          brightness: Brightness.dark,
          surface: const Color(0xFF1B2940),
        ),
        useMaterial3: true,
      ),
      home: const DepotScreen(),
    );
  }
}

class DepotScreen extends StatefulWidget {
  const DepotScreen({super.key});

  @override
  State<DepotScreen> createState() => _DepotScreenState();
}

class _DepotScreenState extends State<DepotScreen> {
  late final GameSession _session;
  late final DepotGame _game;

  @override
  void initState() {
    super.initState();
    _session = GameSession();
    _game = DepotGame(_session);
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  void _showHowToPlay() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to play'),
        content: const Text(
          'Tap a bus when a clear road connects it to the EXIT.\n\n'
          'The bus waits in a departure bay. Riders board from the front '
          'of the queue, in order, and only ride a matching route.\n\n'
          'A full bus leaves and opens its bay. Clear every rider to finish '
          'the depot.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('GOT IT'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _session,
      builder: (context, _) {
        final level = _session.level;
        final state = _session.state;
        final pending = level.passengers.skip(state.queueIndex).toList();

        return Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    children: [
                      _TopBar(
                        levelNumber: _session.levelIndex + 1,
                        moveCount: state.moveCount,
                        onHelp: _showHowToPlay,
                        onRestart: _session.restart,
                      ),
                      const SizedBox(height: 18),
                      _ObjectiveCard(
                        message: _session.message,
                        passengerCount: pending.length,
                      ),
                      const SizedBox(height: 14),
                      _PassengerQueue(passengers: pending),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'DEPOT ROUTE',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: const Color(0xFF8FA2BC),
                                letterSpacing: 1.6,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: 440,
                              maxHeight: constraints.maxHeight * 0.58,
                            ),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: GameWidget<DepotGame>(game: _game),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _BayPanel(parked: state.parked, bayCount: level.bayCount),
                      const SizedBox(height: 12),
                      _ActionBar(
                        canUndo: _session.canUndo,
                        isWon: state.status == GameStatus.won,
                        isStuck: state.status == GameStatus.stuck,
                        onUndo: _session.undo,
                        onHint: _session.showHint,
                        onNext: _session.nextLevel,
                        onRetry: _session.restart,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.levelNumber,
    required this.moveCount,
    required this.onHelp,
    required this.onRestart,
  });

  final int levelNumber;
  final int moveCount;
  final VoidCallback onHelp;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFFFC857),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.directions_bus_rounded,
            color: Color(0xFF24344B),
            size: 27,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BUS-STER',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'DEPOT ${levelNumber.toString().padLeft(2, '0')}  ·  $moveCount MOVES',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF8FA2BC),
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onHelp,
          tooltip: 'How to play',
          icon: const Icon(Icons.help_outline_rounded),
        ),
        IconButton.filledTonal(
          onPressed: onRestart,
          tooltip: 'Restart level',
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

class _ObjectiveCard extends StatelessWidget {
  const _ObjectiveCard({required this.message, required this.passengerCount});

  final String message;
  final int passengerCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2940),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFF2A3A54)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.alt_route_rounded,
            color: Color(0xFFFFC857),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$passengerCount',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFFFFC857),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PassengerQueue extends StatelessWidget {
  const _PassengerQueue({required this.passengers});

  final List<RouteKind> passengers;

  @override
  Widget build(BuildContext context) {
    final visible = passengers.take(8).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF17243A),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NEXT RIDERS',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF8FA2BC),
                  letterSpacing: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              const Text('FIFO QUEUE', style: TextStyle(fontSize: 9)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 34,
              child: visible.isEmpty
                  ? const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'All aboard!',
                        style: TextStyle(fontSize: 12),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, index) => _RouteToken(
                        route: visible[index],
                        isNext: index == 0,
                      ),
                    ),
            ),
          ),
          if (passengers.length > visible.length)
            Text(
              '+${passengers.length - visible.length}',
              style: const TextStyle(
                color: Color(0xFF8FA2BC),
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _RouteToken extends StatelessWidget {
  const _RouteToken({required this.route, required this.isNext});

  final RouteKind route;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color(route.colorValue),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isNext ? Colors.white : Colors.white.withValues(alpha: 0.18),
          width: isNext ? 2 : 1,
        ),
        boxShadow: isNext
            ? const [BoxShadow(color: Color(0x40FFFFFF), blurRadius: 8)]
            : null,
      ),
      child: Text(
        route.symbol,
        style: const TextStyle(
          color: Color(0xFF101A2A),
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _BayPanel extends StatelessWidget {
  const _BayPanel({required this.parked, required this.bayCount});

  final List<ParkedBus> parked;
  final int bayCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'BAYS',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: const Color(0xFF8FA2BC),
            letterSpacing: 1.3,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 10),
        ...List.generate(bayCount, (index) {
          final bus = index < parked.length ? parked[index] : null;
          return Expanded(
            child: Container(
              height: 48,
              margin: EdgeInsets.only(right: index == bayCount - 1 ? 0 : 7),
              decoration: BoxDecoration(
                color: const Color(0xFF1B2940),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: bus == null
                      ? const Color(0xFF2A3A54)
                      : Color(bus.route.colorValue).withValues(alpha: 0.8),
                  width: bus == null ? 1 : 2,
                ),
              ),
              child: bus == null
                  ? const Icon(
                      Icons.add_rounded,
                      color: Color(0xFF566982),
                      size: 18,
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          bus.route.symbol,
                          style: TextStyle(
                            color: Color(bus.route.colorValue),
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${bus.loaded}/${bus.capacity}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
            ),
          );
        }),
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.canUndo,
    required this.isWon,
    required this.isStuck,
    required this.onUndo,
    required this.onHint,
    required this.onNext,
    required this.onRetry,
  });

  final bool canUndo;
  final bool isWon;
  final bool isStuck;
  final VoidCallback onUndo;
  final VoidCallback onHint;
  final VoidCallback onNext;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isWon || isStuck) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          onPressed: isWon ? onNext : onRetry,
          icon: Icon(
            isWon ? Icons.arrow_forward_rounded : Icons.replay_rounded,
          ),
          label: Text(isWon ? 'NEXT DEPOT' : 'TRY AGAIN'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFFC857),
            foregroundColor: const Color(0xFF24344B),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: canUndo ? onUndo : null,
            icon: const Icon(Icons.undo_rounded, size: 19),
            label: const Text('UNDO'),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: FilledButton.icon(
            onPressed: onHint,
            icon: const Icon(Icons.lightbulb_outline_rounded, size: 19),
            label: const Text('ROUTE TIP'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF243A59),
              foregroundColor: const Color(0xFFFFD36F),
            ),
          ),
        ),
        const SizedBox(width: 9),
        IconButton.filledTonal(
          onPressed: onRetry,
          tooltip: 'Restart level',
          icon: const Icon(Icons.replay_rounded),
        ),
      ],
    );
  }
}
