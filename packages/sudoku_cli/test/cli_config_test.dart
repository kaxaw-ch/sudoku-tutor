/// `CliConfig` / `ProfileSpec` 单测（T-CLI-01：profile 声明式启用规则集）。
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:sudoku_core/sudoku_core.dart';

import 'package:sudoku_cli/sudoku_cli.dart';

void main() {
  group('ProfileSpec 规则集对接 sudoku_core', () {
    test('t2 模式 = RuleSet.t2()（16 项全量）', () {
      const ProfileSpec spec = ProfileSpec(
        name: 't2',
        description: '',
        ruleSetMode: RuleSetMode.t2,
        customIds: <String>[],
        defaultDifficulty: Difficulty.medium,
        defaultTargetGivens: 30,
        symmetry: SymmetryMode.none,
        maxAttempts: 500,
      );
      expect(spec.ruleSet, equals(RuleSet.t2()));
      expect(spec.ruleSet.length, 16);
    });

    test('t1 模式 = RuleSet.t1()（13 项，不含 T2 三项）', () {
      const ProfileSpec spec = ProfileSpec(
        name: 't1',
        description: '',
        ruleSetMode: RuleSetMode.t1,
        customIds: <String>[],
        defaultDifficulty: Difficulty.medium,
        defaultTargetGivens: 30,
        symmetry: SymmetryMode.none,
        maxAttempts: 500,
      );
      expect(spec.ruleSet, equals(RuleSet.t1()));
      expect(spec.ruleSet.length, 13);
      expect(spec.ruleSet.allows(TechniqueId.finnedXWing), isFalse);
    });

    test('custom 模式按 ids 启用', () {
      const ProfileSpec spec = ProfileSpec(
        name: 'custom',
        description: '',
        ruleSetMode: RuleSetMode.custom,
        customIds: <String>['nakedSingle', 'hiddenSingle', 'xWing'],
        defaultDifficulty: Difficulty.medium,
        defaultTargetGivens: 30,
        symmetry: SymmetryMode.none,
        maxAttempts: 500,
      );
      expect(spec.ruleSet.allows(TechniqueId.xWing), isTrue);
      expect(spec.ruleSet.allows(TechniqueId.xyWing), isFalse);
    });

    test('toJson/fromJson 往返一致', () {
      const ProfileSpec spec = ProfileSpec(
        name: 't2',
        description: '全量',
        ruleSetMode: RuleSetMode.t2,
        customIds: <String>[],
        defaultDifficulty: Difficulty.hard,
        defaultTargetGivens: 24,
        symmetry: SymmetryMode.central,
        maxAttempts: 800,
      );
      final ProfileSpec restored = ProfileSpec.fromJson(spec.toJson());
      expect(restored.name, spec.name);
      expect(restored.ruleSetMode, RuleSetMode.t2);
      expect(restored.ruleSet, equals(spec.ruleSet));
      expect(restored.defaultDifficulty, Difficulty.hard);
      expect(restored.defaultTargetGivens, 24);
      expect(restored.symmetry, SymmetryMode.central);
      expect(restored.maxAttempts, 800);
    });
  });

  group('CliConfig 载入', () {
    test('内建 t2 名称解析', () {
      final ProfileSpec spec = CliConfig.loadProfile('t2');
      expect(spec.name, 't2');
      expect(spec.ruleSet, equals(RuleSet.t2()));
    });

    test('未知内建名称抛 FormatException', () {
      expect(() => CliConfig.loadProfile('t3'), throwsFormatException);
    });

    test('YAML 文件载入（t1 声明）', () {
      final Directory dir = Directory.systemTemp.createTempSync('cli_cfg_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final File file = File('${dir.path}/t1.yaml');
      file.writeAsStringSync('''
name: t1
description: 测试用 t1
ruleSet:
  mode: t1
  ids: []
defaults:
  difficulty: easy
  targetGivens: 34
  symmetry: central
  maxAttempts: 300
''');
      final ProfileSpec spec =
          CliConfig.loadProfile(file.path, baseDir: dir.path);
      expect(spec.name, 't1');
      expect(spec.ruleSet, equals(RuleSet.t1()));
      expect(spec.defaultDifficulty, Difficulty.easy);
      expect(spec.defaultTargetGivens, 34);
      expect(spec.symmetry, SymmetryMode.central);
      expect(spec.maxAttempts, 300);
    });

    test('custom 模式 YAML 载入', () {
      final Directory dir = Directory.systemTemp.createTempSync('cli_cfg_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final File file = File('${dir.path}/x.yaml');
      file.writeAsStringSync('''
name: x
description: 仅两项
ruleSet:
  mode: custom
  ids: [nakedSingle, xWing]
defaults:
  difficulty: hard
  targetGivens: 26
''');
      final ProfileSpec spec =
          CliConfig.loadProfile(file.path, baseDir: dir.path);
      expect(spec.ruleSetMode, RuleSetMode.custom);
      expect(spec.ruleSet.allows(TechniqueId.nakedSingle), isTrue);
      expect(spec.ruleSet.allows(TechniqueId.xWing), isTrue);
      expect(spec.ruleSet.allows(TechniqueId.xyWing), isFalse);
      expect(spec.defaultDifficulty, Difficulty.hard);
      expect(spec.defaultTargetGivens, 26);
    });

    test('custom 模式缺 ids 抛 FormatException', () {
      final Directory dir = Directory.systemTemp.createTempSync('cli_cfg_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final File file = File('${dir.path}/bad.yaml');
      file.writeAsStringSync('''
name: bad
ruleSet:
  mode: custom
''');
      expect(() => CliConfig.loadProfile(file.path), throwsFormatException);
    });

    test('缺少 ruleSet 抛 FormatException', () {
      expect(
        () => CliConfig.parseYamlString('name: t1\ndefaults:\n  difficulty: easy\n'),
        throwsFormatException,
      );
    });
  });
}
