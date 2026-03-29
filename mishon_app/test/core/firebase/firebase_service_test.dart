import 'package:flutter_test/flutter_test.dart';
import 'package:mishon_app/core/firebase/firebase_service.dart';

void main() {
  test('mapPushDataToIntent routes chat notifications', () {
    final intent = mapPushDataToIntent(<String, Object?>{
      'conversationId': 15,
      'actorUserId': 8,
      'actorUsername': 'michael',
    });

    expect(intent?.location, '/chat/15?peerId=8&username=michael'); 
  });

  test('mapPushDataToIntent routes comment notifications', () {
    final intent = mapPushDataToIntent(<String, Object?>{
      'type': 'post_comment',
      'postId': 55,
      'postUserId': 6,
    });

    expect(intent?.location, '/comments/55?postUserId=6');
  });

  test('mapPushDataToIntent routes follow requests to dedicated screen', () {
    final intent = mapPushDataToIntent(<String, Object?>{
      'type': 'follow_request',
      'relatedUserId': 9,
    });

    expect(intent?.location, '/follow-requests');
  });

  test('mapPushDataToIntent routes moderation and security notifications', () {
    final intent = mapPushDataToIntent(<String, Object?>{
      'type': 'security_session_revoked',
    });

    expect(intent?.location, '/moderation');
  });
}
