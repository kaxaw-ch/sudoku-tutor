import 'package:sudoku_core/sudoku_core.dart';
import 'package:test/test.dart';

void main() {
  group('教学坐标中文化', () {
    test('Coord 同时保留内部标签与玩家中文标签', () {
      expect(Coord.label(Coord.indexOf(2, 3)), 'r3c4');
      expect(Coord.zhLabel(Coord.indexOf(2, 3)), '第 3 行第 4 列');
      expect(
        Coord.zhLabelAll(<int>[Coord.indexOf(0, 0), Coord.indexOf(8, 8)]),
        '第 1 行第 1 列、第 9 行第 9 列',
      );
    });

    test('兼容 r3c4 与历史 3r4c 写法', () {
      expect(
        NarrationFormat.localizeCoordinates('观察 r3c4，再检查 5r6c。'),
        '观察 第 3 行第 4 列，再检查 第 5 行第 6 列。',
      );
    });

    test('模板渲染不向玩家暴露内部坐标', () {
      const NarrationTemplate template =
          NarrationTemplate('{cell} 可删除 {elim}。');
      expect(
        template.render(<String, Object?>{
          'cell': 'r2c3',
          'elim': 'r4c5 的 7',
        }),
        '第 2 行第 3 列 可删除 第 4 行第 5 列 的 7。',
      );
    });

    test('删数文案使用自然中文坐标', () {
      expect(
        NarrationFormat.elimLabel(Coord.indexOf(4, 1), 5),
        '第 5 行第 2 列的候选 5',
      );
    });
  });
}
