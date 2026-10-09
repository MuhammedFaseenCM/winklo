import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/logic/run_rollover.dart';
import 'package:winklo/domain/play_period.dart';

void main() {
  test('a run can be finished on its own day and the next', () {
    expect(
      canFinishRun('20261009', DateTime(2026, 10, 9, 23), PlayPeriod.daily),
      isTrue,
    );
    expect(
      canFinishRun('20261009', DateTime(2026, 10, 10, 0, 5), PlayPeriod.daily),
      isTrue,
    );
  });

  test('a run older than that gives way to the current puzzle', () {
    expect(
      canFinishRun('20261009', DateTime(2026, 10, 11, 0, 5), PlayPeriod.daily),
      isFalse,
    );
  });

  test('debug minute periods carry over one minute', () {
    expect(
      canFinishRun(
        '202610091200',
        DateTime(2026, 10, 9, 12, 1, 30),
        PlayPeriod.minute,
      ),
      isTrue,
    );
    expect(
      canFinishRun(
        '202610091200',
        DateTime(2026, 10, 9, 12, 2, 30),
        PlayPeriod.minute,
      ),
      isFalse,
    );
  });
}
