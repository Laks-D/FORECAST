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
    if (isClosed || data == null) return;
    final name = (data['userName'] as String?)?.trim() ?? '';
    final handle = (data['userHandle'] as String?)?.trim() ?? '';
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
      userHandle: handle.isNotEmpty ? handle : null,
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
      userHandle: state.userHandle,
      userMiddleName: state.userMiddleName,
      userEmail: state.userEmail,
      userPhone: state.userPhone,
      userGender: state.userGender,
      userDateOfBirth: state.userDateOfBirth,
    );
  }

  void selectTab(DashboardTab tab) {
    if (isClosed || state.tab == tab) return;
    emit(state.copyWith(tab: tab));
  }

  void updateProfile({
    String? name,
    String? handle,
    String? middleName,
    String? email,
    String? phone,
    String? gender,
    DateTime? dob,
  }) {
    if (isClosed) return;
    emit(state.copyWith(
      userName: name?.trim() ?? state.userName,
      userHandle: handle?.trim() ?? state.userHandle,
      userMiddleName: middleName?.trim() ?? state.userMiddleName,
      userEmail: email?.trim() ?? state.userEmail,
      userPhone: phone?.trim() ?? state.userPhone,
      userGender: gender?.trim() ?? state.userGender,
      userDateOfBirth: dob ?? state.userDateOfBirth,
    ));
    _persist();
  }

  void setUserHandle(String handle) {
    if (isClosed || (state.userHandle ?? '') == handle) return;
    emit(state.copyWith(userHandle: handle));
    _persist();
  }

  void setUserName(String name) {
    if (isClosed || (state.userName ?? 'User') == name) return;
    emit(state.copyWith(userName: name));
    _persist();
  }

  void setUserMiddleName(String middleName) {
    final trimmed = middleName.trim();
    if (isClosed || (state.userMiddleName ?? '').trim() == trimmed) return;
    emit(state.copyWith(userMiddleName: trimmed));
    _persist();
  }

  void setUserEmail(String email) {
    final trimmed = email.trim();
    if (isClosed || (state.userEmail ?? '').trim() == trimmed) return;
    emit(state.copyWith(userEmail: trimmed));
    _persist();
  }

  void setUserPhone(String phone) {
    final trimmed = phone.trim();
    if (isClosed || (state.userPhone ?? '').trim() == trimmed) return;
    emit(state.copyWith(userPhone: trimmed));
    _persist();
  }

  void setUserGender(String gender) {
    final trimmed = gender.trim();
    if (isClosed || (state.userGender ?? '').trim() == trimmed) return;
    emit(state.copyWith(userGender: trimmed));
    _persist();
  }

  void setUserDateOfBirth(DateTime dob) {
    if (isClosed || state.userDateOfBirth == dob) return;
    emit(state.copyWith(userDateOfBirth: dob));
    _persist();
  }

  void setUserAvatarBytes(Uint8List? bytes) {
    if (isClosed || identical(state.userAvatarBytes, bytes)) return;
    emit(state.copyWith(userAvatarBytes: bytes));
  }

  void setUserAvatarAlignment(Alignment alignment) {
    if (isClosed || state.userAvatarAlignment == alignment) return;
    emit(state.copyWith(userAvatarAlignment: alignment));
  }

  void setClassesToday(int count) {
    if (isClosed || (state.classesToday ?? 0) == count) return;
    emit(state.copyWith(classesToday: count));
  }

  void setScheduleSummary({required int completed, required int remaining, required int total}) {
    if (isClosed) return;
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
