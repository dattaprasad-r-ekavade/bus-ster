import 'game_model.dart';

enum MirrorAxis { x, y }

class LevelVariant {
  static LevelSpec mirror(LevelSpec source, MirrorAxis axis) {
    GridPoint transform(GridPoint point) => switch (axis) {
      MirrorAxis.x => GridPoint(source.width - 1 - point.x, point.y),
      MirrorAxis.y => GridPoint(point.x, source.height - 1 - point.y),
    };

    final suffix = axis.name;
    return LevelSpec(
      id: '${source.id}-mirror-$suffix',
      title: source.title,
      localizedTitles: source.localizedTitles,
      width: source.width,
      height: source.height,
      exit: transform(source.exit),
      roads: source.roads.map(transform),
      buses: [
        for (final bus in source.buses)
          BusSpec(
            id: bus.id,
            route: bus.route,
            position: transform(bus.position),
            capacity: bus.capacity,
          ),
      ],
      passengers: source.passengers,
      tutorialPrompt: source.tutorialPrompt,
      localizedTutorialPrompts: source.localizedTutorialPrompts,
      bayCount: source.bayCount,
      difficultyBand: source.difficultyBand,
      mechanicTags: source.mechanicTags,
      seed: null,
    );
  }
}
