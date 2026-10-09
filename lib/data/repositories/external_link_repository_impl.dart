import 'package:url_launcher/url_launcher.dart';

import '../../domain/repositories/external_link_repository.dart';

class ExternalLinkRepositoryImpl implements ExternalLinkRepository {
  @override
  Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
