import 'package:flutter_bloc/flutter_bloc.dart';

import '../storage/signup_profile_storage.dart';

class UserProfileState {
  const UserProfileState({
    required this.currency,
    required this.loaded,
  });

  final String currency;
  final bool loaded;

  UserProfileState copyWith({String? currency, bool? loaded}) {
    return UserProfileState(
      currency: currency ?? this.currency,
      loaded: loaded ?? this.loaded,
    );
  }

  static const initial = UserProfileState(currency: '₹', loaded: false);
}

class UserProfileCubit extends Cubit<UserProfileState> {
  UserProfileCubit() : super(UserProfileState.initial) {
    refresh();
  }

  Future<void> refresh() async {
    final profile = await SignupProfileStorage.getProfile();
    final nextCurrency = (profile?.currency ?? '').trim();
    emit(
      state.copyWith(
        currency: nextCurrency.isEmpty ? '₹' : nextCurrency,
        loaded: true,
      ),
    );
  }
}
