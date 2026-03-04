import 'package:equatable/equatable.dart';

import '../../domain/entities/client.dart';

abstract class ClientState extends Equatable {
  const ClientState();

  @override
  List<Object?> get props => [];
}

class ClientInitial extends ClientState {}

class ClientLoading extends ClientState {}

class ClientLoaded extends ClientState {
  final List<Client> entities;

  /// Monotonic nonce so every emission is treated as a new state.
  /// Needed because the in-memory datasource returns the same mutable list /
  /// objects, making Equatable's deep-equality always return true.
  final int _nonce;
  static int _nonceSeq = 0;

  ClientLoaded(this.entities) : _nonce = ++_nonceSeq;

  @override
  List<Object?> get props => [_nonce, entities];
}

class ClientError extends ClientState {
  final String message;

  const ClientError(this.message);

  @override
  List<Object?> get props => [message];
}