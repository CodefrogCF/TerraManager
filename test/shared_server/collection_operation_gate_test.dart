import 'package:flutter_test/flutter_test.dart';
import 'package:terramanager/shared_server/collection_operation_gate.dart';

void main() {
  test('exclusive backup waits for edits and prevents further edits', () async {
    final gate = CollectionOperationGate();
    expect(gate.enterMutation(), isTrue);
    final generation = gate.generation;
    final exclusive = gate.enterExclusive();
    expect(gate.exclusive, isTrue);
    expect(gate.enterMutation(), isFalse);
    expect(gate.generation, generation);
    gate.leaveMutation();
    expect(await exclusive, isTrue);
    expect(gate.enterMutation(), isFalse);
    gate.leaveExclusive();
    expect(gate.enterMutation(), isTrue);
    gate.leaveMutation();
    expect(gate.generation, generation + 1);
  });
}
