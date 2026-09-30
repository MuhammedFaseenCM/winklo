import 'dart:convert';

import 'package:winklo/core/firebase/firebase_bootstrap.dart';
import 'package:winklo/domain/entities/zip_level.dart';
import 'package:winklo/domain/play_period.dart';
import 'package:winklo/domain/repositories/zip_level_repository.dart';
import 'package:winklo/features/zip/logic/daily_puzzle_generator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class ZipLevelRepositoryImpl implements ZipLevelRepository {
  ZipLevelRepositoryImpl({
    FirebaseFirestore? firestore,
    AssetBundle? assetBundle,
  }) : _firestore =
           firestore ??
           (FirebaseBootstrap.isReady ? FirebaseFirestore.instance : null),
       _assetBundle = assetBundle ?? rootBundle;

  final FirebaseFirestore? _firestore;
  final AssetBundle _assetBundle;

  static const _assetFiles = [
    'assets/zip/levels/level_01.json',
    'assets/zip/levels/level_02.json',
    'assets/zip/levels/level_03.json',
  ];

  @override
  Future<ZipLevel> fetchDailyLevel(
    DateTime date, {
    Duration period = PlayPeriod.daily,
  }) async {
    final id = DailyPuzzleGenerator.dateId(date, period: period);
    final firestore = _firestore;
    if (firestore != null) {
      try {
        final doc = await firestore
            .collection('zip_levels')
            .doc(id)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 2));
        if (doc.exists && doc.data() != null) {
          return ZipLevel.fromJson(doc.data()!, id: doc.id);
        }
      } catch (_) {
        // fall through to local generator
      }
    }
    return DailyPuzzleGenerator.forDate(date, period: period);
  }

  @override
  Future<List<ZipLevel>> fetchLevels() async {
    final firestore = _firestore;
    if (firestore != null) {
      try {
        final snap = await firestore
            .collection('zip_levels')
            .orderBy('order')
            .get(const GetOptions(source: Source.serverAndCache));
        if (snap.docs.isNotEmpty) {
          return snap.docs
              .map((d) => ZipLevel.fromJson(d.data(), id: d.id))
              .toList();
        }
      } catch (_) {
        // fall through to assets
      }
    }
    return _loadAssets();
  }

  Future<List<ZipLevel>> _loadAssets() async {
    final levels = <ZipLevel>[];
    for (final path in _assetFiles) {
      final raw = await _assetBundle.loadString(path);
      levels.add(ZipLevel.fromJson(jsonDecode(raw) as Map<String, dynamic>));
    }
    levels.sort((a, b) => a.order.compareTo(b.order));
    return levels;
  }
}
