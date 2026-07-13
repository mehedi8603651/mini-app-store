import 'package:mini_program_ui/mini_program_ui.dart';

import '../brain_actions.dart';
import '../brain_theme.dart';

MpNode buildBrainTestGame() {
  return Mp.initialize(
    actions: initializeBrainRound(),
    loading: brainScreenMessage('Preparing challenge'),
    error: brainScreenMessage('Challenge could not start'),
    statusState: 'brain.game_status',
    errorState: 'brain.game_error',
    child: Mp.timer.countdown(
      duration: const Duration(seconds: 10),
      running: '{{state.brain.round.active}}',
      restartToken: '{{state.brain.round.question_id}}',
      remainingState: 'brain.round.remaining',
      onComplete: finishBrainRound('Time ran out'),
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
                    _gameHeader(),
                    Mp.sizedBox(height: 18),
                    _timerBand(),
                    Mp.sizedBox(height: 24),
                    _questionPanel(),
                    Mp.sizedBox(height: 26),
                    _answerButtons(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

MpNode _gameHeader() {
  return Mp.stateBuilder(
    keys: const <String>['brain.round.difficulty_label', 'brain.round.score'],
    child: brainHeader(
      title: '{{state.brain.round.difficulty_label}}',
      leadingIcon: 'close',
      leadingLabel: 'Leave round',
      leadingAction: leaveBrainRound(),
      trailing: Mp.container(
        paddingHorizontal: 12,
        paddingVertical: 9,
        backgroundColor: brainSurface,
        borderRadius: 8,
        child: Mp.text(
          'SCORE  {{state.brain.round.score}}',
          color: brainYellow,
          size: 14,
          weight: 'bold',
        ),
      ),
    ),
  );
}

MpNode _timerBand() {
  return Mp.stateBuilder(
    keys: const <String>['brain.round.remaining'],
    child: Mp.container(
      paddingHorizontal: 16,
      paddingVertical: 13,
      backgroundColor: brainSurface,
      borderColor: brainSurfaceStrong,
      borderWidth: 1,
      borderRadius: 8,
      child: Mp.row(
        children: <MpNode>[
          Mp.icon(
            'timer',
            semanticLabel: 'Time remaining',
            size: 25,
            color: brainCyan,
          ),
          Mp.sizedBox(width: 10),
          Mp.expanded(
            child: Mp.text(
              'TIME LEFT',
              color: brainMuted,
              size: 13,
              weight: 'semibold',
            ),
          ),
          Mp.text(
            '{{state.brain.round.remaining}} s',
            color: brainText,
            size: 22,
            weight: 'bold',
          ),
        ],
      ),
    ),
  );
}

MpNode _questionPanel() {
  return Mp.stateBuilder(
    keys: const <String>[
      'brain.round.expression',
      'brain.round.displayed_answer',
      'brain.round.math_error',
    ],
    child: Mp.container(
      height: 260,
      paddingHorizontal: 20,
      paddingVertical: 22,
      backgroundColor: brainYellow,
      borderRadius: 8,
      child: Mp.column(
        children: <MpNode>[
          Mp.text(
            'TRUE OR FALSE?',
            color: brainYellowDark,
            size: 13,
            weight: 'bold',
            align: 'center',
          ),
          Mp.spacer(),
          Mp.text(
            '{{state.brain.round.expression}}',
            color: brainBackground,
            size: 33,
            weight: 'bold',
            align: 'center',
            maxLines: 2,
            overflow: 'ellipsis',
          ),
          Mp.sizedBox(height: 12),
          Mp.text(
            '= {{state.brain.round.displayed_answer}}',
            color: brainBackground,
            size: 45,
            weight: 'bold',
            align: 'center',
            maxLines: 1,
            overflow: 'ellipsis',
          ),
          Mp.spacer(),
          Mp.text(
            '{{state.brain.round.math_error.message}}',
            color: brainRed,
            size: 12,
            align: 'center',
            maxLines: 1,
            overflow: 'ellipsis',
          ),
        ],
      ),
    ),
  );
}

MpNode _answerButtons() {
  return Mp.grid(
    columns: 2,
    spacing: 14,
    children: <MpNode>[
      Mp.aspectRatio(
        aspectRatio: 1.15,
        child: Mp.button(
          label: 'TRUE',
          action: answerBrainStatement(true),
          height: 128,
          backgroundColor: brainGreen,
          foregroundColor: brainBackground,
          borderColor: brainGreen,
          borderRadius: 8,
          fontSize: 24,
          fontWeight: 'bold',
        ),
      ),
      Mp.aspectRatio(
        aspectRatio: 1.15,
        child: Mp.button(
          label: 'FALSE',
          action: answerBrainStatement(false),
          height: 128,
          backgroundColor: brainRed,
          foregroundColor: brainText,
          borderColor: brainRed,
          borderRadius: 8,
          fontSize: 24,
          fontWeight: 'bold',
        ),
      ),
    ],
  );
}
