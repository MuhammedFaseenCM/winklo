import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/pop_or_go_home.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/zip_ui.dart';

/// Where a league invite link (`/join/CODE`) lands until leagues ship. The
/// leagues work (roadmap batch area C) replaces it with the real join flow.
class JoinLinkPlaceholderScreen extends StatelessWidget {
  const JoinLinkPlaceholderScreen({super.key, required this.code});

  /// The code from the link, as typed.
  final String code;

  /// Invite codes are letters and digits; anything else in the link is
  /// dropped, and a link without a code shows none.
  static String displayCode(String raw) {
    final cleaned = raw.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
    return cleaned.length > 12 ? cleaned.substring(0, 12) : cleaned;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final shown = displayCode(code);
    return Scaffold(
      body: ZipAtmosphere(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: IconButton(
                    onPressed: () => popOrGoHome(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.group_add_rounded,
                        color: ZipColors.ember,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppStrings.joinLinkTitle,
                        textAlign: TextAlign.center,
                        style: textTheme.headlineSmall?.copyWith(
                          color: ZipColors.onInk,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (shown.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: ZipColors.emberSoft,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: ZipColors.ember.withValues(alpha: 0.45),
                              ),
                            ),
                            child: Text(
                              AppStrings.joinLinkCode(shown),
                              style: textTheme.titleMedium?.copyWith(
                                color: ZipColors.ember,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        AppStrings.joinLinkBody,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: ZipColors.inkSoft,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),
                      ZipPrimaryButton(
                        label: AppStrings.backHome,
                        icon: Icons.home_rounded,
                        onPressed: () => context.go('/'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
