import 'package:mini_program_ui/mini_program_ui.dart';

import '../brain_actions.dart';
import '../brain_theme.dart';

MpNode buildBrainTestResult() {
  return Mp.container(
    backgroundColor: brainBackground,
    child: Mp.safeArea(
      child: Mp.scrollView(
        paddingHorizontal: 20,
        paddingTop: 24,
        paddingBottom: 24,
        child: Mp.center(
          child: Mp.container(
            width: 440,
            child: Mp.stateBuilder(
              keys: const <String>[
                'brain.round.score',
                'brain.round.difficulty_label',
                'brain.round.end_reason',
                'brain.round.new_best',
              ],
              child: Mp.column(
                children: <MpNode>[
                  Mp.sizedBox(height: 34),
                  Mp.container(
                    width: 112,
                    height: 112,
                    backgroundColor: brainYellowDark,
                    borderColor: brainYellow,
                    borderWidth: 2,
                    borderRadius: 8,
                    child: Mp.center(
                      child: Mp.icon(
                        'trophy',
                        semanticLabel: 'Round score',
                        size: 68,
                        color: brainYellow,
                      ),
                    ),
                  ),
                  Mp.sizedBox(height: 22),
                  Mp.condition(
                    condition: '{{state.brain.round.new_best}}',
                    whenTrue: Mp.text(
                      'NEW BEST',
                      color: brainCyan,
                      size: 15,
                      weight: 'bold',
                      align: 'center',
                    ),
                    whenFalse: Mp.text(
                      'ROUND COMPLETE',
                      color: brainMuted,
                      size: 15,
                      weight: 'bold',
                      align: 'center',
                    ),
                  ),
                  Mp.sizedBox(height: 8),
                  Mp.text(
                    '{{state.brain.round.score}}',
                    color: brainText,
                    size: 72,
                    weight: 'bold',
                    align: 'center',
                  ),
                  Mp.text(
                    'correct answers',
                    color: brainMuted,
                    size: 16,
                    align: 'center',
                  ),
                  Mp.sizedBox(height: 20),
                  Mp.container(
                    paddingHorizontal: 16,
                    paddingVertical: 14,
                    backgroundColor: brainSurface,
                    borderRadius: 8,
                    child: Mp.row(
                      children: <MpNode>[
                        Mp.expanded(
                          child: Mp.text(
                            '{{state.brain.round.difficulty_label}}',
                            color: brainText,
                            size: 16,
                            weight: 'semibold',
                          ),
                        ),
                        Mp.text(
                          '{{state.brain.round.end_reason}}',
                          color: brainCoral,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                  Mp.sizedBox(height: 28),
                  Mp.button(
                    label: 'PLAY AGAIN',
                    action: replayBrainRound(),
                    height: 58,
                    backgroundColor: brainYellow,
                    foregroundColor: brainBackground,
                    borderColor: brainYellow,
                    borderRadius: 8,
                    fontSize: 17,
                    fontWeight: 'bold',
                  ),
                  Mp.sizedBox(height: 12),
                  Mp.button(
                    label: 'BACK TO LEVELS',
                    action: Mp.router.popToRoot(
                      requestId: 'brain-test-home-from-result',
                    ),
                    height: 54,
                    backgroundColor: brainSurface,
                    foregroundColor: brainText,
                    borderColor: brainSurfaceStrong,
                    borderWidth: 1,
                    borderRadius: 8,
                    fontSize: 16,
                  ),
                  Mp.sizedBox(height: 12),
                  Mp.button(
                    label: 'VIEW HISTORY',
                    action: Mp.router.push('brain_test_history'),
                    height: 54,
                    backgroundColor: brainBackground,
                    foregroundColor: brainCyan,
                    borderColor: brainCyan,
                    borderWidth: 1,
                    borderRadius: 8,
                    fontSize: 16,
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
