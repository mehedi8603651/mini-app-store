import 'package:mini_program_ui/mini_program_ui.dart';

import '../friends_actions.dart';
import '../friends_theme.dart';

MpNode buildFriendsInvite() => Mp.container(
  backgroundColor: friendsBackground,
  child: Mp.safeArea(
    child: Mp.scrollView(
      paddingHorizontal: 18,
      paddingTop: 18,
      paddingBottom: 30,
      child: Mp.center(
        child: Mp.container(
          width: 560,
          child: Mp.column(
            children: <MpNode>[
              friendsHeader(
                title: 'MY INVITE',
                subtitle: 'ONE PERSON, FIVE MINUTES',
                backAction: goBack(),
              ),
              Mp.sizedBox(height: 24),
              Mp.backendBuilder(
                requestId: 'friend_invite',
                endpoint: 'friend-invites',
                method: 'POST',
                forceRefresh: true,
                loading: friendsLoading('Creating a secure invite'),
                error: friendsError(
                  'Invite unavailable',
                  '{{backend.friend_invite.message}}',
                ),
                child: Mp.container(
                  paddingHorizontal: 22,
                  paddingVertical: 28,
                  backgroundColor: friendsSurface,
                  borderColor: friendsBorder,
                  borderWidth: 1,
                  borderRadius: 8,
                  child: Mp.column(
                    children: <MpNode>[
                      Mp.qr.generate(
                        value: '{{backend.friend_invite.data.qrPayload}}',
                        size: 270,
                        padding: 14,
                        errorCorrection: 'medium',
                        foregroundColor: '#FF11151D',
                        backgroundColor: '#FFFFFFFF',
                        semanticLabel: 'Friend invitation QR code',
                      ),
                      Mp.sizedBox(height: 18),
                      Mp.text(
                        'Let your friend scan this code.',
                        color: friendsText,
                        size: 17,
                        weight: 'semibold',
                        align: 'center',
                      ),
                      Mp.sizedBox(height: 7),
                      Mp.text(
                        'Expires {{backend.friend_invite.data.expiresAtUtc}}',
                        color: friendsMuted,
                        size: 11,
                        align: 'center',
                      ),
                      Mp.sizedBox(height: 18),
                      Mp.button(
                        label: 'CREATE NEW CODE',
                        action: regenerateInvite(),
                        height: 44,
                        backgroundColor: friendsSurfaceStrong,
                        foregroundColor: friendsBlue,
                        borderColor: friendsBorder,
                        borderWidth: 1,
                        borderRadius: 6,
                        fontSize: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
