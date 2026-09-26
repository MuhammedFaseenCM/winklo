import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../../core/strings/app_strings.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/failures.dart';
import '../../domain/repositories/issue_report_repository.dart';

const _issueReportsUnavailable = Failure(
  'Firebase is unavailable. Try again later.',
);

class IssueReportRepositoryImpl implements IssueReportRepository {
  IssueReportRepositoryImpl({this._firestore});

  final FirebaseFirestore? _firestore;

  FirebaseFirestore? get _db {
    if (!FirebaseBootstrap.isReady) return null;
    return _firestore ?? FirebaseFirestore.instance;
  }

  FirebaseFirestore _requireDb() {
    final db = _db;
    if (db == null) throw _issueReportsUnavailable;
    return db;
  }

  @override
  Future<void> submit({
    required String title,
    required String description,
    required AppUser user,
  }) async {
    final db = _requireDb();
    try {
      final info = await PackageInfo.fromPlatform();
      await db.collection('issue_reports').add({
        'title': title,
        'description': description,
        'uid': user.uid,
        'displayName': user.displayName,
        'photoUrl': user.photoUrl,
        'avatarId': user.avatarId,
        'appVersion': info.version,
        'buildNumber': info.buildNumber,
        'platform': defaultTargetPlatform.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on Failure {
      rethrow;
    } catch (e) {
      throw Failure(AppStrings.profileReportFailed, cause: e);
    }
  }
}
