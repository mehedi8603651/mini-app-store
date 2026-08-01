import 'package:mini_program_ui/mini_program_ui.dart';

import '../friends_actions.dart';
import '../friends_theme.dart';

MpNode buildFriendsHome() => Mp.initialize(
  actions: initializeFriends(),
  loading: friendsLoading('Opening Friends'),
  error: friendsError(
    'Friends could not start',
    '{{state.friends.startup_error.message}}',
  ),
  statusState: 'friends.startup_status',
  errorState: 'friends.startup_error',
  child: Mp.container(
    backgroundColor: friendsBackground,
    child: Mp.safeArea(
      child: Mp.authBuilder(
        loading: friendsLoading('Restoring secure session'),
        signedOut: _signedOut(),
        error: _signedOut(error: true),
        signedIn: _signedIn(),
      ),
    ),
  ),
);

MpNode _signedOut({bool error = false}) => Mp.scrollView(
  paddingHorizontal: 20,
  paddingTop: 28,
  paddingBottom: 28,
  child: Mp.center(
    child: Mp.container(
      width: 520,
      child: Mp.column(
        children: <MpNode>[
          friendsHeader(title: 'FRIENDS', subtitle: 'QR INVITATIONS'),
          Mp.sizedBox(height: 54),
          Mp.container(
            paddingHorizontal: 28,
            paddingVertical: 38,
            backgroundColor: friendsSurface,
            borderColor: friendsBorder,
            borderWidth: 1,
            borderRadius: 8,
            child: Mp.column(
              children: <MpNode>[
                Mp.icon(
                  'person',
                  semanticLabel: 'Friends account',
                  size: 54,
                  color: friendsMint,
                ),
                Mp.sizedBox(height: 18),
                Mp.text(
                  'Connect by QR',
                  color: friendsText,
                  size: 26,
                  weight: 'bold',
                  align: 'center',
                ),
                Mp.sizedBox(height: 10),
                Mp.text(
                  error
                      ? '{{auth.message}}'
                      : 'Sign in, scan a short-lived invite, then wait for the other person to accept.',
                  color: error ? friendsDanger : friendsMuted,
                  size: 14,
                  align: 'center',
                  maxLines: 5,
                ),
                Mp.sizedBox(height: 28),
                Mp.button(
                  label: 'SIGN IN',
                  action: Mp.auth.showEmailAuth(mode: 'signIn'),
                  height: 50,
                  backgroundColor: friendsBlue,
                  foregroundColor: friendsBackground,
                  borderColor: friendsBlue,
                  borderRadius: 6,
                  fontSize: 15,
                  fontWeight: 'semibold',
                ),
                Mp.sizedBox(height: 10),
                Mp.button(
                  label: 'CREATE TEST ACCOUNT',
                  action: Mp.auth.showEmailAuth(mode: 'signUp'),
                  height: 48,
                  backgroundColor: friendsSurfaceStrong,
                  foregroundColor: friendsText,
                  borderColor: friendsBorder,
                  borderWidth: 1,
                  borderRadius: 6,
                  fontSize: 13,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);

MpNode _signedIn() => Mp.scrollView(
  paddingHorizontal: 16,
  paddingTop: 18,
  paddingBottom: 30,
  child: Mp.center(
    child: Mp.container(
      width: 600,
      child: Mp.column(
        children: <MpNode>[
          friendsHeader(title: 'FRIENDS', subtitle: '{{auth.user.email}}'),
          Mp.sizedBox(height: 22),
          _featureButton(
            'add',
            'SHOW MY QR',
            'Create a five-minute invitation',
            friendsMint,
            openInvite(),
          ),
          Mp.sizedBox(height: 10),
          _featureButton(
            'search',
            'SCAN INVITE',
            'Send a pending friend request',
            friendsBlue,
            openScanner(),
          ),
          Mp.sizedBox(height: 10),
          _featureButton(
            'mail',
            'REQUESTS',
            'Accept or decline incoming requests',
            friendsYellow,
            openRequests(),
          ),
          Mp.sizedBox(height: 10),
          _featureButton(
            'person',
            'MY FRIENDS',
            'View accepted friendships',
            friendsMint,
            openFriendsList(),
          ),
          Mp.sizedBox(height: 24),
          Mp.button(
            label: 'SIGN OUT',
            action: signOutFriends(),
            height: 44,
            backgroundColor: friendsSurface,
            foregroundColor: friendsDanger,
            borderColor: friendsBorder,
            borderWidth: 1,
            borderRadius: 6,
            fontSize: 12,
          ),
        ],
      ),
    ),
  ),
);

MpNode _featureButton(
  String icon,
  String title,
  String subtitle,
  String color,
  MpAction action,
) => Mp.tap(
  action: action,
  semanticLabel: title,
  child: Mp.container(
    paddingHorizontal: 16,
    paddingVertical: 18,
    backgroundColor: friendsSurface,
    borderColor: friendsBorder,
    borderWidth: 1,
    borderRadius: 8,
    child: Mp.row(
      children: <MpNode>[
        Mp.container(
          width: 48,
          height: 48,
          backgroundColor: friendsSurfaceStrong,
          borderRadius: 8,
          child: Mp.center(
            child: Mp.icon(icon, semanticLabel: title, size: 25, color: color),
          ),
        ),
        Mp.sizedBox(width: 14),
        Mp.expanded(
          child: Mp.column(
            children: <MpNode>[
              Mp.text(title, color: friendsText, size: 16, weight: 'semibold'),
              Mp.sizedBox(height: 3),
              Mp.text(subtitle, color: friendsMuted, size: 12),
            ],
          ),
        ),
        Mp.icon(
          'chevronRight',
          semanticLabel: 'Open',
          size: 22,
          color: friendsMuted,
        ),
      ],
    ),
  ),
);
