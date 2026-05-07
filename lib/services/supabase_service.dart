import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;

/// Production-grade Supabase service with relational schema mapping
/// Manages: profiles (id: TEXT/owner_id)
///          organizations (id: UUID, owner_id: TEXT)
///          programs (id: UUID, org_id: UUID)
///          students (id: UUID, org_id: UUID)
///          activities (id: UUID, student_id: UUID, org_id: UUID, activity_type: TEXT)
class SupabaseService {
	SupabaseService._internal();

	static final SupabaseService _instance = SupabaseService._internal();

	factory SupabaseService() => _instance;

	static SupabaseService get instance => _instance;

	SupabaseClient get client => Supabase.instance.client;

	void _logDebug(String message) {
		developer.log(message, name: 'SupabaseService');
	}

	void _logError(String message) {
		developer.log(message, name: 'SupabaseService.ERROR', level: 1000);
	}

	void _logSuccess(String message) {
		developer.log(message, name: 'SupabaseService.SUCCESS', level: 0);
	}

	void checkConnectivity() {
		try {
			final dynamic supabaseUrl = (Supabase.instance.client as dynamic).supabaseUrl;
			_logDebug('DEBUG: Supabase URL: $supabaseUrl');
		} catch (e) {
			_logDebug('DEBUG: Supabase URL: unavailable via client.supabaseUrl | fallback error: $e');
		}
		_logDebug('DEBUG: Supabase Session: ${Supabase.instance.client.auth.currentSession}');
	}

	String _clean(String value) => value.trim();

	/// Print exact PostgreSQL exception details for debugging
	void _printPostgrestException(String method, PostgrestException error) {
		final code = error.code ?? 'unknown';
		final message = error.message;
		final hint = error.hint ?? 'n/a';
		final details = error.details ?? 'n/a';

		_logError('[$method] PostgrestException - code: $code | message: $message | hint: $hint | details: $details');

		// Specific diagnostics
		if (code == '42501' || code == '42P01') {
			_logError('[$method] PERMISSION DENIED or TABLE NOT FOUND. Verify RLS policies and table existence.');
		}
		if (code == '23505') {
			_logError('[$method] UNIQUE CONSTRAINT VIOLATED. Record with this ID/key already exists.');
		}
		if (code == '23502') {
			_logError('[$method] NOT NULL CONSTRAINT VIOLATED. Required field is missing.');
		}
	}

	/// Upsert user profile with Firebase UID as TEXT primary key
	/// Must complete before any organization/program/student operations
	/// Prints "SYNC_SUCCESS" on success or exact PostgrestException on failure
	Future<void> syncUser(
		String uid,
		String email, {
		String? displayName,
		String? photoUrl,
	}) async {
		final cleanedUid = _clean(uid);
		final cleanedEmail = _clean(email);
		final cleanedDisplayName = displayName == null ? null : _clean(displayName);
		final cleanedPhotoUrl = photoUrl == null ? null : _clean(photoUrl);

		if (cleanedUid.isEmpty) {
			throw ArgumentError('uid cannot be empty');
		}

		final payload = <String, dynamic>{
			'id': cleanedUid,
			'email': cleanedEmail,
		};

		if (cleanedDisplayName != null && cleanedDisplayName.isNotEmpty) {
			payload['display_name'] = cleanedDisplayName;
		}

		if (cleanedPhotoUrl != null && cleanedPhotoUrl.isNotEmpty) {
			payload['photo_url'] = cleanedPhotoUrl;
		}

		_logDebug('ATTEMPTING syncUser with data: ${jsonEncode(payload)}');

		try {
			final dynamic response = await client
					.from('profiles')
					.upsert(payload, onConflict: 'id')
					.select()
					.single();

			if (response == null) {
				throw Exception('Database accepted upsert but returned no data');
			}

			_logDebug('SUCCESS: Record created with ID: ${response['id']}');
			_logSuccess('SYNC_SUCCESS');
		} on PostgrestException catch (error) {
			_printPostgrestException('syncUser', error);
			_logError('SYNC_FAILED: ${error.code} - ${error.message}');
			rethrow;
		} catch (error) {
			_logError('SYNC_ERROR: $error');
			rethrow;
		}
	}

