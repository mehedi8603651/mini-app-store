import 'package:mini_program_ui/mini_program_ui.dart';

const _profileCacheKey = 'brain_test_profile';
const brainNextQuestionAction = 'nextQuestion';

List<MpAction> initializeBrainProfile() {
  return <MpAction>[
    Mp.cache.state.get(
      _profileCacheKey,
      targetState: 'brain.profile',
      skipMissing: true,
      requestId: 'brain-test-load-profile',
    ),
    Mp.state.setDefault('brain.profile', const <String, Object?>{}),
    Mp.state.setDefault('brain.profile.best.easy', 0),
    Mp.state.setDefault('brain.profile.best.medium', 0),
    Mp.state.setDefault('brain.profile.best.difficult', 0),
    Mp.state.setDefault('brain.profile.rounds', 0),
    Mp.state.setDefault('brain.profile.total_score', 0),
    Mp.state.setDefault('brain.profile.history', const <Object?>[]),
  ];
}

MpAction startBrainRound({
  required String difficultyKey,
  required String difficultyLabel,
  required int level,
}) {
  return Mp.router.push(
    'brain_test_game',
    params: <String, Object?>{
      'difficulty_key': difficultyKey,
      'difficulty_label': difficultyLabel,
      'level': level,
      'score': 0,
    },
    requestId: 'brain-test-start-$difficultyKey',
  );
}

List<MpAction> initializeBrainRound() {
  return <MpAction>[
    Mp.state.patch(
      <String, Object?>{
        'brain.round.difficulty_key': '{{route.difficulty_key}}',
        'brain.round.difficulty_label': '{{route.difficulty_label}}',
        'brain.round.level': '{{route.level}}',
        'brain.round.score': '{{route.score}}',
        'brain.round.active': false,
        'brain.round.question_id': '{{route.score}}',
        'brain.round.remaining': 10,
        'brain.round.new_best': false,
      },
      remove: const <String>[
        'brain.round.answer_correct',
        'brain.round.end_reason',
        'brain.round.math_error',
      ],
    ),
    Mp.math.compare(
      left: '{{state.brain.round.level}}',
      right: 1,
      targetState: 'brain.round.is_easy',
    ),
    Mp.math.compare(
      left: '{{state.brain.round.level}}',
      right: 2,
      targetState: 'brain.round.is_medium',
    ),
    Mp.action.call(brainNextQuestionAction),
  ];
}

MpAction answerBrainStatement(bool selectedTrue) {
  final branch = selectedTrue
      ? Mp.action.ifElse(
          condition: '{{state.brain.round.statement_true}}',
          thenAction: _correctAnswer(),
          elseAction: finishBrainRound('Wrong answer'),
        )
      : Mp.action.ifElse(
          condition: '{{state.brain.round.statement_true}}',
          thenAction: finishBrainRound('Wrong answer'),
          elseAction: _correctAnswer(),
        );
  return Mp.action.sequence(<MpAction>[
    Mp.state.set('brain.round.active', false),
    branch,
  ]);
}

MpAction leaveBrainRound() {
  return Mp.action.sequence(<MpAction>[
    Mp.state.set('brain.round.active', false),
    Mp.router.pop(requestId: 'brain-test-leave-round'),
  ]);
}

MpAction replayBrainRound() {
  return Mp.router.replace(
    'brain_test_game',
    params: <String, Object?>{
      'difficulty_key': '{{state.brain.round.difficulty_key}}',
      'difficulty_label': '{{state.brain.round.difficulty_label}}',
      'level': '{{state.brain.round.level}}',
      'score': 0,
    },
    requestId: 'brain-test-replay',
  );
}

MpAction clearBrainHistory() {
  return Mp.action.sequence(<MpAction>[
    Mp.state.set('brain.profile.history', const <Object?>[]),
    _saveProfile('brain-test-clear-history'),
  ]);
}

