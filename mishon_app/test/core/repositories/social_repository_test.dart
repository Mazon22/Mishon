import 'package:flutter_test/flutter_test.dart';
import 'package:mishon_app/core/models/social_models.dart';
import 'package:mishon_app/core/repositories/social_repository.dart';

import '../../support/test_doubles.dart';

void main() {
  setUp(() {
    SocialRepository.resetCachesForTest();
  });

  test('createReport forwards payload to api layer', () async {
    final api = FakeApiService()
      ..reportResponse = ReportDetailModel(
        id: 11,
        source: 'User',
        targetType: 'Post',
        targetId: 91,
        targetUserId: 7,
        reason: 'Spam',
        customNote: 'Looks abusive',
        status: 'Open',
        reporterUserId: 5,
        reporterUsername: 'michael',
        assignedModeratorUserId: null,
        assignedModeratorUsername: null,
        resolution: 'None',
        resolutionNote: null,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        resolvedAt: null,
      );
    final repository = SocialRepository(apiService: api);

    final report = await repository.createReport(
      targetType: 'Post',
      targetId: 91,
      reason: 'Spam',
      customNote: 'Looks abusive',
    );

    expect(report.id, 11);
    expect(api.lastReportRequest, <String, Object?>{
      'targetType': 'Post',
      'targetId': 91,
      'reason': 'Spam',
      'customNote': 'Looks abusive',
    });
  });
}
