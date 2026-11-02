import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/entities/client_error_report.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/level_play_stats_repository.dart';
import 'package:winklo/domain/usecases/record_level_play.dart';
import 'package:winklo/domain/usecases/report_client_error.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockStats extends Mock implements LevelPlayStatsRepository {}

class _MockReport extends Mock implements ReportClientError {}

void main() {
  late _MockAuth auth;
  late _MockStats stats;
  late _MockReport report;
  late DateTime now;
  var remoteReady = true;

  setUpAll(() {
    registerFallbackValue(LevelPlayEvent.start);
    registerFallbackValue(
      const ClientErrorReport(severity: 'error', source: 'handled', code: 'x', message: 'x'),
    );
  });

  setUp(() {
    auth = _MockAuth();
    stats = _MockStats();
    report = _MockReport();
    now = DateTime(2026, 11, 2, 9);
    remoteReady = true;
    when(() => auth.currentUser).thenReturn(
      const AppUser(uid: 'u1', displayName: 'Ada'),
    );
    when(() => stats.increment(any(), any(), any(), any()))
        .thenAnswer((_) async {});
    when(() => report(any())).thenAnswer((_) async {});
  });

  RecordLevelPlay build() => RecordLevelPlay(
    auth: auth,
    stats: stats,
    reportClientError: report,
    isRemoteAvailable: () => remoteReady,
    now: () => now,
  );

  test('increments the event for the signed-in player', () async {
    await build()(game: 'zip', levelId: 'zip_1_01', event: LevelPlayEvent.start);
    verify(() => stats.increment('u1', 'zip', 'zip_1_01', LevelPlayEvent.start))
        .called(1);
  });

  test('records nothing when signed out', () async {
    when(() => auth.currentUser).thenReturn(null);
    await build()(game: 'zip', levelId: 'zip_1_01', event: LevelPlayEvent.clear);
    verifyNever(() => stats.increment(any(), any(), any(), any()));
  });

  test('records nothing before Firebase is ready', () async {
    remoteReady = false;
    await build()(game: 'zip', levelId: 'zip_1_01', event: LevelPlayEvent.hint);
    verifyNever(() => stats.increment(any(), any(), any(), any()));
  });

  test('a failed write is reported once per cooldown and never thrown', () async {
    when(() => stats.increment(any(), any(), any(), any()))
        .thenThrow(StateError('permission-denied'));
    final record = build();
    await record(game: 'zip', levelId: 'zip_1_01', event: LevelPlayEvent.start);
    await record(game: 'zip', levelId: 'zip_1_02', event: LevelPlayEvent.start);
    final reports = verify(() => report(captureAny())).captured;
    expect(reports, hasLength(1));
    final sent = reports.single as ClientErrorReport;
    expect(sent.code, 'level_stats_write_failed');
    expect(sent.uid, 'u1');

    now = now.add(const Duration(minutes: 11));
    await record(game: 'zip', levelId: 'zip_1_01', event: LevelPlayEvent.start);
    verify(() => report(any())).called(1);
  });

  test('a timeout is not reported', () async {
    when(() => stats.increment(any(), any(), any(), any()))
        .thenThrow(TimeoutException('slow'));
    await build()(game: 'zip', levelId: 'zip_1_01', event: LevelPlayEvent.start);
    verifyNever(() => report(any()));
  });
}
