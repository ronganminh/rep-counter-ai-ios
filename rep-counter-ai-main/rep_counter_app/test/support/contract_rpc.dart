import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rep_counter_app/core/backend/backend_rpc.dart';

/// Reads `supabase/contracts/<name>.json` (repo root). The database tests
/// (`supabase/tests/*.test.sql`) check the same file against the SQL
/// functions, so a rename on either side fails one of the two suites.
Map<String, Object?> loadContract(String name) {
  final file = File('../../supabase/contracts/$name.json');
  return (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();
}

/// A [BackendRpc] fake that checks every call against a contract before
/// passing it to [handler]: the function must be listed, and the params it
/// gets must be exactly the contract's parameter names. JSON is round-tripped
/// so only what survives `jsonEncode` reaches the handler, like on the wire.
class ContractRpc implements BackendRpc {
  ContractRpc(this.contract, this.handler, {this.invokeHandler});

  final Map<String, Object?> contract;
  final Object? Function(String function, Map<String, Object?> params) handler;
  final Object? Function(String function, Map<String, Object?> body)?
      invokeHandler;
  final List<String> calls = [];

  Map<String, Object?> get _functions =>
      (contract['functions'] as Map).cast<String, Object?>();

  @override
  Future<Object?> rpc(String function, Map<String, Object?> params) async {
    calls.add(function);
    final spec = _functions[function];
    expect(spec, isNotNull, reason: '$function is not in the contract');
    final names = ((spec! as Map)['params'] as List).cast<String>();
    expect(params.keys.toSet(), names.toSet(),
        reason: 'params of $function must match the contract');
    final wire =
        (jsonDecode(jsonEncode(params)) as Map).cast<String, Object?>();
    return jsonDecode(jsonEncode(handler(function, wire)));
  }

  @override
  Future<Object?> invoke(String function, Map<String, Object?> body) async {
    calls.add(function);
    final edge = (contract['edge_functions'] as Map?)?.cast<String, Object?>();
    expect(edge?[function], isNotNull,
        reason: '$function is not an Edge Function in the contract');
    final request =
        ((edge![function] as Map)['request'] as List?)?.cast<String>();
    if (request != null) {
      expect(body.keys.toSet(), request.toSet(),
          reason: 'body of $function must match the contract');
    }
    final wire = (jsonDecode(jsonEncode(body)) as Map).cast<String, Object?>();
    return jsonDecode(jsonEncode(invokeHandler!(function, wire)));
  }

  /// Rows written with [upsert], by table.
  final upserts = <String, List<Map<String, Object?>>>{};

  @override
  Future<void> upsert(String table, Map<String, Object?> row) async {
    calls.add('upsert $table');
    (upserts[table] ??= []).add(row);
  }
}

/// Fails a call the way the backend does.
class FailingRpc implements BackendRpc {
  FailingRpc(this.error);
  final BackendException error;

  @override
  Future<Object?> rpc(String function, Map<String, Object?> params) =>
      Future.error(error);

  @override
  Future<Object?> invoke(String function, Map<String, Object?> body) =>
      Future.error(error);

  @override
  Future<void> upsert(String table, Map<String, Object?> row) =>
      Future.error(error);
}

/// The keys of a contract list such as `workout_row`.
Set<String> contractKeys(Map<String, Object?> contract, String name) =>
    (contract[name] as List).cast<String>().toSet();
