import 'package:mini_program_ui/mini_program_ui.dart';

const friendsRequestsRequest = 'friends_requests';
const friendsListRequest = 'friends_list';

List<MpAction> initializeFriends() => <MpAction>[
  Mp.auth.restore(),
  Mp.state.setDefault('friends.scan_status', 'idle'),
];

MpAction openInvite() =>
    Mp.router.push('friends_invite', requestId: 'friends-open-invite');

MpAction openScanner() =>
    Mp.router.push('friends_scan', requestId: 'friends-open-scanner');

MpAction openRequests() =>
    Mp.router.push('friends_requests', requestId: 'friends-open-requests');

MpAction openFriendsList() =>
    Mp.router.push('friends_list', requestId: 'friends-open-list');

MpAction goBack() => Mp.router.pop(requestId: 'friends-back');

MpAction signOutFriends() => Mp.action.sequence(<MpAction>[
  Mp.auth.signOut(),
  Mp.router.reset('friends_home', requestId: 'friends-signed-out'),
]);

MpAction regenerateInvite() => Mp.backend.query(
  requestId: 'friend_invite',
  endpoint: 'friend-invites',
  method: 'POST',
  forceRefresh: true,
);

MpAction scanFriendInvite() => Mp.action.sequence(<MpAction>[
  Mp.qr.scan(
    allowTorch: true,
    timeout: const Duration(seconds: 60),
    targetState: 'friends.scanned_invite',
    statusState: 'friends.scan_status',
    errorState: 'friends.scan_error',
    requestId: 'friends-scan-invite',
  ),
  Mp.backend.call(
    endpoint: 'friend-invites/redeem',
    method: 'POST',
    body: const <String, Object?>{
      'payload': '{{state.friends.scanned_invite.rawValue}}',
    },
    requestId: 'friends-redeem-invite',
  ),
  Mp.toast(message: 'Friend request sent'),
  Mp.router.pop(requestId: 'friends-scan-complete'),
]);

MpAction refreshRequests() => Mp.backend.query(
  requestId: friendsRequestsRequest,
  endpoint: 'friend-requests',
  forceRefresh: true,
);

MpAction acceptFriendRequest() => Mp.action.sequence(<MpAction>[
  Mp.backend.call(
    endpoint: 'friend-requests/accept',
    method: 'POST',
    body: const <String, Object?>{'requestId': '{{item.requestId}}'},
    requestId: 'friends-accept-request',
  ),
  refreshRequests(),
  Mp.toast(message: 'Friend request accepted'),
]);

MpAction declineFriendRequest() => Mp.action.sequence(<MpAction>[
  Mp.backend.call(
    endpoint: 'friend-requests/decline',
    method: 'POST',
    body: const <String, Object?>{'requestId': '{{item.requestId}}'},
    requestId: 'friends-decline-request',
  ),
  refreshRequests(),
  Mp.toast(message: 'Friend request declined'),
]);

MpAction refreshFriendsList() => Mp.backend.query(
  requestId: friendsListRequest,
  endpoint: 'friends',
  forceRefresh: true,
);

MpAction removeFriend() => Mp.action.sequence(<MpAction>[
  Mp.backend.call(
    endpoint: 'friends/remove',
    method: 'POST',
    body: const <String, Object?>{'friendUserId': '{{item.userId}}'},
    requestId: 'friends-remove',
  ),
  refreshFriendsList(),
  Mp.toast(message: 'Friend removed'),
]);