MpAction generateBrainQuestion() {
  return Mp.action.sequence(<MpAction>[
    Mp.state.set('brain.round.active', false),
    Mp.action.ifElse(
      condition: '{{state.brain.round.is_easy}}',
      thenAction: _easyQuestion(),
      elseAction: Mp.action.ifElse(
        condition: '{{state.brain.round.is_medium}}',
        thenAction: _mediumQuestion(),
        elseAction: _difficultQuestion(),
      ),
    ),
    Mp.math.randomInt(min: 0, max: 1, targetState: 'brain.round.truth_code'),
    Mp.math.compare(
      left: '{{state.brain.round.truth_code}}',
      right: 1,
      targetState: 'brain.round.statement_true',
    ),
    Mp.math.randomInt(min: 1, max: 3, targetState: 'brain.round.wrong_offset'),
    Mp.action.ifElse(
      condition: '{{state.brain.round.statement_true}}',
      thenAction: Mp.state.copy(
        from: 'brain.round.expected',
        to: 'brain.round.displayed_answer',
      ),
      elseAction: Mp.math.evaluate(
        expression:
            '{{state.brain.round.expected}} + {{state.brain.round.wrong_offset}}',
        targetState: 'brain.round.displayed_answer',
        errorState: 'brain.round.math_error',
      ),
    ),
    Mp.state.set('brain.round.active', true),
  ]);
}

MpAction _correctAnswer() {
  return Mp.action.sequence(<MpAction>[
    Mp.state.increment('brain.round.score'),
    Mp.state.increment('brain.round.question_id'),
    Mp.action.call(brainNextQuestionAction),
  ]);
}

MpAction finishBrainRound(String reason) {
  return Mp.action.sequence(<MpAction>[
    Mp.state.set('brain.round.active', false),
    Mp.state.set('brain.round.end_reason', reason),
    Mp.action.ifElse(
      condition: '{{state.brain.round.is_easy}}',
      thenAction: _updateBest('easy'),
      elseAction: Mp.action.ifElse(
        condition: '{{state.brain.round.is_medium}}',
        thenAction: _updateBest('medium'),
        elseAction: _updateBest('difficult'),
      ),
    ),
    Mp.state.increment('brain.profile.rounds'),
    Mp.state.increment(
      'brain.profile.total_score',
      by: '{{state.brain.round.score}}',
    ),
    Mp.state.listPrepend('brain.profile.history', <String, Object?>{
      'difficulty': '{{state.brain.round.difficulty_label}}',
      'difficulty_key': '{{state.brain.round.difficulty_key}}',
      'score': '{{state.brain.round.score}}',
      'reason': '{{state.brain.round.end_reason}}',
      'new_best': '{{state.brain.round.new_best}}',
    }, maxItems: 30),
    _saveProfile('brain-test-save-round'),
    Mp.router.replace('brain_test_result', requestId: 'brain-test-show-result'),
  ]);
}

MpAction _updateBest(String difficultyKey) {
  return Mp.action.sequence(<MpAction>[
    Mp.math.compare(
      left: '{{state.brain.round.score}}',
      right: '{{state.brain.profile.best.$difficultyKey}}',
      comparison: 'greaterThan',
      targetState: 'brain.round.new_best',
    ),
    Mp.action.ifElse(
      condition: '{{state.brain.round.new_best}}',
      thenAction: Mp.state.copy(
        from: 'brain.round.score',
        to: 'brain.profile.best.$difficultyKey',
      ),
      elseAction: Mp.state.set('brain.round.new_best', false),
    ),
  ]);
}

MpAction _saveProfile(String requestId) {
  return Mp.cache.state.set(
    _profileCacheKey,
    '{{state.brain.profile}}',
    requestId: requestId,
  );
}

MpAction _easyQuestion() {
  return Mp.action.sequence(<MpAction>[
    ..._randomOperands(aMax: 12, bMax: 12, cMax: 6, operationMax: 3),
    ..._operationFlags(3),
    Mp.action.ifElse(
      condition: '{{state.brain.round.op_0}}',
      thenAction: _setQuestion(
        expression: '{{state.brain.round.a}} + {{state.brain.round.b}}',
        display: '{{state.brain.round.a}} + {{state.brain.round.b}}',
      ),
      elseAction: Mp.action.ifElse(
        condition: '{{state.brain.round.op_1}}',
        thenAction: _orderedSubtraction(),
        elseAction: Mp.action.ifElse(
          condition: '{{state.brain.round.op_2}}',
          thenAction: _setQuestion(
            expression: '{{state.brain.round.a}} * {{state.brain.round.b}}',
            display: '{{state.brain.round.a}} x {{state.brain.round.b}}',
          ),
          elseAction: _exactDivision(),
        ),
      ),
    ),
  ]);
}

