import 'package:mini_program_ui/mini_program_ui.dart';

import '../friends_actions.dart';
import '../friends_theme.dart';

MpNode buildFriendsScan() => Mp.container(
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
                title: 'SCAN INVITE',
                subtitle: 'REQUESTS NEED ACCEPTANCE',
                backAction: goBack(),
              ),
              Mp.sizedBox(height: 46),
              Mp.container(
                paddingHorizontal: 28,
                paddingVertical: 48,
                backgroundColor: friendsSurface,
                borderColor: friendsBorder,
                borderWidth: 1,
                borderRadius: 8,
                child: Mp.column(
                  children: <MpNode>[
                    Mp.icon(
                      'search',
                      semanticLabel: 'QR scanner',
                      size: 60,
                      color: friendsBlue,
                    ),
                    Mp.sizedBox(height: 20),
                    Mp.text(
                      'Scan your friend\'s code',
                      color: friendsText,
                      size: 23,
                      weight: 'bold',
                      align: 'center',
                    ),
                    Mp.sizedBox(height: 10),
                    Mp.text(
                      'The scanner returns inert text. Friends validates the one-time token before creating a pending request.',
                      color: friendsMuted,
                      size: 13,
                      align: 'center',
                      maxLines: 5,
                    ),
                    Mp.sizedBox(height: 28),
                    Mp.button(
                      label: 'OPEN QR SCANNER',
                      action: scanFriendInvite(),
                      height: 54,
                      backgroundColor: friendsBlue,
                      foregroundColor: friendsBackground,
                      borderColor: friendsBlue,
                      borderRadius: 6,
                      fontSize: 15,
                      fontWeight: 'semibold',
                    ),
                    Mp.sizedBox(height: 14),
                    Mp.stateBuilder(
                      keys: const <String>[
                        'friends.scan_status',
                        'friends.scan_error',
                      ],
                      child: Mp.text(
                        '{{state.friends.scan_error.message}}',
                        color: friendsDanger,
                        size: 12,
                        align: 'center',
                        maxLines: 4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
