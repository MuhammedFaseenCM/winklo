import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/zip_ui.dart';
import '../../../domain/entities/app_user.dart';
import '../../../domain/repositories/analytics_repository.dart';
import '../../../domain/usecases/submit_issue_report.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';
import '../cubit/profile_cubit.dart';
import '../cubit/report_issue_cubit.dart';
import '../cubit/report_issue_state.dart';

class ReportIssueScreen extends StatelessWidget {
  const ReportIssueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final routed = _routedUser(context);
    if (routed != null) {
      return _ReportIssueHost(user: routed);
    }

    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        final user = _profileUser(context) ?? authState.user;
        if (user == null) {
          if (authState.status == AuthStatus.unknown) {
            return const Scaffold(backgroundColor: ZipColors.ink);
          }
          return const _MissingUser();
        }
        return _ReportIssueHost(user: user);
      },
    );
  }
}

class _ReportIssueHost extends StatelessWidget {
  const _ReportIssueHost({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ReportIssueCubit(
        submitIssueReport: context.read<SubmitIssueReport>(),
        analytics: context.read<AnalyticsRepository>(),
        user: user,
      ),
      child: const _ReportIssueForm(),
    );
  }
}

AppUser? _routedUser(BuildContext context) {
  final extra = GoRouterState.of(context).extra;
  if (extra is AppUser) return extra;
  return null;
}

AppUser? _profileUser(BuildContext context) {
  try {
    return context.read<ProfileCubit>().state.profile;
  } on ProviderNotFoundException {
    // Child route is not under the profile screen's cubit.
    return null;
  }
}

class _MissingUser extends StatefulWidget {
  const _MissingUser();

  @override
  State<_MissingUser> createState() => _MissingUserState();
}

class _MissingUserState extends State<_MissingUser> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.canPop()) context.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(backgroundColor: ZipColors.ink);
  }
}

class _ReportIssueForm extends StatefulWidget {
  const _ReportIssueForm();

  @override
  State<_ReportIssueForm> createState() => _ReportIssueFormState();
}

class _ReportIssueFormState extends State<_ReportIssueForm> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<AnalyticsRepository>().logProfileReportOpened());
    });
  }

  Future<void> _submit() {
    return context.read<ReportIssueCubit>().submit();
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return Scaffold(
      backgroundColor: ZipColors.ink,
      appBar: AppBar(
        title: const Text(
          AppStrings.profileReportIssue,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: ZipColors.onInk,
      ),
      body: ZipAtmosphere(
        child: BlocListener<ReportIssueCubit, ReportIssueState>(
        listenWhen: (previous, next) => previous.status != next.status,
        listener: (context, state) {
          if (state.status == ReportIssueStatus.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text(AppStrings.profileReportSent)),
            );
            if (context.canPop()) context.pop();
            return;
          }
          if (state.status != ReportIssueStatus.failure) return;
          final message = state.error;
          if (message == null) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        },
        child: BlocBuilder<ReportIssueCubit, ReportIssueState>(
          builder: (context, state) {
            final isSubmitting = state.status == ReportIssueStatus.submitting;
            final isFormValid =
                state.titleDraft.trim().isNotEmpty &&
                state.descriptionDraft.trim().isNotEmpty;
            final canSend = isFormValid && !isSubmitting;
            return ListView(
              padding: layout.pagePadding,
              children: [
                TextField(
                  enabled: !isSubmitting,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 80,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  style: const TextStyle(color: ZipColors.onInk),
                  decoration: const InputDecoration(
                    labelText: AppStrings.profileReportTitleLabel,
                    hintText: AppStrings.profileReportTitleHint,
                  ),
                  onChanged: context.read<ReportIssueCubit>().setTitle,
                ),
                SizedBox(height: layout.space(12)),
                TextField(
                  enabled: !isSubmitting,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 5,
                  maxLines: 8,
                  maxLength: 2000,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  style: const TextStyle(color: ZipColors.onInk),
                  decoration: const InputDecoration(
                    labelText: AppStrings.profileReportDescriptionLabel,
                    hintText: AppStrings.profileReportDescriptionHint,
                    alignLabelWithHint: true,
                  ),
                  onChanged: context.read<ReportIssueCubit>().setDescription,
                ),
                SizedBox(height: layout.space(16)),
                FilledButton(
                  onPressed: canSend ? () => unawaited(_submit()) : null,
                  child: const Text(AppStrings.profileReportSend),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
}
