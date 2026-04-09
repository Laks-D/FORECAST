import 'package:bloc/bloc.dart';

import 'app_mode.dart';
import 'app_mode_storage.dart';

class AppModeState {
  const AppModeState({
    required this.loaded,
    required this.mode,
    required this.forced,
  });

  final bool loaded;
  final AppMode? mode;
  final bool forced;

  AppModeState copyWith({
    bool? loaded,
    AppMode? mode,
    bool? forced,
  }) {
    return AppModeState(
      loaded: loaded ?? this.loaded,
      mode: mode ?? this.mode,
      forced: forced ?? this.forced,
    );
  }
}

class AppModeCubit extends Cubit<AppModeState> {
  AppModeCubit({AppMode? forcedMode})
      : super(
          AppModeState(
            loaded: forcedMode != null,
            mode: forcedMode,
            forced: forcedMode != null,
          ),
        ) {
    if (forcedMode != null) {
      AppModeConfig.mode = forcedMode;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final m = await AppModeStorage.load();
      final effective = m ?? AppMode.admin;
      AppModeConfig.mode = effective;
      emit(state.copyWith(loaded: true, mode: effective));
    } catch (_) {
      AppModeConfig.mode = AppMode.admin;
      emit(state.copyWith(loaded: true, mode: AppMode.admin));
    }
  }

  Future<void> setMode(AppMode mode) async {
    if (state.forced) return;
    AppModeConfig.mode = mode;
    emit(state.copyWith(loaded: true, mode: mode));
    try {
      await AppModeStorage.save(mode);
    } catch (_) {
      // Ignore persistence failures.
    }
  }
}
