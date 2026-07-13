import 'dart:convert';

import 'package:test/test.dart';

import '../mp/brain_actions.dart';
import '../mp/screens/brain_test_game.dart';

void main() {
  test('correct answer updates the current round in place', () {
    final action = answerBrainStatement(true).toJson();
    final sequence = action['props']! as Map<String, Object?>;
    final steps = sequence['steps']! as List<Object?>;
    final branch = steps[1]! as Map<String, Object?>;
    final branchProps = branch['props']! as Map<String, Object?>;
    final correctBranch = branchProps['then']! as Map<String, Object?>;
    final encoded = jsonEncode(correctBranch);

    expect(encoded, contains('brain.round.score'));
    expect(encoded, contains('brain.round.question_id'));
    expect(encoded, contains(brainNextQuestionAction));
    expect(encoded, isNot(contains('brain_test_game')));
    expect(encoded, isNot(contains('math.randomInt')));
  });

  test('game defines the question generator once in an action scope', () {
    final game = buildBrainTestGame().toJson();
    final props = game['props']! as Map<String, Object?>;
    final actions = props['actions']! as Map<String, Object?>;

    expect(game['type'], 'actionScope');
    expect(actions.keys, <String>[brainNextQuestionAction]);
    expect(
      jsonEncode(actions[brainNextQuestionAction]),
      contains('math.randomInt'),
    );
  });

  test('game countdown restarts from the question ID', () {
    final countdown = _findNode(buildBrainTestGame().toJson(), 'countdown');
    final props = countdown['props']! as Map<String, Object?>;

    expect(props['durationMs'], 10000);
    expect(props['running'], '{{state.brain.round.active}}');
    expect(props['restartToken'], '{{state.brain.round.question_id}}');
    expect(props['remainingState'], 'brain.round.remaining');
  });
}

Map<String, Object?> _findNode(Map<String, Object?> node, String type) {
  if (node['type'] == type) {
    return node;
  }
  final props = node['props'];
  if (props is Map<String, Object?>) {
    for (final value in props.values) {
      if (value is Map<String, Object?> && value.containsKey('type')) {
        final match = _tryFindNode(value, type);
        if (match != null) {
          return match;
        }
      }
    }
  }
  for (final child in (node['children'] as List<Object?>? ?? const [])) {
    if (child is Map<String, Object?>) {
      final match = _tryFindNode(child, type);
      if (match != null) {
        return match;
      }
    }
  }
  throw StateError('Node type $type was not found.');
}

Map<String, Object?>? _tryFindNode(Map<String, Object?> node, String type) {
  try {
    return _findNode(node, type);
  } on StateError {
    return null;
  }
}