MpAction _mediumQuestion() {
  return Mp.action.sequence(<MpAction>[
    ..._randomOperands(
      aMin: 4,
      aMax: 25,
      bMin: 3,
      bMax: 18,
      cMax: 8,
      operationMax: 4,
    ),
    ..._operationFlags(4),
    Mp.action.ifElse(
      condition: '{{state.brain.round.op_0}}',
      thenAction: _setQuestion(
        expression:
            '{{state.brain.round.a}} + {{state.brain.round.b}} + {{state.brain.round.c}}',
        display:
            '{{state.brain.round.a}} + {{state.brain.round.b}} + {{state.brain.round.c}}',
      ),
      elseAction: Mp.action.ifElse(
        condition: '{{state.brain.round.op_1}}',
        thenAction: _setQuestion(
          expression:
              '({{state.brain.round.a}} + {{state.brain.round.b}}) * {{state.brain.round.c}}',
          display:
              '({{state.brain.round.a}} + {{state.brain.round.b}}) x {{state.brain.round.c}}',
        ),
        elseAction: Mp.action.ifElse(
          condition: '{{state.brain.round.op_2}}',
          thenAction: _setQuestion(
            expression:
                '{{state.brain.round.a}} * {{state.brain.round.b}} - {{state.brain.round.c}}',
            display:
                '{{state.brain.round.a}} x {{state.brain.round.b}} - {{state.brain.round.c}}',
          ),
          elseAction: Mp.action.ifElse(
            condition: '{{state.brain.round.op_3}}',
            thenAction: _exactDivision(),
            elseAction: _percentageQuestion(baseMax: 12),
          ),
        ),
      ),
    ),
  ]);
}

MpAction _difficultQuestion() {
  return Mp.action.sequence(<MpAction>[
    ..._randomOperands(
      aMin: 2,
      aMax: 15,
      bMin: 2,
      bMax: 10,
      cMin: 2,
      cMax: 9,
      operationMax: 5,
    ),
    ..._operationFlags(5),
    Mp.action.ifElse(
      condition: '{{state.brain.round.op_0}}',
      thenAction: _setQuestion(
        expression:
            '({{state.brain.round.a}} + {{state.brain.round.b}}) * {{state.brain.round.c}}',
        display:
            '({{state.brain.round.a}} + {{state.brain.round.b}}) x {{state.brain.round.c}}',
      ),
      elseAction: Mp.action.ifElse(
        condition: '{{state.brain.round.op_1}}',
        thenAction: _setQuestion(
          expression:
              '{{state.brain.round.a}} * {{state.brain.round.b}} - {{state.brain.round.c}}',
          display:
              '{{state.brain.round.a}} x {{state.brain.round.b}} - {{state.brain.round.c}}',
        ),
        elseAction: Mp.action.ifElse(
          condition: '{{state.brain.round.op_2}}',
          thenAction: _setQuestion(
            expression:
                '({{state.brain.round.a}} - {{state.brain.round.b}}) * {{state.brain.round.c}}',
            display:
                '({{state.brain.round.a}} - {{state.brain.round.b}}) x {{state.brain.round.c}}',
          ),
          elseAction: Mp.action.ifElse(
            condition: '{{state.brain.round.op_3}}',
            thenAction: _threeFactorDivision(),
            elseAction: Mp.action.ifElse(
              condition: '{{state.brain.round.op_4}}',
              thenAction: _percentageQuestion(baseMax: 20),
              elseAction: _powerQuestion(),
            ),
          ),
        ),
      ),
    ),
  ]);
}

List<MpAction> _randomOperands({
  int aMin = 1,
  required int aMax,
  int bMin = 1,
  required int bMax,
  int cMin = 2,
  required int cMax,
  required int operationMax,
}) {
  return <MpAction>[
    Mp.math.randomInt(min: aMin, max: aMax, targetState: 'brain.round.a'),
    Mp.math.randomInt(min: bMin, max: bMax, targetState: 'brain.round.b'),
    Mp.math.randomInt(min: cMin, max: cMax, targetState: 'brain.round.c'),
    Mp.math.randomInt(
      min: 0,
      max: operationMax,
      targetState: 'brain.round.operation',
    ),
  ];
}

