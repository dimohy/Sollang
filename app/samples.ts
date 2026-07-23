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
    id: "array",
    title: "Arrays and each",
    kicker: "03 · 컬렉션",
    description: "배열을 순회하면서 하나의 mutable 합계를 갱신합니다.",
    code: `main {
    [3, 5, 8, 13, 21] => values
    0 => total!

    values -> each value {
        total! + value => total!
        "받은 값: $value" -> println
    }

    "합계 = $(total!)" -> println
}`
  },
  {
    id: "struct",
    title: "Struct projection",
    kicker: "04 · 구조체",
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
    id: "stream",
    title: "Lazy stream",
    kicker: "05 · 지연 스트림",
    description: "10억 개 범위를 만들지 않고 21개만 읽은 뒤 upstream을 중단합니다.",
    code: `import std.sequence

main {
    0 => scanned!

    1..1000000000
        -> map value {
            value
        }
        -> tap value {
            scanned! + 1 => scanned!
        }
        -> filter value {
            value % 7 == 0
        }
        -> take(3)
        -> each value {
            "발견: $value" -> println
        }

    "10억 개 중 $(scanned!)개만 검사" -> println
}`
  },
  {
    id: "sensor",
    title: "Billion sensor alerts",
    kicker: "06 · 실시간 필터링",
    description: "map·tap·filter·take가 하나의 루프로 융합되는 센서 경보 예제입니다.",
    code: `import std.sequence

struct Reading {
    sensorId: Int
    celsius: Int
}

main {
    0 => scanned!

    1..1000000000
        -> map sensorId {
            Reading {
                sensorId: sensorId
                celsius: 20 + ((sensorId % 97) * 17) % 40
            }
        }
        -> tap reading {
            reading.sensorId => scanned!
        }
        -> filter reading {
            reading.celsius >= 57
        }
        -> take(5)
        -> each alert {
            "센서 $(alert.sensorId) = $(alert.celsius)°C" -> println
        }

    "실제 검사량 = $(scanned!)" -> println
}`
  },
  {
    id: "scan",
    title: "Stateful scan",
    kicker: "07 · 누적 상태",
    description: "구조체 상태를 스트림 전체에서 유지하면서 거래 위험 임계점을 찾습니다.",
    code: `import std.sequence

struct Transaction {
    id: Int
    amount: Int
}

struct AccountState {
    lastId: Int
    withdrawn: Int
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
            lastId: 0
            withdrawn: 0
        }) account, transaction {
            AccountState {
                lastId: transaction.id
                withdrawn: account.withdrawn + transaction.amount
            }
        }
        -> filter account {
            account.withdrawn > 1000
        }
        -> take(5)
        -> each warning {
            "거래 $(warning.lastId): $(warning.withdrawn)원" -> println
        }

    "검사한 거래 = $(scanned!)" -> println
}`
  }
];
