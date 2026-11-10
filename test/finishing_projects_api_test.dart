import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:expense_tracker_flutter/core/sync/sync_api.dart';

void main() {
  SyncApi makeApi(Future<http.Response> Function(http.Request) handler) {
    return SyncApi('https://example.test', client: MockClient((request) async {
      if (request.url.path == '/api/auth/login') {
        return http.Response(jsonEncode({
          'user': {'id': 'u1', 'email': 'user@example.test', 'name': 'Test'},
          'accessToken': 'access', 'refreshToken': 'refresh',
        }), 200);
      }
      expect(request.headers['authorization'], 'Bearer access');
      return handler(request);
    }));
  }

  test('list finishing projects uses authenticated GET', () async {
    final api = makeApi((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/finishing/projects');
      return http.Response(jsonEncode({'projects': [
        {'project_id': 'p1', 'project_name': 'Apartment', 'custody_piasters': '0'},
      ]}), 200);
    });
    addTearDown(api.close);
    await api.login('user@example.test', 'password123');
    final projects = await api.listFinishingProjects();
    expect(projects.single['project_id'], 'p1');
  });

  test('create finishing project sends stable ID and trimmed names', () async {
    final api = makeApi((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/finishing/projects');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['projectId'], 'project-123');
      expect(body['clientName'], 'Client');
      expect(body['projectName'], 'Apartment');
      return http.Response('{"status":"created"}', 201);
    });
    addTearDown(api.close);
    await api.login('user@example.test', 'password123');
    final result = await api.createFinishingProject(
      projectId: 'project-123', clientName: ' Client ', projectName: 'Apartment');
    expect(result['status'], 'created');
  });

  test('project detail returns null for 404', () async {
    final api = makeApi((request) async {
      expect(request.url.path, '/api/finishing/projects/missing');
      return http.Response('{"error":"not_found"}', 404);
    });
    addTearDown(api.close);
    await api.login('user@example.test', 'password123');
    expect(await api.getFinishingProject('missing'), isNull);
  });

  test('invalid project ID is rejected without network call', () async {
    final api = makeApi((_) async => throw StateError('unexpected request'));
    addTearDown(api.close);
    expect(
      () => api.createFinishingProject(
        projectId: '../unsafe', clientName: 'Client', projectName: 'Apartment'),
      throwsArgumentError,
    );
  });
}
