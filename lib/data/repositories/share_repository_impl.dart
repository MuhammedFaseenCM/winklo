import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/failures.dart';
import '../../domain/repositories/share_repository.dart';

class ShareRepositoryImpl implements ShareRepository {
  ShareRepositoryImpl({Future<ShareResult> Function(ShareParams params)? share})
    : _share = share ?? SharePlus.instance.share;

  final Future<ShareResult> Function(ShareParams params) _share;

  @override
  Future<bool> shareText(String text) async {
    try {
      final result = await _share(ShareParams(text: text));
      // Android reports the picked app from 5.1 (API 22) on; there,
      // `unavailable` only comes back when a second share replaces a pending
      // one, so it isn't a share.
      return result.status == ShareResultStatus.success;
    } on PlatformException catch (e) {
      throw Failure('Could not open the share sheet', cause: e);
    }
  }
}
