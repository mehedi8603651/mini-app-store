import 'package:mini_program_ui/mini_program_ui.dart';

import '../friends_actions.dart';
import '../friends_theme.dart';

MpNode buildFriendsList() => Mp.container(
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
                title: 'MY FRIENDS',
                subtitle: 'ACCEPTED CONNECTIONS',
                backAction: goBack(),
              ),
              Mp.sizedBox(height: 20),
              Mp.backendBuilder(
                requestId: friendsListRequest,
                endpoint: 'friends',
                loading: friendsLoading('Loading friends'),
                error: friendsError(
                  'Friends unavailable',
                  '{{backend.friends_list.message}}',
                ),
                empty: _emptyFriends(),
                child: Mp.repeat(
                  source: '{{backend.friends_list.data.items}}',
                  spacing: 9,
                  limit: 100,
                  empty: _emptyFriends(),
                  itemTemplate: _friendCard(),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

MpNode _friendCard() => Mp.container(
  paddingHorizontal: 15,
  paddingVertical: 15,
  backgroundColor: friendsSurface,
  borderColor: friendsBorder,
  borderWidth: 1,
  borderRadius: 8,
  child: Mp.row(
    children: <MpNode>[
      Mp.container(
        width: 46,
        height: 46,
        backgroundColor: friendsSurfaceStrong,
        borderRadius: 23,
        child: Mp.center(
          child: Mp.icon(
            'person',
            semanticLabel: 'Friend',
            size: 25,
            color: friendsMint,
          ),
        ),
      ),
      Mp.sizedBox(width: 12),
      Mp.expanded(
        child: Mp.column(
          children: <MpNode>[
            Mp.text(
              '{{item.email}}',
              color: friendsText,
              size: 15,
              weight: 'semibold',
              maxLines: 1,
              overflow: 'ellipsis',
            ),
            Mp.sizedBox(height: 3),
            Mp.text(
              'Friends since {{item.friendsSinceUtc}}',
              color: friendsMuted,
              size: 10,
            ),
          ],
        ),
      ),
      Mp.iconButton(
        'delete',
        semanticLabel: 'Remove {{item.email}}',
        action: removeFriend(),
        size: 42,
        iconSize: 20,
        color: friendsDanger,
        backgroundColor: friendsSurface,
        borderRadius: 21,
      ),
    ],
  ),
);

MpNode _emptyFriends() => friendsError(
  'No friends yet',
  'Create a QR invitation or scan one, then accept the pending request.',
);