	/// Create organization with owner_id (profiles.id) reference
	/// Returns: {id: UUID, name: string, owner_id: TEXT}
	Future<Map<String, dynamic>> createOrganization(String name, String ownerUid) async {
		final cleanedName = _clean(name);
		final cleanedOwnerUid = _clean(ownerUid);

		if (cleanedName.isEmpty) {
			throw ArgumentError('name cannot be empty');
		}

		if (cleanedOwnerUid.isEmpty) {
			throw ArgumentError('ownerUid cannot be empty');
		}

		final payload = {
			'name': cleanedName,
			'owner_id': cleanedOwnerUid,
		};

		_logDebug('ATTEMPTING createOrganization with data: ${jsonEncode(payload)}');

		try {
			final dynamic response = await client
					.from('organizations')
					.insert(payload)
					.select('id, name, owner_id')
					.single();

			_logDebug('SUCCESS: Record created with ID: ${response['id']}');
			return Map<String, dynamic>.from(response);
		} on PostgrestException catch (error) {
			_printPostgrestException('createOrganization', error);
			rethrow;
		} catch (error) {
			_logError('createOrganization failed: $error');
			rethrow;
		}
	}

	/// Create program under organization
	/// Params: orgId (UUID), name, description
	/// Returns: {id: UUID, org_id: UUID, name: string, description: string}
	Future<Map<String, dynamic>> createProgram({
		required String orgId,
		required String name,
		String? description,
	}) async {
		final cleanedOrgId = _clean(orgId);
		final cleanedName = _clean(name);
		final cleanedDescription = description == null ? null : _clean(description);

		if (cleanedOrgId.isEmpty) {
			throw ArgumentError('orgId cannot be empty');
		}

		if (cleanedName.isEmpty) {
			throw ArgumentError('name cannot be empty');
		}

		final payload = <String, dynamic>{
			'org_id': cleanedOrgId,
			'name': cleanedName,
		};

		if (cleanedDescription != null && cleanedDescription.isNotEmpty) {
			payload['description'] = cleanedDescription;
		}

		_logDebug('ATTEMPTING createProgram with data: ${jsonEncode(payload)}');

		try {
			final dynamic response = await client
					.from('programs')
					.insert(payload)
					.select('id, org_id, name, description')
					.single();

			_logDebug('SUCCESS: Record created with ID: ${response['id']}');
			return Map<String, dynamic>.from(response);
		} on PostgrestException catch (error) {
			_printPostgrestException('createProgram', error);
			rethrow;
		} catch (error) {
			_logError('createProgram failed: $error');
			rethrow;
		}
	}

	/// Add student to organization AND link to program via activities
	/// Creates record in 'students' table AND activity entry for first class
	/// Params: orgId (UUID), name, phone, profession, programId (UUID)
	/// Returns: {student_id: UUID, activity_id: UUID}
	Future<Map<String, dynamic>> addStudentToProgram({
		required String orgId,
		required String name,
		required String phone,
		required String profession,
		required String programId,
	}) async {
		final cleanedOrgId = _clean(orgId);
		final cleanedName = _clean(name);
		final cleanedPhone = _clean(phone);
		final cleanedProfession = _clean(profession);
		final cleanedProgramId = _clean(programId);

		if (cleanedOrgId.isEmpty) throw ArgumentError('orgId cannot be empty');
		if (cleanedName.isEmpty) throw ArgumentError('name cannot be empty');
		if (cleanedPhone.isEmpty) throw ArgumentError('phone cannot be empty');
		if (cleanedProfession.isEmpty) throw ArgumentError('profession cannot be empty');
		if (cleanedProgramId.isEmpty) throw ArgumentError('programId cannot be empty');

		final studentPayload = <String, dynamic>{
			'org_id': cleanedOrgId,
			'full_name': cleanedName,
			'phone': cleanedPhone,
			'profession': cleanedProfession,
		};

		_logDebug('ATTEMPTING addStudentToProgram with student data: ${jsonEncode(studentPayload)}');

		try {
			// Step 1: Create student record
			final dynamic studentResponse = await client
					.from('students')
					.insert(studentPayload)
					.select('id, org_id, full_name, phone, profession')
					.single();

			if (studentResponse == null) {
				throw Exception('Student insert succeeded but returned no data');
			}

			final studentId = studentResponse['id'].toString();
			_logDebug('SUCCESS: Record created with ID: $studentId');

			// Step 2: Link student to program via activities (first class enrollment)
			final activityPayload = <String, dynamic>{
				'org_id': cleanedOrgId,
				'student_id': studentId,
				'activity_type': 'class_schedule',
				'status': 'enrolled',
				'event_date': DateTime.now().toUtc().toIso8601String(),
			};

			_logDebug('ATTEMPTING addStudentToProgram: linking activity with data: ${jsonEncode(activityPayload)}');

			final dynamic activityResponse = await client
					.from('activities')
					.insert(activityPayload)
					.select('id, org_id, student_id, activity_type, status')
					.single();

			if (activityResponse == null) {
				throw Exception('Activity insert succeeded but returned no data');
			}

			final activityId = activityResponse['id'].toString();
			_logDebug('SUCCESS: Record created with ID: $activityId');

			return {
				'student_id': studentId,
				'activity_id': activityId,
				'student_data': Map<String, dynamic>.from(studentResponse),
				'activity_data': Map<String, dynamic>.from(activityResponse),
			};
		} on PostgrestException catch (error) {
			_printPostgrestException('addStudentToProgram', error);
			rethrow;
		} catch (error) {
			_logError('addStudentToProgram failed: $error');
			rethrow;
		}
	}

