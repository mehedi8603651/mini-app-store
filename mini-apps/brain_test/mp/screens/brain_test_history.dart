import 'package:mini_program_ui/mini_program_ui.dart';

import '../brain_actions.dart';
import '../brain_theme.dart';

MpNode buildBrainTestHistory() {
  return Mp.container(
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
                brainHeader(
                  title: 'History',
                  leadingAction: Mp.router.pop(),
                  trailing: Mp.button(
                    label: 'CLEAR',
                    action: clearBrainHistory(),
                    height: 40,
                    backgroundColor: brainSurface,
                    foregroundColor: brainCoral,
                    borderColor: brainSurfaceStrong,
                    borderWidth: 1,
                    borderRadius: 8,
                    fontSize: 13,
                    fontWeight: 'semibold',
                  ),
                ),
                Mp.sizedBox(height: 22),
                _bestScores(),
                Mp.sizedBox(height: 22),
                Mp.stateBuilder(
                  keys: const <String>['brain.profile.history'],
                  child: Mp.repeat(
                    source: '{{state.brain.profile.history}}',
                    limit: 30,
                    spacing: 10,
                    empty: Mp.container(
                      paddingAll: 30,
                      backgroundColor: brainSurface,
                      borderRadius: 8,
                      child: Mp.column(
                        children: <MpNode>[
                          Mp.icon(
                            'history',
                            semanticLabel: 'Empty score history',
                            size: 34,
                            color: brainMuted,
                          ),
                          Mp.sizedBox(height: 12),
                          Mp.text(
                            'No completed rounds yet',
                            color: brainMuted,
                            size: 16,
                            align: 'center',
                          ),
                        ],
                      ),
                    ),
                    itemTemplate: Mp.container(
                      paddingHorizontal: 16,
                      paddingVertical: 14,
                      backgroundColor: brainSurface,
                      borderColor: brainSurfaceStrong,
                      borderWidth: 1,
                      borderRadius: 8,
                      child: Mp.row(
                        children: <MpNode>[
                          Mp.container(
                            width: 42,
                            height: 42,
                            backgroundColor: brainYellowDark,
                            borderRadius: 8,
                            child: Mp.center(
                              child: Mp.icon(
                                'bolt',
                                semanticLabel: 'Completed round',
                                size: 24,
                                color: brainYellow,
                              ),
                            ),
                          ),
                          Mp.sizedBox(width: 12),
                          Mp.expanded(
                            child: Mp.column(
                              children: <MpNode>[
                                Mp.text(
                                  '{{item.difficulty}}',
                                  color: brainText,
                                  size: 16,
                                  weight: 'semibold',
                                ),
                                Mp.sizedBox(height: 3),
                                Mp.text(
                                  '{{item.reason}}',
                                  color: brainMuted,
                                  size: 13,
                                ),
                              ],
                            ),
                          ),
                          Mp.text(
                            '{{item.score}}',
                            color: brainCyan,
                            size: 26,
                            weight: 'bold',
                            align: 'end',
                          ),
                        ],
                      ),
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
}

MpNode _bestScores() {
  return Mp.stateBuilder(
    keys: const <String>[
      'brain.profile.best.easy',
      'brain.profile.best.medium',
      'brain.profile.best.difficult',
    ],
    child: Mp.container(
      paddingAll: 16,
      backgroundColor: brainSurface,
      borderRadius: 8,
      child: Mp.column(
        children: <MpNode>[
          Mp.row(
            children: <MpNode>[
              Mp.icon(
                'trophy',
                semanticLabel: 'Best scores',
                size: 24,
                color: brainYellow,
              ),
              Mp.sizedBox(width: 9),
              Mp.text(
                'BEST SCORES',
                color: brainText,
                size: 15,
                weight: 'bold',
              ),
            ],
          ),
          Mp.sizedBox(height: 16),
          Mp.row(
            children: <MpNode>[
              Mp.expanded(
                child: _bestValue(
                  'EASY',
                  '{{state.brain.profile.best.easy}}',
                  brainCyan,
                ),
              ),
              Mp.expanded(
                child: _bestValue(
                  'MEDIUM',
                  '{{state.brain.profile.best.medium}}',
                  brainYellow,
                ),
              ),
              Mp.expanded(
                child: _bestValue(
                  'HARD',
                  '{{state.brain.profile.best.difficult}}',
                  brainCoral,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

MpNode _bestValue(String label, String value, String color) {
  return Mp.column(
    children: <MpNode>[
      Mp.text(value, color: color, size: 25, weight: 'bold', align: 'center'),
      Mp.text(label, color: brainMuted, size: 11, align: 'center'),
    ],
  );
}
