import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rep_counter_app/core/backend/backend_rpc.dart';
import 'package:rep_counter_app/features/sync/supabase_cloud_sync_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// The real Supabase SDK against a fake HTTP server: every way staging can
/// fail (401, 404, 5xx, HTML instead of JSON, no network) must reach the
/// features as a [BackendException] they can turn into "sync pending",
/// never as an SDK or socket error that crashes a caller.
void main() {
  late sb.SupabaseClient client;
  late SupabaseBackendRpc rpc;
  late Future<http.Response> Function(http.Request) server;

  setUp(() {
    server = (_) async => http.Response('null', 200);
    client = sb.SupabaseClient(
      'https://staging.example.test',
      'anon-key',
      authOptions: const sb.AuthClientOptions(autoRefreshToken: false),
      postgrestOptions: const sb.PostgrestClientOptions(retryEnabled: false),
      // PostgREST reads the request back from the response, as on the wire.
      httpClient: MockClient((r) async {
        final res = await server(r);
        return http.Response.bytes(res.bodyBytes, res.statusCode,
            headers: res.headers, request: r);
      }),
    );
    rpc = SupabaseBackendRpc(client);
  });

  tearDown(() => client.dispose());

  http.Response jsonResponse(int status, Object body) =>
      http.Response(jsonEncode(body), status,
          headers: {'content-type': 'application/json'});

  Future<BackendException> rpcError() async {
    try {
      await rpc.rpc('sync_pull_workouts', {'p_after': 0, 'p_limit': 10});
    } on BackendException catch (e) {
      return e;
    }
    fail('expected a BackendException');
  }

  Future<BackendException> invokeError() async {
    try {
      await rpc.invoke('ai-request', {'request_id': 'r1'});
    } on BackendException catch (e) {
      return e;
    }
    fail('expected a BackendException');
  }

  group('SQL functions (PostgREST)', () {
    test('expired JWT (401 PGRST303) reads as signed out', () async {
      server = (_) async => jsonResponse(
          401, {'code': 'PGRST303', 'message': 'JWT expired', 'details': null});
      final e = await rpcError();
      expect(e.code, 'PGRST303');
      expect(e.notSignedIn, isTrue);
    });

    test('not signed in inside the function (28000)', () async {
      server = (_) async =>
          jsonResponse(400, {'code': '28000', 'message': 'not_authenticated'});
      expect((await rpcError()).notSignedIn, isTrue);
    });

    test('missing function (404 PGRST202) is a server error', () async {
      server = (_) async => jsonResponse(404, {
            'code': 'PGRST202',
            'message': 'Could not find the function',
          });
      final e = await rpcError();
      expect(e.code, 'PGRST202');
      expect(e.notSignedIn, isFalse);
      expect(e.offline, isFalse);
    });

    test('5xx with an HTML page keeps the status as code', () async {
      server = (_) async => http.Response('<html>Bad gateway</html>', 502);
      final e = await rpcError();
      expect(e.code, '502');
      expect(e.notSignedIn, isFalse);
    });

    test('no network', () async {
      server = (_) async =>
          throw const SocketException('Failed host lookup: staging');
      expect((await rpcError()).offline, isTrue);
      server = (_) async => throw http.ClientException('Connection reset');
      expect((await rpcError()).offline, isTrue);
    });

    test('a 200 that is not the contract fails as invalid_response', () async {
      server = (_) async => jsonResponse(200, {'rows': 'oops'});
      await expectLater(
          SupabaseCloudSyncApi(rpc).pull(after: 0),
          throwsA(isA<BackendException>()
              .having((e) => e.code, 'code', 'invalid_response')));
      server = (_) async => jsonResponse(200, {
            'rows': [
              {'client_id': 7, 'raw': {}, 'server_seq': 'x'}
            ],
            'cursor': 1,
            'has_more': false,
          });
      await expectLater(
          SupabaseCloudSyncApi(rpc).pull(after: 0),
          throwsA(isA<BackendException>()
              .having((e) => e.code, 'code', 'invalid_response')));
    });
  });

  group('Edge Functions', () {
    test('gateway 401 for a bad JWT (no "error" field)', () async {
      // What staging answered on 2026-10-31 for a call without a valid JWT.
      server = (_) async => jsonResponse(401, {
            'code': 'UNAUTHORIZED_INVALID_JWT_FORMAT',
            'message': 'Invalid JWT',
          });
      final e = await invokeError();
      expect(e.status, 401);
      expect(e.code, 'http_401');
      expect(e.notSignedIn, isTrue);
    });

    test("the function's own error body", () async {
      server = (_) async =>
          jsonResponse(402, {'error': 'insufficient_credits', 'balance': 0});
      final e = await invokeError();
      expect(e.code, 'insufficient_credits');
      expect(e.body?['balance'], 0);
    });

    test('404 and 5xx', () async {
      server = (_) async => http.Response('Function not found', 404);
      expect((await invokeError()).code, 'http_404');
      server = (_) async => http.Response('upstream error', 503);
      final e = await invokeError();
      expect(e.status, 503);
      expect(e.notSignedIn, isFalse);
      expect(e.offline, isFalse);
    });

    test('no network', () async {
      server = (_) async => throw const SocketException('Network is down');
      expect((await invokeError()).offline, isTrue);
    });
  });
}
