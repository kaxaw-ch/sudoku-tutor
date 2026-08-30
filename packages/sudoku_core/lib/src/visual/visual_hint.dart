/// 四类可视化标记的聚合根 + JSON codec（P0-ENG-09，**强制**）。
///
/// 铁律：**UI 层不得自行推断任何坐标**，一切高亮/描边/连线/划除都来自本对象。
library;

import 'package:meta/meta.dart';

import '../model/candidate_set.dart';
import 'candidate_mark.dart';
import 'cell_mark.dart';
import 'link_mark.dart';
import 'mark_role.dart';
import 'region_mark.dart';

/// 一步技巧结论的完整可视化数据。
@immutable
class VisualHint {
  /// 构造一份可视化数据（各列表做不可变拷贝）。
  VisualHint({
    List<CellMark> cells = const <CellMark>[],
    List<RegionMark> regions = const <RegionMark>[],
    List<LinkMark> links = const <LinkMark>[],
    List<CandidateMark> candidateMarks = const <CandidateMark>[],
  })  : cells = List<CellMark>.unmodifiable(cells),
        regions = List<RegionMark>.unmodifiable(regions),
        links = List<LinkMark>.unmodifiable(links),
        candidateMarks = List<CandidateMark>.unmodifiable(candidateMarks);

  /// 空可视化数据（无任何标记）。
  factory VisualHint.empty() => VisualHint();

  /// **可视化数据装配工厂**（T-CORE-09）：把一次技巧结论的
  /// 「模式格 + 关键格 + 连线 + 删数」一次性装配成 UI 可直接渲染的 [VisualHint]。
  ///
  /// 设计要点：
  /// - 识别器只需按语义把格索引分桶传入，**不需要自己 new 任何 Mark**，
  ///   从而保证 16 项技巧的可视化字段口径完全一致；
  /// - 同一格被多个桶命中时，按「模式 > 鳍 > 枢轴 > 夹翼 > 强链 > 弱链 >
  ///   覆盖区 > 删数 > 目标」的优先级**只保留最高优先级角色**，避免重复 [CellMark]；
  /// - [eliminated] 中的每条 `cell -> digit` 会同时产出
  ///   [MarkRole.elimination] 的 [CellMark] 与 [CandidateMarkKind.strike] 的 [CandidateMark]；
  /// - [placed] 中的每条 `cell -> digit` 会同时产出
  ///   [MarkRole.target] 的 [CellMark] 与 [CandidateMarkKind.target] 的 [CandidateMark]；
  /// - [focusDigits] 会写入所有**模式类**角色的 `focusDigits`，供 UI 只高亮相关候选数。
  factory VisualHint.assemble({
    Iterable<int> patternCells = const <int>[],
    Iterable<int> finCells = const <int>[],
    Iterable<int> pivotCells = const <int>[],
    Iterable<int> pincerCells = const <int>[],
    Iterable<int> chainStrongCells = const <int>[],
    Iterable<int> chainWeakCells = const <int>[],
    Iterable<int> coverCells = const <int>[],
    Iterable<MapEntry<int, int>> eliminated = const <MapEntry<int, int>>[],
    Iterable<MapEntry<int, int>> placed = const <MapEntry<int, int>>[],
    Iterable<MapEntry<int, int>> emphasized = const <MapEntry<int, int>>[],
    CandidateSet focusDigits = CandidateSet.none,
    Iterable<RegionMark> regions = const <RegionMark>[],
    Iterable<LinkMark> links = const <LinkMark>[],
  }) {
    final List<CellMark> cellMarks = <CellMark>[];
    final Set<int> taken = <int>{};

    void addCells(Iterable<int> source, MarkRole role, {bool focus = true}) {
      for (final int index in source) {
        if (!taken.add(index)) {
          continue;
        }
        cellMarks.add(
          CellMark(
            index: index,
            role: role,
            focusDigits: focus ? focusDigits : CandidateSet.none,
          ),
        );
      }
    }

    // 优先级从高到低，先占先得。
    addCells(patternCells, MarkRole.pattern);
    addCells(finCells, MarkRole.fin);
    addCells(pivotCells, MarkRole.pivot);
    addCells(pincerCells, MarkRole.pincer);
    addCells(chainStrongCells, MarkRole.chainStrong);
    addCells(chainWeakCells, MarkRole.chainWeak);
    addCells(coverCells, MarkRole.cover, focus: false);

    final List<CandidateMark> candidateMarks = <CandidateMark>[];
    for (final MapEntry<int, int> entry in emphasized) {
      candidateMarks.add(
        CandidateMark(
          cellIndex: entry.key,
          digit: entry.value,
          kind: CandidateMarkKind.emphasize,
        ),
      );
    }
    for (final MapEntry<int, int> entry in eliminated) {
      if (taken.add(entry.key)) {
        cellMarks.add(CellMark(index: entry.key, role: MarkRole.elimination));
      }
      candidateMarks.add(
        CandidateMark(
          cellIndex: entry.key,
          digit: entry.value,
          kind: CandidateMarkKind.strike,
        ),
      );
    }
    for (final MapEntry<int, int> entry in placed) {
      if (taken.add(entry.key)) {
        cellMarks.add(CellMark(index: entry.key, role: MarkRole.target));
      }
      candidateMarks.add(
        CandidateMark(
          cellIndex: entry.key,
          digit: entry.value,
          kind: CandidateMarkKind.target,
        ),
      );
    }

    return VisualHint(
      cells: cellMarks,
      regions: regions.toList(growable: false),
      links: links.toList(growable: false),
      candidateMarks: candidateMarks,
    );
  }

