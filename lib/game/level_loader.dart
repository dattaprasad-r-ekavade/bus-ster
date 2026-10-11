import 'package:flutter/services.dart';

import 'game_model.dart';
import 'level_bundle.dart';

Future<List<LevelSpec>> loadBundledLevels() async {
  final source = await rootBundle.loadString('assets/levels/levels.json');
  return LevelBundleCodec.decode(source);
}
