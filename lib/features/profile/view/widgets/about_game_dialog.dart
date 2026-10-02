import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/zip_ui.dart';
import '../../../../domain/repositories/analytics_repository.dart';

Future<void> showAboutGameDialog(BuildContext context) async {
  final info = await PackageInfo.fromPlatform();
  if (!context.mounted) return;

  unawaited(context.read<AnalyticsRepository>().logProfileAboutOpened());

  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: ZipColors.wall,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      side: BorderSide(color: ZipColors.glassBorder),
    ),
    builder: (sheetContext) {
      return _AboutGameSheet(version: info.version);
    },
  );
}

class _AboutGameSheet extends StatelessWidget {
  const _AboutGameSheet({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const ZipMark(size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppStrings.profileAboutGame,
                      style: textTheme.titleMedium?.copyWith(
                        color: ZipColors.onInk,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                AppStrings.profileAboutBody,
                style: textTheme.bodyMedium?.copyWith(
                  color: ZipColors.onInk,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                AppStrings.profileAboutGamesHeading,
                style: textTheme.titleSmall?.copyWith(
                  color: ZipColors.onInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              const _AboutGameCard(
                title: AppStrings.zipTitle,
                description: AppStrings.zipTagline,
                icon: Icons.bolt_rounded,
                accent: ZipColors.ember,
                accentSoft: ZipColors.emberSoft,
                gradient: ZipColors.emberGradient,
              ),
              const SizedBox(height: 10),
              const _AboutGameCard(
                title: AppStrings.pathWordsTitle,
                description: AppStrings.pathWordsTagline,
                icon: Icons.route_rounded,
                accent: ZipColors.sky,
                accentSoft: ZipColors.skySoft,
                gradient: ZipColors.skyGradient,
              ),
              const SizedBox(height: 10),
              const _AboutGameCard(
                title: AppStrings.sudokuTitle,
                description: AppStrings.sudokuTagline,
                icon: Icons.grid_on_rounded,
                accent: ZipColors.success,
                accentSoft: ZipColors.successSoft,
                gradient: ZipColors.successGradient,
              ),
              const SizedBox(height: 20),
              Text(
                AppStrings.profileAboutDailyHeading,
                style: textTheme.titleSmall?.copyWith(
                  color: ZipColors.onInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0x14FFFFFF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x1AFFFFFF)),
                ),
                child: Text(
                  AppStrings.profileAboutDailyBody,
                  style: textTheme.bodyMedium?.copyWith(
                    color: ZipColors.onInk,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                AppStrings.profileAboutVersion(version),
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: ZipColors.inkSoft,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(AppStrings.tutorialGotIt),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutGameCard extends StatelessWidget {
  const _AboutGameCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.accentSoft,
    required this.gradient,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color accent;
  final Color accentSoft;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: ZipColors.cardGradient,
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(gradient: gradient),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: accentSoft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Icon(icon, color: accent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: textTheme.titleSmall?.copyWith(
                                color: ZipColors.onInk,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              description,
                              style: textTheme.bodySmall?.copyWith(
                                color: ZipColors.inkSoft,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
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
