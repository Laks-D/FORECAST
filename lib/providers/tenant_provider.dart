import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_service.dart';

final selectedOrgProvider = StateProvider<String?>((ref) => null);

final organizationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
	return SupabaseService.instance.fetchOrganizations();
});

final studentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
	final orgId = ref.watch(selectedOrgProvider);
	if (orgId == null) {
		return <Map<String, dynamic>>[];
	}

	return SupabaseService.instance.getStudents(orgId);
});
