import 'package:equatable/equatable.dart';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';

enum DashboardTab { calendar, people, cards, home, phone, settings }

final class DashboardState extends Equatable {
  const DashboardState({
    this.tab = DashboardTab.home,
    this.userName = 'User',
    this.userMiddleName,
    this.userEmail,
    this.userPhone,
    this.userGender,
    this.userDateOfBirth,
    this.userAvatarBytes,
    this.userAvatarAlignment = Alignment.center,
    this.classesToday = 5,
    this.classesMin = 0,
    this.classesMax = 12,
    this.classesCompleted = 1,
    this.classesRemaining = 4,
    this.classesTotal = 5,
  });

  final DashboardTab tab;

  final String? userName;
  final String? userMiddleName;
  final String? userEmail;
  final String? userPhone;
  final String? userGender;
  final DateTime? userDateOfBirth;

  final Uint8List? userAvatarBytes;
  final Alignment userAvatarAlignment;

  final int? classesToday;
  final int? classesMin;
  final int? classesMax;

  final int? classesCompleted;
  final int? classesRemaining;
  final int? classesTotal;

  DashboardState copyWith({
    DashboardTab? tab,
    String? userName,
    String? userMiddleName,
    String? userEmail,
    String? userPhone,
    String? userGender,
    DateTime? userDateOfBirth,
    Uint8List? userAvatarBytes,
    Alignment? userAvatarAlignment,
    int? classesToday,
    int? classesMin,
    int? classesMax,
    int? classesCompleted,
    int? classesRemaining,
    int? classesTotal,
  }) {
    return DashboardState(
      tab: tab ?? this.tab,
      userName: userName ?? this.userName,
      userMiddleName: userMiddleName ?? this.userMiddleName,
      userEmail: userEmail ?? this.userEmail,
      userPhone: userPhone ?? this.userPhone,
      userGender: userGender ?? this.userGender,
      userDateOfBirth: userDateOfBirth ?? this.userDateOfBirth,
      userAvatarBytes: userAvatarBytes ?? this.userAvatarBytes,
      userAvatarAlignment: userAvatarAlignment ?? this.userAvatarAlignment,
      classesToday: classesToday ?? this.classesToday,
      classesMin: classesMin ?? this.classesMin,
      classesMax: classesMax ?? this.classesMax,
      classesCompleted: classesCompleted ?? this.classesCompleted,
      classesRemaining: classesRemaining ?? this.classesRemaining,
      classesTotal: classesTotal ?? this.classesTotal,
    );
  }

  @override
  List<Object?> get props => [
        tab,
      userName,
        userMiddleName,
        userEmail,
        userPhone,
        userGender,
        userDateOfBirth,
        userAvatarBytes,
        userAvatarAlignment,
        classesToday,
        classesMin,
        classesMax,
        classesCompleted,
        classesRemaining,
        classesTotal,
      ];
}