	Future<List<Map<String, dynamic>>> fetchStudents(String orgId) async {
		final cleanedOrgId = _clean(orgId);

		if (cleanedOrgId.isEmpty) {
			return <Map<String, dynamic>>[];
		}

		_logDebug('ATTEMPTING fetchStudents with data: {orgId: $cleanedOrgId}');

		try {
			final dynamic response = await client
					.from('students')
					.select('id, org_id, full_name, phone, profession')
					.eq('org_id', cleanedOrgId)
					.order('full_name');

			_logDebug('SUCCESS: Fetched ${(response as List).length} records');
			return List<Map<String, dynamic>>.from(response);
		} on PostgrestException catch (error) {
			_printPostgrestException('fetchStudents', error);
			rethrow;
		} catch (error) {
			_logError('fetchStudents failed: $error');
			rethrow;
		}
	}

	/// Record activity for student: class_schedule or payment_due
	/// One modular function for all activity types
	/// Params: orgId (UUID), studentId (UUID), activityType ('class_schedule' or 'payment_due')
	/// Optional: amountDue, eventDate, status
	/// Returns: {id: UUID, org_id: UUID, student_id: UUID, activity_type: string, ...}
	Future<Map<String, dynamic>> recordActivity({
		required String orgId,
		required String studentId,
		required String activityType,
		double? amountDue,
		DateTime? eventDate,
		String? status,
	}) async {
		final cleanedOrgId = _clean(orgId);
		final cleanedStudentId = _clean(studentId);
		final cleanedActivityType = _clean(activityType);
		final cleanedStatus = status == null ? null : _clean(status);

		if (cleanedOrgId.isEmpty) throw ArgumentError('orgId cannot be empty');
		if (cleanedStudentId.isEmpty) throw ArgumentError('studentId cannot be empty');
		if (cleanedActivityType.isEmpty) throw ArgumentError('activityType cannot be empty');

		// Validate activity type
		const validTypes = ['class_schedule', 'payment_due'];
		if (!validTypes.contains(cleanedActivityType)) {
			throw ArgumentError('activityType must be one of: $validTypes');
		}

		final payload = <String, dynamic>{
			'org_id': cleanedOrgId,
			'student_id': cleanedStudentId,
			'activity_type': cleanedActivityType,
		};

		if (amountDue != null) {
			payload['amount_due'] = amountDue;
		}

		if (eventDate != null) {
			payload['event_date'] = eventDate.toUtc().toIso8601String();
		}

		if (cleanedStatus != null && cleanedStatus.isNotEmpty) {
			payload['status'] = cleanedStatus;
		}

		_logDebug('ATTEMPTING recordActivity with data: ${jsonEncode(payload)}');

		try {
			final dynamic response = await client
					.from('activities')
					.insert(payload)
					.select('id, org_id, student_id, activity_type, amount_due, event_date, status')
					.single();

			if (response == null) {
				throw Exception('Activity insert succeeded but returned no data');
			}

			_logDebug('SUCCESS: Record created with ID: ${response['id']}');
			return Map<String, dynamic>.from(response);
		} on PostgrestException catch (error) {
			_printPostgrestException('recordActivity', error);
			rethrow;
		} catch (error) {
			_logError('recordActivity failed: $error');
			rethrow;
		}
	}

