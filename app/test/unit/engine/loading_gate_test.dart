/// T-DOM-02 · 加载闸门测试（P0-ENG-12：>300ms 自动上抛 loading）。
///
/// 使用注入的短阈值加速测试；同时断言默认阈值为 300ms（架构 §7.7）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/domain/engine/loading_gate.dart';

void main() {
  test('默认阈值是 300ms（架构 §7.7 常量）', () {
    expect(kLoadingThreshold, const Duration(milliseconds: 300));
    expect(LoadingGate().threshold, const Duration(milliseconds: 300));
  });

  test('超过阈值未完成 → 上抛 loading=true；完成后复位 false', () async {
    final List<bool> changes = <bool>[];
    final LoadingGate gate = LoadingGate(
      threshold: const Duration(milliseconds: 20),
      onChanged: changes.add,
    );
    expect(gate.isLoading, isFalse);

    final Future<int> future = gate.run(() async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return 42;
    });

    // 60ms 时任务尚未完成，loading 应已上抛。
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(gate.isLoading, isTrue);
    expect(changes, contains(true));

    final int result = await future;
    expect(result, 42);
    expect(gate.isLoading, isFalse);
    expect(changes, <bool>[true, false]);
  });

  test('未超过阈值 → 不上抛 loading', () async {
    final List<bool> changes = <bool>[];
    final LoadingGate gate = LoadingGate(
      threshold: const Duration(milliseconds: 100),
      onChanged: changes.add,
    );

    await gate.run(() async => 1);
    expect(changes, isEmpty, reason: '快任务不应触发 loading');
    expect(gate.isLoading, isFalse);
  });

  test('onChanged 可稍后赋值（provider 装配场景）', () async {
    final LoadingGate gate = LoadingGate(
      threshold: const Duration(milliseconds: 20),
    );
    final List<bool> changes = <bool>[];
    gate.onChanged = changes.add;

    await gate.run(() async {
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    expect(changes, contains(true));
    expect(gate.isLoading, isFalse);
  });

  test('任务抛错时 loading 也复位（finally 语义）', () async {
    final LoadingGate gate = LoadingGate(
      threshold: const Duration(milliseconds: 20),
    );
    await expectLater(
      gate.run<void>(() async {
        await Future<void>.delayed(const Duration(milliseconds: 60));
        throw StateError('boom');
      }),
      throwsA(isA<StateError>()),
    );
    expect(gate.isLoading, isFalse);
  });

  test('dispose 取消定时器（无泄漏）', () {
    final LoadingGate gate = LoadingGate();
    gate.dispose();
    expect(gate.isLoading, isFalse);
  });
}
