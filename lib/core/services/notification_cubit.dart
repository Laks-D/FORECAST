
import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'notification_storage.dart';

final class NotificationState extends Equatable {
	const NotificationState({
		required this.loading,
		required this.sessionReminders,
		required this.sessionLeadMinutes,
		required this.paymentReminders,
		required this.paymentReminderHour,
		required this.paymentReminderMinute,
		required this.paymentDaysBefore,
		required this.paymentOverdueDaily,
		required this.records,
	});

	final bool loading;

	final bool sessionReminders;
	final int sessionLeadMinutes;

	final bool paymentReminders;
	final int paymentReminderHour;
	final int paymentReminderMinute;
	final int paymentDaysBefore;
	final bool paymentOverdueDaily;

	final List<AppNotification> records;

	int get unreadCount => records.where((e) => !e.read).length;

	NotificationState copyWith({
		bool? loading,
		bool? sessionReminders,
		int? sessionLeadMinutes,
		bool? paymentReminders,
		int? paymentReminderHour,
		int? paymentReminderMinute,
		int? paymentDaysBefore,
		bool? paymentOverdueDaily,
		List<AppNotification>? records,
	}) {
		return NotificationState(
			loading: loading ?? this.loading,
			sessionReminders: sessionReminders ?? this.sessionReminders,
			sessionLeadMinutes: sessionLeadMinutes ?? this.sessionLeadMinutes,
			paymentReminders: paymentReminders ?? this.paymentReminders,
			paymentReminderHour: paymentReminderHour ?? this.paymentReminderHour,
			paymentReminderMinute: paymentReminderMinute ?? this.paymentReminderMinute,
			paymentDaysBefore: paymentDaysBefore ?? this.paymentDaysBefore,
			paymentOverdueDaily: paymentOverdueDaily ?? this.paymentOverdueDaily,
			records: records ?? this.records,
		);
	}

	static NotificationState defaults() {
		const p = NotificationStorage.defaultPrefs;
		return NotificationState(
			loading: true,
			sessionReminders: p['sessionReminders'] as bool? ?? true,
			sessionLeadMinutes: p['sessionLeadMinutes'] as int? ?? 5,
			paymentReminders: p['paymentReminders'] as bool? ?? true,
			paymentReminderHour: p['paymentReminderHour'] as int? ?? 8,
			paymentReminderMinute: p['paymentReminderMinute'] as int? ?? 0,
			paymentDaysBefore: p['paymentDaysBefore'] as int? ?? 0,
			paymentOverdueDaily: p['paymentOverdueDaily'] as bool? ?? true,
			records: const <AppNotification>[],
		);
	}

	@override
	List<Object?> get props => [
				loading,
				sessionReminders,
				sessionLeadMinutes,
				paymentReminders,
				paymentReminderHour,
				paymentReminderMinute,
				paymentDaysBefore,
				paymentOverdueDaily,
				records,
			];
}

class NotificationCubit extends Cubit<NotificationState> {
	NotificationCubit() : super(NotificationState.defaults()) {
		_authSub = FirebaseAuth.instance.authStateChanges().listen((_) => _load());
		_load();
	}

	StreamSubscription<User?>? _authSub;

	Future<void> _load() async {
		emit(state.copyWith(loading: true));
		final prefs = await NotificationStorage.loadPrefs();
		final records = await NotificationStorage.loadRecords();

		emit(
			state.copyWith(
				loading: false,
				sessionReminders: (prefs['sessionReminders'] as bool?) ?? state.sessionReminders,
				sessionLeadMinutes: (prefs['sessionLeadMinutes'] as int?) ?? state.sessionLeadMinutes,
				paymentReminders: (prefs['paymentReminders'] as bool?) ?? state.paymentReminders,
				paymentReminderHour: (prefs['paymentReminderHour'] as int?) ?? state.paymentReminderHour,
				paymentReminderMinute: (prefs['paymentReminderMinute'] as int?) ?? state.paymentReminderMinute,
				paymentDaysBefore: (prefs['paymentDaysBefore'] as int?) ?? state.paymentDaysBefore,
				paymentOverdueDaily: (prefs['paymentOverdueDaily'] as bool?) ?? state.paymentOverdueDaily,
				records: _sortNewestFirst(records),
			),
		);
	}

	static List<AppNotification> _sortNewestFirst(List<AppNotification> items) {
		final out = [...items];
		out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
		return out;
	}

	Future<void> _persistPrefs() {
		final data = <String, dynamic>{
			'sessionReminders': state.sessionReminders,
			'sessionLeadMinutes': state.sessionLeadMinutes,
			'paymentReminders': state.paymentReminders,
			'paymentReminderHour': state.paymentReminderHour,
			'paymentReminderMinute': state.paymentReminderMinute,
			'paymentDaysBefore': state.paymentDaysBefore,
			'paymentOverdueDaily': state.paymentOverdueDaily,
		};
		return NotificationStorage.savePrefs(data);
	}

	/* ─────── Preferences API (used by NotificationSettingsPage) ─────── */

	Future<void> toggleSessionReminders(bool enabled) async {
		emit(state.copyWith(sessionReminders: enabled));
		await _persistPrefs();
	}

	Future<void> setSessionLeadMinutes(int minutes) async {
		emit(state.copyWith(sessionLeadMinutes: minutes));
		await _persistPrefs();
	}

	Future<void> togglePaymentReminders(bool enabled) async {
		emit(state.copyWith(paymentReminders: enabled));
		await _persistPrefs();
	}

	Future<void> setPaymentReminderTime(int hour, int minute) async {
		emit(state.copyWith(paymentReminderHour: hour, paymentReminderMinute: minute));
		await _persistPrefs();
	}

	Future<void> setPaymentDaysBefore(int days) async {
		emit(state.copyWith(paymentDaysBefore: days));
		await _persistPrefs();
	}

	Future<void> togglePaymentOverdueDaily(bool enabled) async {
		emit(state.copyWith(paymentOverdueDaily: enabled));
		await _persistPrefs();
	}

	/* ─────── Records API (used by NotificationsPage) ─────── */

	Future<void> addRecord(AppNotification record) async {
		final next = _sortNewestFirst([record, ...state.records]);
		emit(state.copyWith(records: next));
		await NotificationStorage.saveRecords(next);
	}

	Future<void> markRead(String id) async {
		final next = state.records.map((e) => e.id == id ? e.copyWith(read: true) : e).toList(growable: false);
		emit(state.copyWith(records: next));
		await NotificationStorage.saveRecords(next);
	}

	Future<void> markAllRead() async {
		final next = state.records.map((e) => e.copyWith(read: true)).toList(growable: false);
		emit(state.copyWith(records: next));
		await NotificationStorage.saveRecords(next);
	}

	Future<void> deleteRecord(String id) async {
		final next = state.records.where((e) => e.id != id).toList(growable: false);
		emit(state.copyWith(records: next));
		await NotificationStorage.saveRecords(next);
	}

	Future<void> clearAll() async {
		emit(state.copyWith(records: const <AppNotification>[]));
		await NotificationStorage.clearRecords();
	}

	@override
	Future<void> close() async {
		await _authSub?.cancel();
		return super.close();
	}
}

