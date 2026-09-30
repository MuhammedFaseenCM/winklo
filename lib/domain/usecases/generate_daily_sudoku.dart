import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:winklo/core/firebase/firebase_bootstrap.dart';
import 'package:winklo/domain/entities/sudoku_puzzle.dart';
import 'package:winklo/domain/play_period.dart';
import 'package:winklo/domain/sudoku/sudoku_generator.dart';

class GenerateDailySudoku {
  GenerateDailySudoku({
    this.period = PlayPeriod.daily,
    FirebaseFirestore? firestore,
  }) : _firestore =
           firestore ??
           (FirebaseBootstrap.isReady ? FirebaseFirestore.instance : null);

  final Duration period;
  final FirebaseFirestore? _firestore;

  Future<SudokuPuzzle> call({required DateTime day}) async {
    final local = day.toLocal();
    final bucket = PlayPeriod.bucket(local, period);
    final dateId = PlayPeriod.id(bucket, period);

    final firestore = _firestore;
    if (firestore != null) {
      try {
        var doc = await firestore
            .collection('sudoku_levels')
            .doc('daily_$dateId')
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 2));
        if (!doc.exists) {
          doc = await firestore
              .collection('sudoku_levels')
              .doc('sudoku_$dateId')
              .get(const GetOptions(source: Source.serverAndCache))
              .timeout(const Duration(seconds: 2));
        }
        if (doc.exists && doc.data() != null) {
          return SudokuPuzzle.fromJson(doc.data()!, id: doc.id);
        }
      } catch (_) {
        // Fall through to procedural generator
      }
    }

    return SudokuGenerator.generate(day: day, period: period);
  }
}
