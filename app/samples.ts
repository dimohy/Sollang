export type Sample = {
  id: string;
  title: string;
  kicker: string;
  description: string;
  code: string;
};

export const samples: Sample[] = [
  {
    id: "hello",
    title: "Hello, Sollang",
    kicker: "01 · 시작하기",
    description: "값이 화살표를 따라 함수로 흐르는 가장 작은 Sollang 프로그램입니다.",
    code: `main {
    "Hello from Sollang!" -> println
    "값이 왼쪽에서 오른쪽으로 흐릅니다." -> println
}`
  },
  {
    id: "flow",
    title: "Flow-first functions",
    kicker: "02 · 함수와 흐름",
    description: "중첩 호출 대신 데이터의 이동 방향을 그대로 읽을 수 있습니다.",
    code: `square value: Int -> Int => value * value
addTax price: Int, percent: Int -> Int {
    price + (price * percent / 100)
}

main {
    12
        -> square
        -> addTax(10)
        => total

    "결과 = $total" -> println
}`
  },
  {
    id: "struct",
    title: "Struct projection",
    kicker: "03 · 구조체",
    description: "도메인 값을 구조체로 표현하고 필드를 자연스럽게 읽습니다.",
    code: `struct Point {
    x: Int
    y: Int
}

distanceSquared point: Point -> Int {
    point.x * point.x + point.y * point.y
}

main {
    Point {
        x: 3
        y: 4
    }
        -> distanceSquared
        => distance

    "거리의 제곱 = $distance" -> println
}`
  },
  {
    id: "loop",
    title: "Mutable while",
    kicker: "04 · 반복과 상태",
    description: "명시적인 mutable 값과 while 흐름으로 작은 수열을 만듭니다.",
    code: `main {
    0 => current!
    1 => next!
    0 => count!

    count! < 8 -> while {
        "fib = $(current!)" -> println
        current! + next! => sum
        next! => current!
        sum => next!
        count! + 1 => count!
    }
}`
  },
  {
    id: "sensor-stream",
    title: "10억 센서 스트림",
    kicker: "05 · 지연 스트림",
    description: "10억 개를 만들지 않고 upstream을 필요한 만큼만 당겨 다섯 경보에서 즉시 멈춥니다.",
    code: `import std.sequence

struct Reading {
    sensorId: Int
    celsius: Int
}

main {
    0 => alertCount!
    0 => scannedCount!

    1..1000000000
        -> map sensorId {
            Reading {
                sensorId: sensorId
                celsius: 20 + ((sensorId % 97) * 17) % 40
            }
        }
        -> tap reading {
            reading.sensorId => scannedCount!
        }
        -> filter reading {
            reading.celsius >= 57
        }
        -> take(5)
        -> each alert {
            alertCount! + 1 => alertCount!
            "경보 $(alertCount!): 센서 $(alert.sensorId) = $(alert.celsius)°C" -> println
        }

    "탐색 중단: 10억 개 중 $(scannedCount!)개만 검사" -> println
}`
  },
  {
    id: "nested-stream",
    title: "중첩 주문 스트림",
    kicker: "06 · flatMap과 취소",
    description: "flatMap의 중첩 upstream에서 skip과 take가 하나의 downstream 카운터로 동작하고 일곱 번째 값에서 전체 흐름을 멈춥니다.",
    code: `import std.sequence

main {
    0 => scanned!

    1..10
        -> beforeEach outer {
        }
        -> flatMap(1..10) outer, inner {
            outer * 10 + inner
        }
        -> tap value {
            scanned! + 1 => scanned!
        }
        -> skip(3)
        -> take(4)
        -> each value {
            "$value" -> println
        }

    "scanned=$(scanned!)" -> println
}`
  },
  {
    id: "risk-stream",
    title: "거래 위험 스캔",
    kicker: "07 · 상태 스트림",
    description: "map·tap·scan·filter·take가 하나의 downstream 흐름으로 융합되어 중간 컬렉션 없이 실행됩니다.",
    code: `import std.sequence

struct Transaction {
    id: Int
    amount: Int
}

struct AccountState {
    lastTransactionId: Int
    withdrawnToday: Int
}

main {
    0 => scanned!

    1..1000000000
        -> map id {
            Transaction {
                id: id
                amount: 100 + (id % 7) * 50
            }
        }
        -> tap transaction {
            scanned! + 1 => scanned!
        }
        -> scan(AccountState {
            lastTransactionId: 0
            withdrawnToday: 0
        }) account, transaction {
            AccountState {
                lastTransactionId: transaction.id
                withdrawnToday: account.withdrawnToday + transaction.amount
            }
        }
        -> filter account {
            account.withdrawnToday > 1000
        }
        -> take(5)
        -> each warning {
            "warning tx=$(warning.lastTransactionId), withdrawn=$(warning.withdrawnToday)" -> println
        }

    "scanned=$(scanned!)" -> println
}`
  }
];
