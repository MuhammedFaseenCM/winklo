import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../cubit/profile_cubit.dart';
import '../../cubit/profile_state.dart';

/// Display-name editor. Expects [ProfileCubit] from the parent sheet route.
class NameEditSheet extends StatefulWidget {
  const NameEditSheet({super.key});

  @override
  State<NameEditSheet> createState() => _NameEditSheetState();
}

class _NameEditSheetState extends State<NameEditSheet> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: context.read<ProfileCubit>().state.nameDraft,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _syncName(String nameDraft) {
    if (_nameController.text == nameDraft) return;
    _nameController.value = TextEditingValue(
      text: nameDraft,
      selection: TextSelection.collapsed(offset: nameDraft.length),
    );
  }

  Future<void> _save() async {
    final cubit = context.read<ProfileCubit>();
    await cubit.saveName();
    if (!mounted) return;
    final state = cubit.state;
    final nameFailed =
        state.status == ProfileStatus.failure &&
        state.failureKind == ProfileFailureKind.name;
    if (state.status == ProfileStatus.idle && !nameFailed) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: BlocListener<ProfileCubit, ProfileState>(
            listenWhen: (previous, next) =>
                previous.nameDraft != next.nameDraft,
            listener: (context, state) => _syncName(state.nameDraft),
            child: BlocBuilder<ProfileCubit, ProfileState>(
              builder: (context, state) {
                final isSaving = state.status == ProfileStatus.saving;
                final nameError =
                    state.status == ProfileStatus.failure &&
                        state.failureKind == ProfileFailureKind.name
                    ? state.error
                    : null;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Color(0x33FFFFFF),
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      AppStrings.profileEditDisplayName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: ZipColors.onInk,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _nameController,
                      enabled: !isSaving,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(
                        color: ZipColors.onInk,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        labelText: AppStrings.profileEditName,
                        hintText: AppStrings.profileNameHint,
                        prefixIcon: const Icon(
                          Icons.badge_outlined,
                          color: ZipColors.inkSoft,
                        ),
                        errorText: nameError,
                      ),
                      onChanged: context.read<ProfileCubit>().setNameDraft,
                      onSubmitted: (_) => unawaited(_save()),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: isSaving ? null : () => unawaited(_save()),
                      child: const Text(AppStrings.profileSave),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