	Future<List<Map<String, dynamic>>> getStudentLedger(String studentId) async {
		final cleanedStudentId = _clean(studentId);

		if (cleanedStudentId.isEmpty) {
			return <Map<String, dynamic>>[];
		}

		_logDebug('ATTEMPTING getStudentLedger with data: {studentId: $cleanedStudentId}');

		try {
			final dynamic response = await client
					.from('activities')
					.select('id, org_id, student_id, activity_type, amount_due, event_date, status')
					.eq('student_id', cleanedStudentId)
					.order('event_date', ascending: false);

			_logDebug('SUCCESS: Fetched ${(response as List).length} records');
			return List<Map<String, dynamic>>.from(response);
		} on PostgrestException catch (error) {
			_printPostgrestException('getStudentLedger', error);
			rethrow;
		} catch (error) {
			_logError('getStudentLedger failed: $error');
			rethrow;
		}
	}

	/// Sync Firebase Auth user to Supabase profiles
	/// Wrapper for syncUser that handles Firebase user context
	Future<void> syncFirebaseUserWithSupabase({
		required String uid,
		String? email,
		String? displayName,
		String? photoUrl,
	}) async {
		_logDebug('ATTEMPTING syncFirebaseUserWithSupabase with data: {uid: $uid, email: $email}');
		try {
			await syncUser(
				uid,
				email ?? '',
				displayName: displayName,
				photoUrl: photoUrl,
			);
			_logDebug('SUCCESS: Firebase user synced to Supabase');
		} on PostgrestException catch (error) {
			_printPostgrestException('syncFirebaseUserWithSupabase', error);
			_logError('SYNC_FIREBASE_FAILED: ${error.code}');
		} catch (error) {
			_logError('syncFirebaseUserWithSupabase error: $error');
		}
	}

	/// Fetch organizations for current Firebase user (owner)
	/// Uses Firebase Auth context
	/// Returns: List of {id, name, owner_id}
	Future<List<Map<String, dynamic>>> fetchOrganizations() async {
		try {
			final currentUser = FirebaseAuth.instance.currentUser;
			final ownerId = currentUser?.uid.trim();
			if (ownerId == null || ownerId.isEmpty) {
				return <Map<String, dynamic>>[];
			}

			_logDebug('ATTEMPTING fetchOrganizations with data: {ownerId: $ownerId}');

			final dynamic response = await client
					.from('organizations')
					.select('id, name, owner_id')
					.eq('owner_id', ownerId);

			_logDebug('SUCCESS: Fetched ${(response as List).length} organizations');
			return List<Map<String, dynamic>>.from(response);
		} on PostgrestException catch (error) {
			_printPostgrestException('fetchOrganizations', error);
			rethrow;
		} catch (error) {
			_logError('fetchOrganizations failed: $error');
			rethrow;
		}
	}

	/// Alias for fetchStudents (for backward compatibility)
	Future<List<Map<String, dynamic>>> getStudents(String orgId) async {
		return await fetchStudents(orgId);
	}

	/// Add student to organization
	/// Note: Prefer addStudentToProgram for linking to programs
	/// Params: orgId (UUID), name, phone, profession
	/// Returns: {id, org_id, full_name, phone, profession}
	Future<Map<String, dynamic>> addStudent(
		String orgId,
		String name,
		String phone,
		String profession,
	) async {
		final payload = {
			'org_id': orgId,
			'full_name': name,
			'phone': phone,
			'profession': profession,
		};

		_logDebug('ATTEMPTING addStudent with data: ${jsonEncode(payload)}');

		try {
			final dynamic response = await client
					.from('students')
					.insert(payload)
					.select('id, org_id, full_name, phone, profession')
					.single();

			if (response == null) {
				throw Exception('Student insert succeeded but returned no data');
			}

			_logDebug('SUCCESS: Record created with ID: ${response['id']}');
			return Map<String, dynamic>.from(response);
		} on PostgrestException catch (error) {
			_printPostgrestException('addStudent', error);
			rethrow;
		} catch (error) {
			_logError('addStudent failed: $error');
			rethrow;
		}
	}
}
