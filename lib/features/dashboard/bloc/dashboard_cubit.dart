import 'package:bloc/bloc.dart';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';

import '../../../core/storage/admin_profile_storage.dart';
import 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit() : super(const DashboardState());

  /// Load persisted admin profile from local storage.
  Future<void> loadProfile() async {
    final data = await AdminProfileStorage.load();
    if (data == null) return;
    final name = (data['userName'] as String?)?.trim() ?? '';
    final middleName = (data['userMiddleName'] as String?)?.trim() ?? '';
    final email = (data['userEmail'] as String?)?.trim() ?? '';
    final phone = (data['userPhone'] as String?)?.trim() ?? '';
    final gender = (data['userGender'] as String?)?.trim() ?? '';
    final dobStr = data['userDateOfBirth'] as String?;
    DateTime? dob;
    if (dobStr != null && dobStr.isNotEmpty) {
      dob = DateTime.tryParse(dobStr);
    }
    emit(state.copyWith(
      userName: name.isNotEmpty ? name : null,
      userMiddleName: middleName.isNotEmpty ? middleName : null,
      userEmail: email.isNotEmpty ? email : null,
      userPhone: phone.isNotEmpty ? phone : null,
      userGender: gender.isNotEmpty ? gender : null,
      userDateOfBirth: dob,
    ));
  }

  /// Persist current profile fields to local storage.
  Future<void> _persist() async {
    await AdminProfileStorage.save(
      userName: state.userName,
      userMiddleName: state.userMiddleName,
      userEmail: state.userEmail,
      userPhone: state.userPhone,
      userGender: state.userGender,
      userDateOfBirth: state.userDateOfBirth,
    );
  }

  void selectTab(DashboardTab tab) {
    if (state.tab == tab) return;
    emit(state.copyWith(tab: tab));
  }

  void setUserName(String name) {
    if ((state.userName ?? 'User') == name) return;
    emit(state.copyWith(userName: name));
    _persist();
  }

  void setUserMiddleName(String middleName) {
    final trimmed = middleName.trim();
    if ((state.userMiddleName ?? '').trim() == trimmed) return;
    emit(state.copyWith(userMiddleName: trimmed));
    _persist();
  }

  void setUserEmail(String email) {
    final trimmed = email.trim();
    if ((state.userEmail ?? '').trim() == trimmed) return;
    emit(state.copyWith(userEmail: trimmed));
    _persist();
  }

  void setUserPhone(String phone) {
    final trimmed = phone.trim();
    if ((state.userPhone ?? '').trim() == trimmed) return;
    emit(state.copyWith(userPhone: trimmed));
    _persist();
  }

  void setUserGender(String gender) {
    final trimmed = gender.trim();
    if ((state.userGender ?? '').trim() == trimmed) return;
    emit(state.copyWith(userGender: trimmed));
    _persist();
  }

  void setUserDateOfBirth(DateTime dob) {
    if (state.userDateOfBirth == dob) return;
    emit(state.copyWith(userDateOfBirth: dob));
    _persist();
  }

  void setUserAvatarBytes(Uint8List? bytes) {
    if (identical(state.userAvatarBytes, bytes)) return;
    emit(state.copyWith(userAvatarBytes: bytes));
  }

  void setUserAvatarAlignment(Alignment alignment) {
    if (state.userAvatarAlignment == alignment) return;
    emit(state.copyWith(userAvatarAlignment: alignment));
  }

  void setClassesToday(int count) {
    if ((state.classesToday ?? 0) == count) return;
    emit(state.copyWith(classesToday: count));
  }

  void setScheduleSummary({required int completed, required int remaining, required int total}) {
    if ((state.classesCompleted ?? 0) == completed &&
        (state.classesRemaining ?? 0) == remaining &&
        (state.classesTotal ?? 0) == total) {
      return;
    }
    emit(state.copyWith(
      classesCompleted: completed,
      classesRemaining: remaining,
      classesTotal: total,
    ));
  }
}
