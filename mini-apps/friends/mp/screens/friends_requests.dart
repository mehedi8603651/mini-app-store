import 'package:mini_program_ui/mini_program_ui.dart';

import '../friends_actions.dart';
import '../friends_theme.dart';

MpNode buildFriendsRequests() => Mp.container(
  backgroundColor: friendsBackground,
  child: Mp.safeArea(
    child: Mp.scrollView(
      paddingHorizontal: 16,
      paddingTop: 18,
      paddingBottom: 30,
      child: Mp.center(
        child: Mp.container(
          width: 600,
          child: Mp.column(
            children: <MpNode>[
              friendsHeader(
                title: 'REQUESTS',
                subtitle: 'YOU DECIDE WHO TO ACCEPT',
                backAction: goBack(),
              ),
              Mp.sizedBox(height: 20),
              Mp.backendBuilder(
                requestId: friendsRequestsRequest,
                endpoint: 'friend-requests',
                loading: friendsLoading('Loading requests'),
                error: friendsError(
                  'Requests unavailable',
                  '{{backend.friends_requests.message}}',
                ),
                empty: _emptyRequests(),
                child: Mp.repeat(
                  source: '{{backend.friends_requests.data.items}}',
                  spacing: 9,
                  limit: 50,
                  empty: _emptyRequests(),
                  itemTemplate: _requestCard(),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

MpNode _requestCard() => Mp.container(
  paddingHorizontal: 15,
  paddingVertical: 16,
  backgroundColor: friendsSurface,
  borderColor: friendsBorder,
  borderWidth: 1,
  borderRadius: 8,
  child: Mp.column(
    children: <MpNode>[
      Mp.row(
        children: <MpNode>[
          Mp.icon(
            'person',
            semanticLabel: 'Friend request',
            size: 29,
            color: friendsYellow,
          ),
          Mp.sizedBox(width: 12),
          Mp.expanded(
            child: Mp.column(
              children: <MpNode>[
                Mp.text(
                  '{{item.fromEmail}}',
                  color: friendsText,
                  size: 15,
                  weight: 'semibold',
                  maxLines: 1,
                  overflow: 'ellipsis',
                ),
                Mp.sizedBox(height: 3),
                Mp.text(
                  'Sent {{item.createdAtUtc}}',
                  color: friendsMuted,
                  size: 10,
                ),
              ],
            ),
          ),
        ],
      ),
      Mp.sizedBox(height: 14),
      Mp.row(
        children: <MpNode>[
          Mp.expanded(
            child: Mp.button(
              label: 'DECLINE',
              action: declineFriendRequest(),
              height: 42,
              backgroundColor: friendsSurfaceStrong,
              foregroundColor: friendsDanger,
              borderColor: friendsBorder,
              borderWidth: 1,
              borderRadius: 6,
              fontSize: 12,
            ),
          ),
          Mp.sizedBox(width: 8),
          Mp.expanded(
            child: Mp.button(
              label: 'ACCEPT',
              action: acceptFriendRequest(),
              height: 42,
              backgroundColor: friendsMint,
              foregroundColor: friendsBackground,
              borderColor: friendsMint,
              borderRadius: 6,
              fontSize: 12,
              fontWeight: 'semibold',
            ),
          ),
        ],
      ),
    ],
  ),
);

MpNode _emptyRequests() => friendsError(
  'No pending requests',
  'Share your QR or wait for someone to scan an invitation.',
);
