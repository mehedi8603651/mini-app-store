import 'package:mini_program_ui/mini_program_ui.dart';

import '../brain_actions.dart';
import '../brain_theme.dart';

MpNode buildBrainTestHome() {
  return Mp.initialize(
    actions: initializeBrainProfile(),
    loading: brainScreenMessage('Loading Brain Test'),
    error: brainScreenMessage('Brain Test could not start'),
    statusState: 'brain.home_status',
    errorState: 'brain.home_error',
    child: Mp.container(
      backgroundColor: brainBackground,
      child: Mp.safeArea(
        child: Mp.scrollView(
          paddingHorizontal: 20,
          paddingTop: 16,
          paddingBottom: 24,
          child: Mp.center(
            child: Mp.container(
              width: 440,
              child: Mp.column(
                children: <MpNode>[
                  _homeHeader(),
                  Mp.sizedBox(height: 26),
                  _brainHero(),
                  Mp.sizedBox(height: 26),
                  _profileSummary(),
                  Mp.sizedBox(height: 28),
                  Mp.text(
                    'Choose a challenge',
                    color: brainText,
                    size: 21,
                    weight: 'semibold',
                  ),
                  Mp.sizedBox(height: 12),
                  Mp.stateBuilder(
                    keys: const <String>[
                      'brain.profile.best.easy',
                      'brain.profile.best.medium',
                      'brain.profile.best.difficult',
                    ],
                    child: Mp.column(
                      children: <MpNode>[
                        _difficultyButton(
                          label: 'EASY   +  -  x  /',
                          best: '{{state.brain.profile.best.easy}}',
                          color: brainCyan,
                          foreground: brainBackground,
                          action: startBrainRound(
                            difficultyKey: 'easy',
                            difficultyLabel: 'Easy',
                            level: 1,
                          ),
                        ),
                        Mp.sizedBox(height: 12),
                        _difficultyButton(
                          label: 'MEDIUM   MIXED + %',
                          best: '{{state.brain.profile.best.medium}}',
                          color: brainYellow,
                          foreground: brainBackground,
                          action: startBrainRound(
                            difficultyKey: 'medium',
                            difficultyLabel: 'Medium',
                            level: 2,
                          ),
                        ),
                        Mp.sizedBox(height: 12),
                        _difficultyButton(
                          label: 'DIFFICULT   ( )  %  ^',
                          best: '{{state.brain.profile.best.difficult}}',
                          color: brainCoral,
                          foreground: brainText,
                          action: startBrainRound(
                            difficultyKey: 'difficult',
                            difficultyLabel: 'Difficult',
                            level: 3,
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
    ),
  );
}

MpNode _homeHeader() {
  return Mp.row(
    children: <MpNode>[
      Mp.container(
        width: 44,
        height: 44,
        backgroundColor: brainYellow,
        borderRadius: 8,
        child: Mp.center(
          child: Mp.icon(
            'bolt',
            semanticLabel: 'Brain Test mark',
            size: 27,
            color: brainBackground,
          ),
        ),
      ),
      Mp.sizedBox(width: 12),
      Mp.expanded(
        child: Mp.text(
          'BRAIN TEST',
          color: brainText,
          size: 22,
          weight: 'bold',
        ),
      ),
      Mp.iconButton(
        'history',
        semanticLabel: 'Score history',
        action: Mp.router.push('brain_test_history'),
        size: 44,
        iconSize: 25,
        color: brainYellow,
        backgroundColor: brainSurface,
        borderColor: brainSurfaceStrong,
        borderWidth: 1,
        borderRadius: 8,
      ),
    ],
  );
}

MpNode _brainHero() {
  return Mp.column(
    children: <MpNode>[
      Mp.container(
        width: 132,
        height: 132,
        backgroundColor: brainYellowDark,
        borderColor: brainYellow,
        borderWidth: 2,
        borderRadius: 8,
        child: Mp.center(
          child: Mp.icon(
            'brain',
            semanticLabel: 'Brain challenge',
            size: 82,
            color: brainYellow,
          ),
        ),
      ),
      Mp.sizedBox(height: 18),
      Mp.text(
        'Think fast. Trust the math.',
        color: brainText,
        size: 26,
        weight: 'bold',
        align: 'center',
      ),
      Mp.sizedBox(height: 7),
      Mp.text(
        '10 seconds for every true-or-false challenge',
        color: brainMuted,
        size: 15,
        align: 'center',
      ),
    ],
  );
}

MpNode _profileSummary() {
  return Mp.stateBuilder(
    keys: const <String>['brain.profile.rounds', 'brain.profile.total_score'],
    child: Mp.container(
      paddingHorizontal: 18,
      paddingVertical: 15,
      backgroundColor: brainSurface,
      borderColor: brainSurfaceStrong,
      borderWidth: 1,
      borderRadius: 8,
      child: Mp.row(
        children: <MpNode>[
          Mp.expanded(
            child: _summaryValue('{{state.brain.profile.rounds}}', 'ROUNDS'),
          ),
          Mp.container(
            width: 1,
            height: 42,
            backgroundColor: brainSurfaceStrong,
            child: Mp.sizedBox(width: 1, height: 1),
          ),
          Mp.expanded(
            child: _summaryValue(
              '{{state.brain.profile.total_score}}',
              'CORRECT',
            ),
          ),
        ],
      ),
    ),
  );
}

MpNode _summaryValue(String value, String label) {
  return Mp.column(
    children: <MpNode>[
      Mp.text(
        value,
        color: brainText,
        size: 24,
        weight: 'bold',
        align: 'center',
      ),
      Mp.text(label, color: brainMuted, size: 11, align: 'center'),
    ],
  );
}

MpNode _difficultyButton({
  required String label,
  required String best,
  required String color,
  required String foreground,
  required MpAction action,
}) {
  return Mp.button(
    label: '$label     BEST $best',
    action: action,
    height: 72,
    backgroundColor: color,
    foregroundColor: foreground,
    borderColor: color,
    borderRadius: 8,
    fontSize: 16,
    fontWeight: 'bold',
  );
}
