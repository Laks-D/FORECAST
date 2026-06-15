import re

with open('lib/features/client/presentation/bloc/client_bloc.dart', 'r') as f:
    content = f.read()

# Add alias import
content = content.replace("import '../../domain/entities/client_event.dart';", "import '../../domain/entities/client_event.dart' as domain;")

# Note addition
old_note = """    await clientEventRepository.add(ClientEvent(
      eventId: _uuid.v4(),
      clientId: event.entityId,
      tutorId: FirebaseAuth.instance.currentUser?.uid ?? '',
      firebaseUid: client.firebaseUid,
      type: ClientEventType.note,
      note: event.note,
      createdAt: event.createdAt ?? DateTime.now(),
    ));"""

new_note = """    await clientEventRepository.add(domain.ClientEvent(
      eventId: _uuid.v4(),
      clientId: event.entityId,
      tutorId: FirebaseAuth.instance.currentUser?.uid ?? '',
      firebaseUid: client.firebaseUid,
      type: domain.ClientEventType.note,
      note: event.note,
      createdAt: event.createdAt ?? DateTime.now(),
    ));"""

content = content.replace(old_note, new_note)

# Status change
old_status = """    await clientEventRepository.add(ClientEvent(
      eventId: _uuid.v4(),
      clientId: event.entityId,
      tutorId: FirebaseAuth.instance.currentUser?.uid ?? '',
      firebaseUid: client.firebaseUid,
      type: ClientEventType.statusChanged,
      status: event.status,
      createdAt: event.createdAt ?? DateTime.now(),
    ));"""

new_status = """    await clientEventRepository.add(domain.ClientEvent(
      eventId: _uuid.v4(),
      clientId: event.entityId,
      tutorId: FirebaseAuth.instance.currentUser?.uid ?? '',
      firebaseUid: client.firebaseUid,
      type: domain.ClientEventType.statusChanged,
      status: event.status,
      createdAt: event.createdAt ?? DateTime.now(),
    ));"""

content = content.replace(old_status, new_status)

# Profile created
old_created = """    await clientEventRepository.add(ClientEvent(
      eventId: _uuid.v4(),
      clientId: clientId,
      tutorId: FirebaseAuth.instance.currentUser?.uid ?? '',
      firebaseUid: event.firebaseUid,
      type: ClientEventType.profileCreated,
      createdAt: DateTime.now(),
    ));"""

new_created = """    await clientEventRepository.add(domain.ClientEvent(
      eventId: _uuid.v4(),
      clientId: clientId,
      tutorId: FirebaseAuth.instance.currentUser?.uid ?? '',
      firebaseUid: event.firebaseUid,
      type: domain.ClientEventType.profileCreated,
      createdAt: DateTime.now(),
    ));"""

content = content.replace(old_created, new_created)

# Profile created note
old_created_note = """      await clientEventRepository.add(ClientEvent(
        eventId: _uuid.v4(),
        clientId: clientId,
        tutorId: FirebaseAuth.instance.currentUser?.uid ?? '',
        firebaseUid: event.firebaseUid,
        type: ClientEventType.note,
        note: 'Referred by: ${event.referredBy}',
        createdAt: DateTime.now(),
      ));"""

new_created_note = """      await clientEventRepository.add(domain.ClientEvent(
        eventId: _uuid.v4(),
        clientId: clientId,
        tutorId: FirebaseAuth.instance.currentUser?.uid ?? '',
        firebaseUid: event.firebaseUid,
        type: domain.ClientEventType.note,
        note: 'Referred by: ${event.referredBy}',
        createdAt: DateTime.now(),
      ));"""

content = content.replace(old_created_note, new_created_note)

with open('lib/features/client/presentation/bloc/client_bloc.dart', 'w') as f:
    f.write(content)
