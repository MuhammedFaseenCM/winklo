import 'package:share_plus/share_plus.dart';

import '../../domain/repositories/share_repository.dart';

class ShareRepositoryImpl implements ShareRepository {
  @override
  Future<bool> shareText(String text) async {
    final result = await SharePlus.instance.share(ShareParams(text: text));
    return result.status != ShareResultStatus.dismissed;
  }
}
