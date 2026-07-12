import 'package:mini_program_ui/mini_program_ui.dart';

const _black = '#FF000000';
const _surface = '#FF1F1F1F';
const _accent = '#FFFF5258';
const _text = '#FFF5F5F5';
const _muted = '#FF9A9A9A';

MpNode buildCalculatorHistory() {
  return Mp.container(
    backgroundColor: _black,
    child: Mp.safeArea(
      child: Mp.scrollView(
        paddingAll: 18,
        child: Mp.column(
          children: <MpNode>[
            Mp.row(
              children: <MpNode>[
                Mp.iconButton(
                  'arrowBack',
                  semanticLabel: 'Back to calculator',
                  action: Mp.navigation.popScreen(),
                  size: 46,
                  iconSize: 27,
                  color: _text,
                  backgroundColor: _black,
                  borderRadius: 23,
                ),
                Mp.sizedBox(width: 8),
                Mp.expanded(
                  child: Mp.text(
                    'History',
                    color: _text,
                    size: 25,
                    weight: 'semibold',
                  ),
                ),
                Mp.button(
                  label: 'Clear',
                  action: _clearHistory(),
                  height: 42,
                  backgroundColor: _surface,
                  foregroundColor: _accent,
                  borderColor: _surface,
                  borderRadius: 21,
                  fontSize: 15,
                ),
              ],
            ),
            Mp.sizedBox(height: 18),
            Mp.stateBuilder(
              keys: const <String>['calc.history'],
              child: Mp.repeat(
                source: '{{state.calc.history}}',
                limit: 50,
                spacing: 10,
                empty: Mp.container(
                  paddingAll: 28,
                  backgroundColor: _surface,
                  borderRadius: 8,
                  child: Mp.column(
                    children: <MpNode>[
                      Mp.icon(
                        'history',
                        semanticLabel: 'Empty calculation history',
                        size: 32,
                        color: _muted,
                      ),
                      Mp.sizedBox(height: 12),
                      Mp.text(
                        'No calculations yet',
                        color: _muted,
                        size: 16,
                        align: 'center',
                      ),
                    ],
                  ),
                ),
                itemTemplate: Mp.container(
                  paddingHorizontal: 16,
                  paddingVertical: 13,
                  backgroundColor: _surface,
                  borderRadius: 8,
                  child: Mp.column(
                    children: <MpNode>[
                      Mp.text(
                        '{{item.expression}}',
                        color: _muted,
                        size: 15,
                        align: 'end',
                        maxLines: 2,
                        overflow: 'ellipsis',
                      ),
                      Mp.sizedBox(height: 4),
                      Mp.text(
                        '= {{item.result}}',
                        color: _text,
                        size: 22,
                        weight: 'medium',
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
  );
}

MpAction _clearHistory() {
  return Mp.action.sequence(<MpAction>[
    Mp.cache.state.remove(
      'calculator_history',
      requestId: 'calculator-clear-history',
    ),
    Mp.state.set('calc.history', const <Object?>[]),
  ]);
}
