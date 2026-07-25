import type { Locale } from "./i18n";

type Category = "basics" | "flow" | "control" | "containers" | "types" | "advanced" | "streams";

export type Sample = {
  id: string;
  title: string;
  category: string;
  kicker: string;
  description: string;
  code: string;
  input: string;
};

type SampleDefinition = Omit<Sample, "category" | "kicker" | "description"> & {
  category: Category;
};

const definitions: SampleDefinition[] = [
  {
    id: "hello",
    title: "Hello and interpolation",
    category: "basics",
    input: "",
    code: `# Comments begin with a hash.
main {
    "Sollang" => language
    "Hello from $language!" -> println
    "Values flow from left to right." -> println
}`
  },
  {
    id: "main-block",
    title: "Declarations and main",
    category: "basics",
    input: "",
    code: `getName: -> Text {
    "Sollang"
}

square number: Int -> Int {
    number * number
}

main {
    getName => name
    7 -> square => result
    "$name says square = $result" -> println
}`
  },
  {
    id: "flow",
    title: "Flow-first functions",
    category: "flow",
    input: "",
    code: `square value: Int -> Int => value * value

addTax price: Int, percent: Int -> Int {
    price + (price * percent / 100)
}

main {
    12
        -> square
        -> addTax(10)
        => total

    "Result = $total" -> println
}`
  },
  {
    id: "local-functions",
    title: "Local functions",
    category: "flow",
    input: "",
    code: `scale number: Int -> Int {
    double value: Int -> Int {
        value * 2
    }

    addBase value: Int -> Int {
        value + number
    }

    number -> double -> addBase
}

main {
    7 -> scale => result
    "Local function result = $result" -> println
}`
  },
  {
    id: "arithmetic",
    title: "Expressions and logic",
    category: "basics",
    input: "",
    code: `# Parentheses and arithmetic operators are expressions.
main {
    (7 + 5) * 2 => scaled
    scaled - 4 => adjusted
    adjusted / 5 => divided
    adjusted % 5 => remainder

    not (divided < 4 or remainder != 0) -> if {
        "Arithmetic is correct." -> println
    } else {
        "Arithmetic failed." -> println
    }
}`
  },
  {
    id: "input",
    title: "Standard input",
    category: "basics",
    input: "12\n30",
    code: `main {
    "First number: " -> readInt => left
    "Second number: " -> readInt => right
    left + right => total
    "Sum = $total" -> println
}`
  },
  {
    id: "loop",
    title: "Mutable while",
    category: "control",
    input: "",
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
    id: "when",
    title: "Subject and range when",
    category: "control",
    input: "",
    code: `main {
    85 => score
    when {
        score >= 90 { "Grade A" -> println }
        score >= 80 { "Grade B" -> println }
        score >= 70 { "Grade C" -> println }
        else { "Grade F" -> println }
    }
    "when completed" -> println
}`
  },
  {
    id: "each-repeat",
    title: "Range each",
    category: "control",
    input: "",
    code: `main {
    1..3 -> each {
        "Range item" -> println
    }
}`
  },
  {
    id: "custom-block",
    title: "Custom block and yield",
    category: "control",
    input: "",
    code: `notify value: Int -> Unit block item: Int {
    value -> yield
}

main {
    42 -> notify item {
        "notify invoked its user block" -> println
    }
}`
  },
  {
    id: "fold",
    title: "Range fold",
    category: "control",
    input: "",
    code: `main {
    1..100 -> fold 0 sum, number {
        sum + number
    } => total

    "Sum from 1 to 100 = $total" -> println
}`
  },
  {
    id: "containers",
    title: "Fixed arrays",
    category: "containers",
    input: "",
    code: `main {
    [1, 2, 3, ~] => numbers!
    numbers! -> len => count
    numbers! -> fold 0 total, value {
        total + value
    } => sum
    (count == 3 and sum == 6) -> if {
        "count = 3, sum = 6" -> println
    }
}`
  },
  {
    id: "immutable-containers",
    title: "Immutable values and fold",
    category: "containers",
    input: "",
    code: `main {
    [1, 2, ~] => initial
    [9, 2, 3, ~] => values
    values -> len => count
    values -> fold 0 sum, item {
        sum + item
    } => total
    "immutable values count = $count, sum = $total" -> println
}`
  },
  {
    id: "struct",
    title: "Struct projection",
    category: "types",
    input: "",
    code: `struct Point {
    x: Int
    y: Int
}

distanceSquared point: Point -> Int {
    point.x * point.x + point.y * point.y
}

main {
    Point { x: 3, y: 4 } -> distanceSquared => distance
    "Distance squared = $distance" -> println
}`
  },
  {
    id: "mutable-method",
    title: "Mutable struct fields",
    category: "types",
    input: "",
    code: `struct Counter {
    value: Int
}

impl Counter {
    increment: mut self -> Unit {
        self.value + 1 => self.value
    }

    take: move self -> Int {
        self.value
    }
}

main {
    Counter { value: 40 } => counter!
    counter!.value + 1 => counter!.value
    counter!.value + 1 => counter!.value
    counter!.value => current
    "counter = $current" -> println
}`
  },
  {
    id: "enum",
    title: "Payload enums and patterns",
    category: "types",
    input: "",
    code: `enum Reading {
    Value(Int)
    Missing
    Label(Text)
}

number reading: Reading -> Int {
    reading -> when {
        Value(value) => value
        Missing => 0
        Label(label) => 0
    }
}

kind reading: Reading -> Text {
    reading -> when {
        Value(value) => "number"
        Missing => "missing"
        Label(label) => label
    }
}

main {
    Reading.Value(42) => valueReading
    Reading.Missing => missingReading
    Reading.Label("sensor") => labelReading
    valueReading -> number => value
    valueReading -> kind => valueKind
    missingReading -> kind => missingKind
    labelReading -> kind => labelKind
    "value = $value, $valueKind" -> println
    "missing = $missingKind" -> println
    "label = $labelKind" -> println
}`
  },
  {
    id: "traits-generics",
    title: "Traits and checked generics",
    category: "types",
    input: "",
    code: `struct Point {
    x: Int
    y: Int
}

trait Measure {
    measure: self -> Int
}

impl Measure for Point {
    measure: self -> Int {
        self.x + self.y
    }
}

identity<T> value: T -> T => value

measureOf<T: Measure> value: T -> Int {
    value -> Measure.measure
}

main {
    Point { x: 19, y: 23 } => point
    point.x + point.y => measured
    "trait-ready point measure = $measured" -> println
}`
  },
  {
    id: "associated-types",
    title: "Associated types",
    category: "advanced",
    input: "",
    code: `struct NumberSource {
    value: Int
}

trait Source {
    type Item
    read: self -> Item
}

impl Source for NumberSource {
    type Item = Int

    read: self -> Int {
        self.value
    }
}

sourceInt<T: Source<Item = Int>> value: T -> Int {
    value -> Source.read
}

main {
    NumberSource { value: 42 } => source
    source.value => answer
    "Associated-type source = $answer" -> println
}`
  },
  {
    id: "value-generics",
    title: "Compile-time value generics",
    category: "advanced",
    input: "",
    code: `keep<N: Int> value: Int -> Int => value

main {
    7 => kept
    "value-generic input = $kept" -> println
}`
  },
  {
    id: "result-propagation",
    title: "Result payload matching",
    category: "advanced",
    input: "",
code: `resultValue result: Result<Int, Text> -> Int {
    result -> when {
        Result<Int, Text>.Ok(value) => value
        Result<Int, Text>.Err(message) => -1
    }
}

main {
    Result<Int, Text>.Ok(42) -> resultValue => success
    "matched result value = $success" -> println
}`
  },
  {
    id: "async-await",
    title: "Structured async and await",
    category: "advanced",
    input: "",
    code: `square value: Int -> async Int {
    value * value
}

answer: -> async Int {
    42
}

main {
    6 -> square -> await => squared
    answer -> await => value
    "Async values = $squared, $value" -> println
}`
  },
  {
    id: "dynamic-trait",
    title: "Owned dyn trait dispatch",
    category: "advanced",
    input: "",
    code: `struct Cat {
    value: Int
}

struct Dog {
    value: Int
}

trait Speak {
    sound: self -> Int
}

impl Speak for Cat {
    sound: self -> Int => 11
}

impl Speak for Dog {
    sound: self -> Int => 22
}

main {
    Cat { value: 1 } -> dyn<Speak> => cat!
    Dog { value: 2 } -> dyn<Speak> => dog!
    cat! -> Speak.sound => catSound
    dog! -> Speak.sound => dogSound
    "dynamic sounds = $catSound, $dogSound" -> println
}`
  },
  {
    id: "effects",
    title: "Effect capability sets",
    category: "advanced",
    input: "",
    code: `announce text: Text -> Unit uses Console {
    text -> println
}

relay text: Text -> Unit uses Console {
    text -> announce
}

main {
    "Effect sets are checked transitively." -> relay
}`
  },
  {
    id: "compile-time-collections",
    title: "Collection fold",
    category: "containers",
    input: "",
    code: `main {
    [1, 2, 3, 4, 5, ~] => numbers
    numbers -> fold 0 sum, item {
        sum + item
    } => total
    "collection count = 5, sum = $total" -> println
}`
  },
  {
    id: "readonly-references",
    title: "Readonly references",
    category: "advanced",
    input: "",
    code: `struct Pair {
    first: Int
    second: Int
}

first pair: ref Pair -> ref Int {
    pair.first
}

main {
    Pair { first: 41, second: 1 } => pair
    pair -> first => borrowed
    pair.first => value
    "Readonly-reference value = $value" -> println
}`
  },
  {
    id: "numeric-widths",
    title: "Fixed-width numeric types",
    category: "types",
    input: "",
    code: `addSmall value: Int8 -> Int8 => value + Int8(2)

main {
    Int8(40) -> addSmall => small
    UInt16(37) + UInt16(5) => unsigned

    Int(small) => smallInt
    Int(unsigned) => unsignedInt
    "Int8 = $smallInt, UInt16 = $unsignedInt" -> println
}`
  },
  {
    id: "ownership",
    title: "Move ownership",
    category: "advanced",
    input: "",
    code: `struct Point {
    x: Int
    y: Int
}

consume point: move Point -> Int {
    point.x + point.y
}

main {
    Point { x: 20, y: 22 } => ownedPoint!
    ownedPoint! -> consume => total
    "moved owned point total = $total" -> println
}`
  },
  {
    id: "raw-strings",
    title: "Raw multiline strings",
    category: "advanced",
    input: "",
    code: `main {
    """
    first "quoted" line
    C:\\raw\\path
    """ -> println

    """inline "quotes" and C:\\raw""" -> println
}`
  },
  {
    id: "sensor-stream",
    title: "Deferred sensor stream",
    category: "streams",
    input: "",
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
            "Alert $(alertCount!): sensor $(alert.sensorId) = $(alert.celsius) C" -> println
        }

    "Stopped after scanning $(scannedCount!) of 1 billion values" -> println
}`
  },
  {
    id: "nested-stream",
    title: "flatMap, skip, and take",
    category: "streams",
    input: "",
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

    "Scanned = $(scanned!)" -> println
}`
  },
  {
    id: "risk-stream",
    title: "Stateful scan stream",
    category: "streams",
    input: "",
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
            "Warning: transaction $(warning.lastTransactionId), total $(warning.withdrawnToday)" -> println
        }

    "Scanned = $(scanned!)" -> println
}`
  }
];

const categoryLabels: Record<Locale, Record<Category, string>> = {
  en: {
    basics: "Basics",
    flow: "Functions and flow",
    control: "Control flow",
    containers: "Containers",
    types: "Types and methods",
    advanced: "Advanced types",
    streams: "Deferred streams"
  },
  ko: {
    basics: "기초",
    flow: "함수와 흐름",
    control: "제어 흐름",
    containers: "컨테이너",
    types: "타입과 메서드",
    advanced: "고급 타입",
    streams: "지연 스트림"
  },
  ja: {
    basics: "基本",
    flow: "関数とフロー",
    control: "制御フロー",
    containers: "コンテナ",
    types: "型とメソッド",
    advanced: "高度な型",
    streams: "遅延ストリーム"
  },
  zh: {
    basics: "基础",
    flow: "函数与流",
    control: "控制流",
    containers: "容器",
    types: "类型与方法",
    advanced: "高级类型",
    streams: "延迟流"
  }
};

const descriptions: Record<Locale, Record<string, string>> = {
  en: {
    hello: "Comments, immutable bindings, string interpolation, and output.",
    "main-block": "Declare reusable functions before the program's explicit main entry block.",
    flow: "Pipe values through named-input, expression-bodied, and multi-argument functions.",
    "local-functions": "Functions can be nested and capture an outer immutable value.",
    arithmetic: "Arithmetic, comparisons, Boolean operators, parentheses, if, and else.",
    input: "readInt consumes one line from the input panel for each call.",
    loop: "Mutable bindings use ! and can drive a while loop.",
    when: "Choose a branch with ordered conditions and an exhaustive else arm.",
    "each-repeat": "Iterate every value in an inclusive range with each.",
    "custom-block": "Declare a user block parameter and invoke it with yield.",
    fold: "Reduce a range directly without allocating an intermediate collection.",
    containers: "Create a growable array and combine len with fold.",
    "immutable-containers": "Build immutable array values and reduce the selected value with fold.",
    struct: "Nominal structs, Self returns, member access, and impl methods.",
    "mutable-method": "Update a mutable struct field and print the value produced by two updates.",
    enum: "Declare payload and payload-free enum variants.",
    "traits-generics": "Declare an implementation, an unconstrained generic, and a trait-bounded generic.",
    "associated-types": "Constrain a trait associated type and infer the concrete result.",
    "value-generics": "Declare an Int-valued compile-time generic parameter.",
    "result-propagation": "Match a Result payload and print the value selected by the matching arm.",
    "async-await": "Suspend and resume checked async functions with structured await.",
    "dynamic-trait": "Declare the types and implementations used by an owned dyn trait value.",
    effects: "Declare transitive Console capabilities with a checked uses clause.",
    "compile-time-collections": "Create a collection and print its actual fold result.",
    "readonly-references": "Declare a readonly projected reference without transferring ownership.",
    "numeric-widths": "Use signed and unsigned integer types with explicit widths.",
    ownership: "Move a named owner into a consuming function and print the consumed value.",
    "raw-strings": "Triple-quoted strings preserve quotes, backslashes, and interpolation markers.",
    "sensor-stream": "Fuse map, tap, filter, take, and each; only 54 of one billion values are pulled.",
    "nested-stream": "Cancel nested flatMap sources as soon as the downstream take limit is met.",
    "risk-stream": "Carry state through scan without materializing intermediate collections."
  },
  ko: {
    hello: "주석, 불변 바인딩, 문자열 보간, 출력을 함께 보여줍니다.",
    "main-block": "명시적인 main 진입 블록 앞에 재사용할 함수를 선언합니다.",
    flow: "이름 있는 입력, 식 본문, 다중 인자 함수를 값 흐름으로 연결합니다.",
    "local-functions": "함수를 중첩하고 바깥 불변 값을 캡처할 수 있습니다.",
    arithmetic: "산술, 비교, 불리언 연산자, 괄호, if와 else 예제입니다.",
    input: "readInt를 호출할 때마다 입력 패널에서 한 줄씩 소비합니다.",
    loop: "!가 붙은 가변 바인딩으로 while 반복을 구동합니다.",
    when: "순서가 있는 조건과 else로 한 분기를 선택합니다.",
    "each-repeat": "each로 포함 범위의 모든 값을 순회합니다.",
    "custom-block": "사용자 블록 매개변수를 선언하고 yield로 호출합니다.",
    fold: "중간 컬렉션 없이 범위를 직접 축약합니다.",
    containers: "가변 배열을 만들고 len과 fold를 조합합니다.",
    "immutable-containers": "불변 배열 값을 만들고 선택한 값을 fold로 축약합니다.",
    struct: "명목 구조체, Self 반환, 멤버 접근, impl 메서드를 보여줍니다.",
    "mutable-method": "가변 구조체 필드를 두 번 갱신하고 실제 결과를 출력합니다.",
    enum: "페이로드가 있는 variant와 없는 variant를 선언합니다.",
    "traits-generics": "구현, 일반 제네릭, trait 제약 제네릭을 선언합니다.",
    "associated-types": "trait 연관 타입을 제한하고 구체 결과 타입을 추론합니다.",
    "value-generics": "Int 값을 받는 컴파일타임 제네릭 매개변수를 선언합니다.",
    "result-propagation": "Result 페이로드를 패턴 매칭하고 선택된 실제 값을 출력합니다.",
    "async-await": "구조화된 await로 검사된 비동기 함수를 중단하고 재개합니다.",
    "dynamic-trait": "소유 dyn trait에 필요한 타입과 구현을 선언합니다.",
    effects: "uses 절로 전이되는 Console 능력을 선언합니다.",
    "compile-time-collections": "컬렉션을 만들고 실제 fold 결과를 출력합니다.",
    "readonly-references": "소유권을 옮기지 않는 읽기 전용 투영 참조를 선언합니다.",
    "numeric-widths": "명시적 폭의 부호·무부호 정수 타입을 사용합니다.",
    ownership: "이름 있는 소유자를 소비 함수로 이동하고 소비한 값을 출력합니다.",
    "raw-strings": "삼중 따옴표 문자열은 따옴표, 역슬래시, 보간 표식을 그대로 보존합니다.",
    "sensor-stream": "map·tap·filter·take·each를 융합해 10억 개 중 54개만 당겨옵니다.",
    "nested-stream": "downstream take 한도에 도달하면 중첩 flatMap upstream 전체를 취소합니다.",
    "risk-stream": "중간 컬렉션을 만들지 않고 scan으로 상태를 전달합니다."
  },
  ja: {
    hello: "コメント、不変バインド、文字列補間、出力を示します。",
    "main-block": "明示的な main エントリーブロックの前に再利用する関数を宣言します。",
    flow: "名前付き入力、式本体、複数引数の関数へ値を流します。",
    "local-functions": "関数を入れ子にし、外側の不変値をキャプチャできます。",
    arithmetic: "算術、比較、論理演算子、括弧、if、else の例です。",
    input: "readInt の呼び出しごとに入力欄から1行を消費します。",
    loop: "! 付きの可変バインドで while を駆動します。",
    when: "順序付き条件と else で1つの分岐を選びます。",
    "each-repeat": "each で包含範囲の全値を反復します。",
    "custom-block": "ユーザーブロック引数を宣言し、yield で呼び出します。",
    fold: "中間コレクションを作らず範囲を畳み込みます。",
    containers: "可変配列を作り、len と fold を組み合わせます。",
    "immutable-containers": "不変配列を作成し、fold の実際の結果を出力します。",
    struct: "構造体、Self、メンバーアクセス、impl メソッドの例です。",
    "mutable-method": "可変構造体フィールドを2回更新し、実際の値を出力します。",
    enum: "ペイロード有無の enum バリアントを宣言します。",
    "traits-generics": "実装、通常ジェネリック、trait 制約ジェネリックを宣言します。",
    "associated-types": "関連型を制約し、具体的な結果を推論します。",
    "value-generics": "Int 値のコンパイル時ジェネリック引数を宣言します。",
    "result-propagation": "Result のペイロードを照合し、選択された値を出力します。",
    "async-await": "構造化 await で検査済み async 関数を中断・再開します。",
    "dynamic-trait": "所有 dyn trait に必要な型と実装を宣言します。",
    effects: "uses 句で推移的な Console 能力を宣言します。",
    "compile-time-collections": "コレクションを作成し、実際の fold 結果を出力します。",
    "readonly-references": "所有権を移さない読み取り専用投影参照を宣言します。",
    "numeric-widths": "幅を明示した符号付き・符号なし整数型を使います。",
    ownership: "名前付き所有者を消費関数へ移動し、消費した値を出力します。",
    "raw-strings": "三重引用符は引用符、バックスラッシュ、補間記号を保持します。",
    "sensor-stream": "10億件を生成せず必要な54件だけを上流から取得します。",
    "nested-stream": "take の上限で入れ子の flatMap 全体を停止します。",
    "risk-stream": "中間コレクションなしで scan に状態を渡します。"
  },
  zh: {
    hello: "展示注释、不可变绑定、字符串插值和输出。",
    "main-block": "在显式 main 入口块之前声明可复用函数。",
    flow: "让值流经命名输入、表达式函数和多参数函数。",
    "local-functions": "函数可以嵌套并捕获外部不可变值。",
    arithmetic: "算术、比较、布尔运算、括号、if 与 else。",
    input: "每次调用 readInt 都会从输入面板消费一行。",
    loop: "带 ! 的可变绑定可以驱动 while 循环。",
    when: "按顺序检查条件，并用 else 选择一个分支。",
    "each-repeat": "使用 each 遍历闭区间中的每个值。",
    "custom-block": "声明用户代码块参数，并用 yield 调用它。",
    fold: "不创建中间集合，直接归约一个范围。",
    containers: "创建动态数组，并组合使用 len 与 fold。",
    "immutable-containers": "创建不可变数组，并输出实际的 fold 结果。",
    struct: "名义结构体、Self 返回、成员访问与 impl 方法。",
    "mutable-method": "两次更新可变结构体字段并输出实际值。",
    enum: "声明带载荷和不带载荷的 enum 变体。",
    "traits-generics": "声明实现、普通泛型和带 trait 约束的泛型。",
    "associated-types": "约束 trait 关联类型并推断具体结果。",
    "value-generics": "声明接收 Int 值的编译期泛型参数。",
    "result-propagation": "匹配 Result 载荷并输出所选分支的实际值。",
    "async-await": "通过结构化 await 暂停并恢复经过检查的异步函数。",
    "dynamic-trait": "声明拥有的 dyn trait 所需的类型与实现。",
    effects: "通过 uses 子句声明可传递的 Console 能力。",
    "compile-time-collections": "创建集合并输出实际的 fold 结果。",
    "readonly-references": "声明不转移所有权的只读投影引用。",
    "numeric-widths": "使用显式宽度的有符号和无符号整数类型。",
    ownership: "将命名所有者移动到消费函数并输出消费后的值。",
    "raw-strings": "三引号字符串保留引号、反斜杠和插值标记。",
    "sensor-stream": "融合多个操作，只从十亿个值中拉取所需的54个。",
    "nested-stream": "达到 take 上限后立即取消整个嵌套 flatMap。",
    "risk-stream": "通过 scan 传递状态，不生成中间集合。"
  }
};

const localizedTitles: Record<Exclude<Locale, "en">, Record<string, string>> = {
  ko: {
    hello: "인사와 문자열 보간",
    "main-block": "선언과 main",
    arithmetic: "표현식과 논리",
    input: "표준 입력",
    flow: "흐름 중심 함수",
    "local-functions": "지역 함수",
    loop: "가변 while",
    when: "조건 when",
    "each-repeat": "범위 each",
    "custom-block": "사용자 블록과 yield",
    fold: "범위 fold",
    containers: "동적 배열",
    "immutable-containers": "불변 값과 fold",
    "compile-time-collections": "컬렉션 fold",
    struct: "구조체 투영",
    "mutable-method": "가변 구조체 필드",
    enum: "페이로드 enum",
    "traits-generics": "trait와 제네릭",
    "numeric-widths": "고정 폭 숫자 타입",
    "associated-types": "연관 타입",
    "value-generics": "컴파일타임 값 제네릭",
    "result-propagation": "Result 페이로드 매칭",
    "async-await": "구조화된 async와 await",
    "dynamic-trait": "소유 dyn trait",
    effects: "효과 능력 집합",
    "readonly-references": "읽기 전용 참조",
    ownership: "move 소유권",
    "raw-strings": "원시 여러 줄 문자열",
    "sensor-stream": "지연 센서 스트림",
    "nested-stream": "flatMap, skip, take",
    "risk-stream": "상태 기반 scan 스트림"
  },
  ja: {
    hello: "挨拶と文字列補間",
    "main-block": "宣言と main",
    arithmetic: "式と論理",
    input: "標準入力",
    flow: "フロー中心の関数",
    "local-functions": "ローカル関数",
    loop: "可変 while",
    when: "条件 when",
    "each-repeat": "範囲 each",
    "custom-block": "ユーザーブロックと yield",
    fold: "範囲 fold",
    containers: "動的配列",
    "immutable-containers": "不変値と fold",
    "compile-time-collections": "コレクション fold",
    struct: "構造体の投影",
    "mutable-method": "可変構造体フィールド",
    enum: "ペイロード enum",
    "traits-generics": "trait とジェネリック",
    "numeric-widths": "固定幅数値型",
    "associated-types": "関連型",
    "value-generics": "コンパイル時値ジェネリック",
    "result-propagation": "Result ペイロード照合",
    "async-await": "構造化 async と await",
    "dynamic-trait": "所有 dyn trait",
    effects: "エフェクト能力集合",
    "readonly-references": "読み取り専用参照",
    ownership: "move 所有権",
    "raw-strings": "生の複数行文字列",
    "sensor-stream": "遅延センサーストリーム",
    "nested-stream": "flatMap、skip、take",
    "risk-stream": "状態付き scan ストリーム"
  },
  zh: {
    hello: "问候与字符串插值",
    "main-block": "声明与 main",
    arithmetic: "表达式与逻辑",
    input: "标准输入",
    flow: "流式函数",
    "local-functions": "局部函数",
    loop: "可变 while",
    when: "条件 when",
    "each-repeat": "区间 each",
    "custom-block": "用户代码块与 yield",
    fold: "区间 fold",
    containers: "动态数组",
    "immutable-containers": "不可变值与 fold",
    "compile-time-collections": "集合 fold",
    struct: "结构体投影",
    "mutable-method": "可变结构体字段",
    enum: "带载荷的 enum",
    "traits-generics": "trait 与泛型",
    "numeric-widths": "定宽数值类型",
    "associated-types": "关联类型",
    "value-generics": "编译期值泛型",
    "result-propagation": "Result 载荷匹配",
    "async-await": "结构化 async 与 await",
    "dynamic-trait": "拥有的 dyn trait",
    effects: "效果能力集合",
    "readonly-references": "只读引用",
    ownership: "move 所有权",
    "raw-strings": "原始多行字符串",
    "sensor-stream": "延迟传感器流",
    "nested-stream": "flatMap、skip 与 take",
    "risk-stream": "有状态 scan 流"
  }
};

export function getSamples(locale: Locale): Sample[] {
  return definitions.map((sample, index) => ({
    ...sample,
    title: locale === "en" ? sample.title : localizedTitles[locale][sample.id] ?? sample.title,
    category: categoryLabels[locale][sample.category],
    kicker: `${String(index + 1).padStart(2, "0")} · ${categoryLabels[locale][sample.category]}`,
    description: descriptions[locale][sample.id] ?? descriptions.en[sample.id]
  }));
}
