"""Check C462 terminal results through canonical transparent value wrappers."""
import argparse
import json
import re
from pathlib import Path

NODE = re.compile(r'^node (\d+) kind (\d+) parent (-?\d+) .*? type ([\d/-]+) .*? opcode (-?\d+) operands (-?\d+)/(-?\d+)/(-?\d+) flags (\d+)$')
UINT64 = '11/1/1/-1/11/0'


def verify(text):
    nodes = {}
    for line in text.splitlines():
        match = NODE.fullmatch(line)
        if not match:
            raise ValueError('C462_TYPED_IR_NODE_FORMAT_INVALID')
        index, kind, parent, type_id, opcode, operand0, operand1, next_operand, flags = match.groups()
        index = int(index)
        if index in nodes:
            raise ValueError('C462_TYPED_IR_DUPLICATE_NODE')
        nodes[index] = dict(kind=int(kind), parent=int(parent), type=type_id,
                            opcode=int(opcode), operand0=int(operand0), operand1=int(operand1), nextOperand=int(next_operand))
    if list(nodes) != list(range(len(nodes))):
        raise ValueError('C462_TYPED_IR_NODE_ORDER_INVALID')
    bodies = [n for n in nodes.values() if n['kind'] == 1 and n['type'] == UINT64]
    if len(bodies) != 2:
        raise ValueError('C462_TYPED_IR_TWO_UINT64_BODIES_REQUIRED')

    def resolve(index):
        seen = set()
        while True:
            if index in seen or index not in nodes:
                raise ValueError('C462_TYPED_IR_RESULT_EDGE_INVALID')
            seen.add(index)
            node = nodes[index]
            if node['type'] != UINT64:
                raise ValueError('C462_TYPED_IR_RESULT_TYPE_MISMATCH')
            if node['kind'] != 9 or node['opcode'] != -1:
                return index
            if node['operand0'] >= 0:
                index = node['operand0']
            else:
                # aggregateValueIndex uses exact direct children in sibling order;
                # a later same-type producer replaces an earlier same-type source.
                children = [i for i, child in nodes.items() if child['parent'] == index
                            and child['type'] == UINT64 and child['kind'] in (3, 5, 9, 34)]
                if not children:
                    raise ValueError('C462_TYPED_IR_WRAPPER_PRODUCER_MISSING')
                index = children[-1]

    first, second = [resolve(body['operand0']) for body in bodies]
    if nodes[first]['kind'] != 34 or nodes[second]['kind'] != 3:
        raise ValueError('C462_TYPED_IR_TERMINAL_RESULT_OWNERSHIP_MISMATCH')
    subject = nodes.get(nodes[first]['operand0'])
    if (not subject or subject['kind'] != 5 or subject['type'] != UINT64
            or subject['parent'] != nodes[first]['parent'] or subject['nextOperand'] != first):
        raise ValueError('C462_TYPED_IR_SUBJECT_IDENTITY_MISMATCH')
    return dict(status='passed', terminalResult=first, nonterminalResult=second)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        raise ValueError('C462_TYPED_IR_FRESH_PROOF_REQUIRED')
    result = verify(args.input.read_text(encoding='utf-8-sig'))
    args.output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print('C462_TYPED_IR_TERMINAL_OWNERSHIP_VALIDATED')


if __name__ == '__main__':
    main()
