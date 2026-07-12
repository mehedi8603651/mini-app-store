import 'package:mini_program_ui/mini_program_ui.dart';

const _black = '#FF000000';
const _surface = '#FF252525';
const _memorySurface = '#FF202020';
const _operatorSurface = '#FF481719';
const _accent = '#FFFF5258';
const _text = '#FFF5F5F5';
const _muted = '#FF9A9A9A';

MpNode buildCalculatorHome() {
  return Mp.initialize(
    actions: <MpAction>[
      Mp.cache.state.get(
        'calculator_memory',
        targetState: 'calc.memory',
        skipMissing: true,
        requestId: 'calculator-load-memory',
      ),
      Mp.state.setDefault('calc.memory', 0),
      Mp.cache.state.get(
        'calculator_history',
        targetState: 'calc.history',
        skipMissing: true,
        requestId: 'calculator-load-history',
      ),
      Mp.state.setDefault('calc.history', const <Object?>[]),
      Mp.state.setDefault('calc.expression', ''),
      Mp.state.setDefault('calc.result', 0),
    ],
    loading: _screenMessage('Loading calculator'),
    error: _screenMessage('Calculator could not start'),
    statusState: 'calc.status',
    errorState: 'calc.startup_error',
    child: Mp.container(
      backgroundColor: _black,
      child: Mp.safeArea(
        child: Mp.scrollView(
          paddingHorizontal: 18,
          paddingTop: 10,
          paddingBottom: 18,
          child: Mp.center(
            child: Mp.container(
              width: 420,
              child: Mp.column(
                children: <MpNode>[
                  _header(),
                  Mp.sizedBox(height: 14),
                  _display(),
                  Mp.sizedBox(height: 14),
                  Mp.grid(
                    columns: 4,
                    spacing: 10,
                    children: <MpNode>[
                      _memoryKey('mc', _memoryClear()),
                      _memoryKey('m+', _memoryAdd()),
                      _memoryKey('m-', _memorySubtract()),
                      _memoryKey('mr', _memoryRecall()),
                    ],
                  ),
                  Mp.sizedBox(height: 10),
                  Mp.grid(
                    columns: 4,
                    spacing: 10,
                    children: <MpNode>[
                      _key('AC', _clear(), foreground: _accent),
                      Mp.aspectRatio(
                        aspectRatio: 1,
                        child: Mp.iconButton(
                          'backspace',
                          semanticLabel: 'Backspace',
                          action: Mp.state.backspace('calc.expression'),
                          size: 68,
                          iconSize: 28,
                          color: _accent,
                          backgroundColor: _surface,
                          borderRadius: 999,
                        ),
                      ),
                      _key('+/-', _toggleSign(), foreground: _accent),
                      _operatorKey('÷', '/'),
                      _numberKey('7'),
                      _numberKey('8'),
                      _numberKey('9'),
                      _operatorKey('×', '*'),
                      _numberKey('4'),
                      _numberKey('5'),
                      _numberKey('6'),
                      _operatorKey('−', '-'),
                      _numberKey('1'),
                      _numberKey('2'),
                      _numberKey('3'),
                      _operatorKey('+', '+'),
                      _key('%', _append('%'), foreground: _text),
                      _numberKey('0'),
                      _numberKey('.'),
                      _key(
                        '=',
                        _calculate(),
                        background: _accent,
                        foreground: _text,
                        fontSize: 36,
                      ),
                    ],
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

MpNode _header() {
  return Mp.row(
    children: <MpNode>[
      Mp.expanded(
        child: Mp.column(
          children: <MpNode>[
            Mp.text('Calculate', color: _text, size: 25, weight: 'semibold'),
            Mp.sizedBox(height: 6),
            Mp.align(
              alignment: 'centerLeft',
              child: Mp.container(
                height: 4,
                width: 132,
                backgroundColor: _accent,
                borderRadius: 2,
                child: Mp.sizedBox(width: 1, height: 1),
              ),
            ),
          ],
        ),
      ),
      Mp.iconButton(
        'history',
        semanticLabel: 'Calculation history',
        action: Mp.navigation.openScreen('calculator_history'),
        size: 48,
        iconSize: 29,
        color: _muted,
        backgroundColor: _black,
        borderRadius: 24,
      ),
    ],
  );
}

MpNode _display() {
  return Mp.container(
    height: 176,
    paddingHorizontal: 4,
    paddingVertical: 12,
    backgroundColor: _black,
    child: Mp.stateBuilder(
      keys: const <String>[
        'calc.expression',
        'calc.result',
        'calc.error',
        'calc.memory',
      ],
      child: Mp.column(
        children: <MpNode>[
          Mp.text(
            'M  {{state.calc.memory}}',
            color: _muted,
            size: 13,
            align: 'end',
            maxLines: 1,
            overflow: 'ellipsis',
          ),
          Mp.spacer(),
          Mp.text(
            '{{state.calc.expression}}',
            color: _muted,
            size: 22,
            align: 'end',
            maxLines: 2,
            overflow: 'ellipsis',
          ),
          Mp.sizedBox(height: 8),
          Mp.text(
            '{{state.calc.result}}',
            color: _text,
            size: 44,
            weight: 'medium',
            align: 'end',
            maxLines: 1,
            overflow: 'ellipsis',
          ),
          Mp.text(
            '{{state.calc.error.message}}',
            color: _accent,
            size: 12,
            align: 'end',
            maxLines: 1,
            overflow: 'ellipsis',
          ),
        ],
      ),
    ),
  );
}

MpNode _screenMessage(String message) {
  return Mp.container(
    backgroundColor: _black,
    paddingAll: 24,
    child: Mp.center(
      child: Mp.text(message, color: _muted, align: 'center'),
    ),
  );
}

MpNode _numberKey(String label) => _key(label, _append(label));

MpNode _operatorKey(String label, String value) => _key(
  label,
  _append(value),
  background: _operatorSurface,
  foreground: _accent,
  fontSize: 34,
);

MpNode _memoryKey(String label, MpAction action) => _key(
  label,
  action,
  background: _memorySurface,
  foreground: _muted,
  fontSize: 25,
);

MpNode _key(
  String label,
  MpAction action, {
  String background = _surface,
  String foreground = _text,
  num fontSize = 30,
}) {
  return Mp.aspectRatio(
    aspectRatio: 1,
    child: Mp.button(
      label: label,
      action: action,
      height: 68,
      backgroundColor: background,
      foregroundColor: foreground,
      borderColor: background,
      borderRadius: 999,
      fontSize: fontSize,
      fontWeight: 'regular',
    ),
  );
}

MpAction _append(String value) {
  return Mp.state.appendText('calc.expression', value, maxLength: 512);
}

MpAction _clear() {
  return Mp.action.sequence(<MpAction>[
    Mp.state.patch(
      <String, Object?>{'calc.expression': '', 'calc.result': 0},
      remove: const <String>['calc.error'],
    ),
  ]);
}

MpAction _toggleSign() {
  return Mp.action.sequence(<MpAction>[
    Mp.math.evaluate(
      expression: '-({{state.calc.expression}})',
      targetState: 'calc.result',
      errorState: 'calc.error',
    ),
    Mp.state.copy(
      from: 'calc.result',
      to: 'calc.expression',
      convertTo: 'text',
    ),
  ]);
}

MpAction _calculate() {
  return Mp.action.sequence(<MpAction>[
    Mp.math.evaluate(
      expression: '{{state.calc.expression}}',
      targetState: 'calc.result',
      errorState: 'calc.error',
    ),
    Mp.state.listPrepend('calc.history', <String, Object?>{
      'expression': '{{state.calc.expression}}',
      'result': '{{state.calc.result}}',
    }, maxItems: 50),
    Mp.cache.state.set(
      'calculator_history',
      '{{state.calc.history}}',
      requestId: 'calculator-save-history',
    ),
    Mp.state.copy(
      from: 'calc.result',
      to: 'calc.expression',
      convertTo: 'text',
    ),
  ]);
}

MpAction _memoryClear() {
  return Mp.action.sequence(<MpAction>[
    Mp.state.set('calc.memory', 0),
    _saveMemory(),
  ]);
}

MpAction _memoryAdd() {
  return Mp.action.sequence(<MpAction>[
    Mp.state.increment('calc.memory', by: '{{state.calc.result}}'),
    _saveMemory(),
  ]);
}

MpAction _memorySubtract() {
  return Mp.action.sequence(<MpAction>[
    Mp.state.decrement('calc.memory', by: '{{state.calc.result}}'),
    _saveMemory(),
  ]);
}

MpAction _memoryRecall() {
  return Mp.action.sequence(<MpAction>[
    Mp.state.copy(from: 'calc.memory', to: 'calc.result'),
    Mp.state.copy(
      from: 'calc.memory',
      to: 'calc.expression',
      convertTo: 'text',
    ),
    Mp.state.remove('calc.error'),
  ]);
}

MpAction _saveMemory() {
  return Mp.cache.state.set(
    'calculator_memory',
    '{{state.calc.memory}}',
    requestId: 'calculator-save-memory',
  );
}