  /// 高亮格标记。
  final List<CellMark> cells;

  /// 区域描边标记。
  final List<RegionMark> regions;

  /// 连线标记。
  final List<LinkMark> links;

  /// 候选数标记。
  final List<CandidateMark> candidateMarks;

  /// 是否不含任何标记。
  bool get isEmpty =>
      cells.isEmpty && regions.isEmpty && links.isEmpty && candidateMarks.isEmpty;

  /// 是否含有标记。
  bool get isNotEmpty => !isEmpty;

  /// 涉及的全部格索引（升序去重，供「涉及格」统计与测试断言用）。
  List<int> involvedCells() {
    final Set<int> set = <int>{};
    for (final CellMark mark in cells) {
      set.add(mark.index);
    }
    for (final RegionMark mark in regions) {
      set.addAll(mark.cornerCells);
    }
    for (final LinkMark mark in links) {
      set
        ..add(mark.fromCell)
        ..add(mark.toCell);
    }
    for (final CandidateMark mark in candidateMarks) {
      set.add(mark.cellIndex);
    }
    final List<int> list = set.toList()..sort();
    return List<int>.unmodifiable(list);
  }

  /// 序列化为 JSON map（与 [fromJson] 往返一致）。
  Map<String, Object?> toJson() => <String, Object?>{
        'cells': <Map<String, Object?>>[for (final CellMark m in cells) m.toJson()],
        'regions': <Map<String, Object?>>[for (final RegionMark m in regions) m.toJson()],
        'links': <Map<String, Object?>>[for (final LinkMark m in links) m.toJson()],
        'candidateMarks': <Map<String, Object?>>[
          for (final CandidateMark m in candidateMarks) m.toJson(),
        ],
      };

  /// 由 JSON map 反序列化。
  static VisualHint fromJson(Map<String, Object?> json) => VisualHint(
        cells: <CellMark>[
          for (final Object? item in _listOf(json['cells']))
            CellMark.fromJson(item! as Map<String, Object?>),
        ],
        regions: <RegionMark>[
          for (final Object? item in _listOf(json['regions']))
            RegionMark.fromJson(item! as Map<String, Object?>),
        ],
        links: <LinkMark>[
          for (final Object? item in _listOf(json['links']))
            LinkMark.fromJson(item! as Map<String, Object?>),
        ],
        candidateMarks: <CandidateMark>[
          for (final Object? item in _listOf(json['candidateMarks']))
            CandidateMark.fromJson(item! as Map<String, Object?>),
        ],
      );

  static List<Object?> _listOf(Object? value) =>
      value is List<Object?> ? value : const <Object?>[];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VisualHint &&
          _sameList<CellMark>(other.cells, cells) &&
          _sameList<RegionMark>(other.regions, regions) &&
          _sameList<LinkMark>(other.links, links) &&
          _sameList<CandidateMark>(other.candidateMarks, candidateMarks));

  static bool _sameList<T>(List<T> a, List<T> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(cells),
        Object.hashAll(regions),
        Object.hashAll(links),
        Object.hashAll(candidateMarks),
      );

  @override
  String toString() => 'VisualHint(cells=${cells.length},regions=${regions.length},'
      'links=${links.length},candidateMarks=${candidateMarks.length})';
}
