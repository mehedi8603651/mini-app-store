import 'package:mini_program_ui/mini_program_ui.dart';

import 'screens/friends_home.dart';
import 'screens/friends_invite.dart';
import 'screens/friends_list.dart';
import 'screens/friends_requests.dart';
import 'screens/friends_scan.dart';

final miniProgram = MpProgram(
  screens: <String, MpScreenBuilder>{
    'friends_home': buildFriendsHome,
    'friends_invite': buildFriendsInvite,
    'friends_scan': buildFriendsScan,
    'friends_requests': buildFriendsRequests,
    'friends_list': buildFriendsList,
  },
);