List<MpAction> _operationFlags(int maxOperation) {
  return <MpAction>[
    for (var operation = 0; operation <= maxOperation; operation += 1)
      Mp.math.compare(
        left: '{{state.brain.round.operation}}',
        right: operation,
        targetState: 'brain.round.op_$operation',
      ),
  ];
}

MpAction _setQuestion({required String expression, required String display}) {
  return Mp.action.sequence(<MpAction>[
    Mp.math.evaluate(
      expression: expression,
      targetState: 'brain.round.expected',
      errorState: 'brain.round.math_error',
    ),
    Mp.state.set('brain.round.expression', display),
  ]);
}

MpAction _orderedSubtraction() {
  return Mp.action.sequence(<MpAction>[
    Mp.math.evaluate(
      expression: 'max({{state.brain.round.a}}, {{state.brain.round.b}})',
      targetState: 'brain.round.left',
      errorState: 'brain.round.math_error',
    ),
    Mp.math.evaluate(
      expression: 'min({{state.brain.round.a}}, {{state.brain.round.b}})',
      targetState: 'brain.round.right',
      errorState: 'brain.round.math_error',
    ),
    _setQuestion(
      expression: '{{state.brain.round.left}} - {{state.brain.round.right}}',
      display: '{{state.brain.round.left}} - {{state.brain.round.right}}',
    ),
  ]);
}

MpAction _exactDivision() {
  return Mp.action.sequence(<MpAction>[
    Mp.math.evaluate(
      expression: '{{state.brain.round.a}} * {{state.brain.round.b}}',
      targetState: 'brain.round.dividend',
      errorState: 'brain.round.math_error',
    ),
    _setQuestion(
      expression: '{{state.brain.round.dividend}} / {{state.brain.round.b}}',
      display: '{{state.brain.round.dividend}} / {{state.brain.round.b}}',
    ),
  ]);
}

MpAction _threeFactorDivision() {
  return Mp.action.sequence(<MpAction>[
    Mp.math.evaluate(
      expression:
          '{{state.brain.round.a}} * {{state.brain.round.b}} * {{state.brain.round.c}}',
      targetState: 'brain.round.dividend',
      errorState: 'brain.round.math_error',
    ),
    _setQuestion(
      expression: '{{state.brain.round.dividend}} / {{state.brain.round.c}}',
      display: '{{state.brain.round.dividend}} / {{state.brain.round.c}}',
    ),
  ]);
}

MpAction _percentageQuestion({required int baseMax}) {
  return Mp.action.sequence(<MpAction>[
    Mp.math.randomInt(min: 1, max: 9, targetState: 'brain.round.percent_step'),
    Mp.math.randomInt(
      min: 2,
      max: baseMax,
      targetState: 'brain.round.base_step',
    ),
    Mp.math.evaluate(
      expression: '{{state.brain.round.percent_step}} * 10',
      targetState: 'brain.round.percent',
      errorState: 'brain.round.math_error',
    ),
    Mp.math.evaluate(
      expression: '{{state.brain.round.base_step}} * 10',
      targetState: 'brain.round.base',
      errorState: 'brain.round.math_error',
    ),
    _setQuestion(
      expression: '{{state.brain.round.percent}}% * {{state.brain.round.base}}',
      display: '{{state.brain.round.percent}}% of {{state.brain.round.base}}',
    ),
  ]);
}

MpAction _powerQuestion() {
  return Mp.action.sequence(<MpAction>[
    Mp.math.randomInt(min: 2, max: 9, targetState: 'brain.round.power_base'),
    Mp.math.randomInt(
      min: 2,
      max: 4,
      targetState: 'brain.round.power_exponent',
    ),
    _setQuestion(
      expression:
          '{{state.brain.round.power_base}} ^ {{state.brain.round.power_exponent}}',
      display:
          '{{state.brain.round.power_base}} ^ {{state.brain.round.power_exponent}}',
    ),
  ]);
}
