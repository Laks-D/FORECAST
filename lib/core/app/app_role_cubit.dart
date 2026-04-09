import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_role.dart';
import 'app_role_storage.dart';

class AppRoleState {
  const AppRoleState({
    required this.role,
    required this.loaded,
  });

  final AppRole role;
  final bool loaded;

  AppRoleState copyWith({
    AppRole? role,
    bool? loaded,
  }) {
    return AppRoleState(
      role: role ?? this.role,
      loaded: loaded ?? this.loaded,
    );
  }

  static const initial = AppRoleState(role: AppRole.tutor, loaded: false);
}

class AppRoleCubit extends Cubit<AppRoleState> {
  AppRoleCubit() : super(AppRoleState.initial) {
    refresh();
  }

  Future<void> refresh() async {
    final role = await AppRoleStorage.load();
    emit(state.copyWith(role: role, loaded: true));
  }

  Future<void> setRole(AppRole role) async {
    emit(state.copyWith(role: role, loaded: true));
    await AppRoleStorage.save(role);
  }
}
