안녕하세요. 이번에는 `SmallLang`이라는 작은 언어를 사부작 만들고 있습니다.

아직은 정말 작습니다. 언어라고 부르기엔 조금 민망할 정도로요… ^^;

그래도 이제 첫 문법이 조금 더 SmallLang다워졌습니다.

```smalllang
getName: -> Text {
    "dimohy"
}

square: Int -> Int {
    it * it
}

main {
    getName -> name
    7 -> square -> num
    "Hello, {name}. square = {num}" -> print
}
```

출력은 이렇습니다.

```text
Hello, dimohy. square = 49
```

그리고 이 코드는 LLVM IR로 내려간 뒤 Windows x64 네이티브 실행 파일로 링크됩니다. 현재 생성된 exe 크기는:

```text
1,088 bytes
```

헐… 아직 기능이 작긴 하지만, 실제 실행 파일까지 만들어지는 걸 보면 재미있습니다.

## 문법은 어디로 가고 있나?

처음부터 정하고 싶었던 것은 `let`이나 `var` 없이도 자연스럽게 읽히는 바인딩이었습니다.

```smalllang
name = "dimohy"
```

여기에 최근에는 값의 흐름을 더 잘 보이게 하는 `->` 문법을 넣었습니다.

```smalllang
getName -> name
7 -> square -> num
"Hello, {name}. square = {num}" -> print
```

`getName -> name`은 `getName` 함수를 호출해서 그 결과를 `name`에 바인딩합니다.

`7 -> square -> num`은 7이라는 값이 `square` 함수로 흘러가고, 그 결과가 `num`에 바인딩됩니다.

괄호로 쓰면 `num = square(7)` 같은 형태도 가능하지만, SmallLang에서는 일단 "값이 어디로 흘러가는지"가 눈에 보이는 쪽을 선호해보려고 합니다.

함수 타입도 같은 방향성을 갖습니다.

```smalllang
square: Int -> Int {
    it * it
}
```

지금은 입력이 하나인 함수에서 그 입력을 암묵적으로 `it`으로 받습니다. 그래서 `it * it`이 됩니다. 조금 과감한 선택이긴 한데, 작은 함수에서는 꽤 단순하게 읽히네요.

## 문자열과 숫자

문자열 보간은 가장 작은 형태로 시작했습니다.

```smalllang
"Hello, {name}. square = {num}"
```

아직은 `{name}`처럼 바인딩 이름을 넣는 정도입니다. 복잡한 표현식을 문자열 안에 바로 넣는 건 조금 더 생각해보려고 합니다. 너무 빨리 다 넣으면 언어가 금방 무거워지더군요.

숫자는 현재 64-bit 정수 리터럴과 `+`, `*`를 지원합니다. `*`가 `+`보다 먼저 묶이고, 둘 다 왼쪽 결합입니다.

## 내부는 어떻게 되어 있나?

컴파일러는 최신 .NET과 C# Preview 기준으로 만들고 있습니다.

처음에는 빠르게 만들다 보니 `Program.cs`에 Lexer까지 들어갔는데… 아아… 이건 바로 정리했습니다. 지금은 역할별로 나누어 두었습니다.

- `Cli`
- `Lexing`
- `Parsing`
- `Syntax`
- `Semantics`
- `CodeGen`
- `Tooling`

Lexer와 Parser도 손으로 직접 박아두지 않고, 작은 규칙 파일에서 소스 생성기로 만들어지게 했습니다.

Lexer 규칙은 이런 식입니다.

```text
token Identifier = identifier
token String = quoted_string
token Number = number
token Plus = "+"
token Star = "*"
token Arrow = "->"
token Colon = ":"
token Equal = "="
```

Parser 규칙도 별도 파일에 둡니다.

```text
rule FunctionDeclaration = Identifier Colon FunctionSignature LeftBrace NewLine* Expression NewLine* RightBrace
rule FunctionSignature = Arrow TypeName | TypeName Arrow TypeName
rule FlowExpression = AdditiveExpression (Arrow Path)*
rule AdditiveExpression = MultiplicativeExpression (Plus MultiplicativeExpression)*
rule MultiplicativeExpression = PrimaryExpression (Star PrimaryExpression)*
```

Roslyn incremental source generator가 `syntax/smalllang.lexer`, `syntax/smalllang.grammar`를 읽고 `Lexer`, `TokenKind`, `Parser`를 생성합니다.

문법을 표현하는 곳과 C# 구현 코드를 분리하고 싶었습니다. 언어를 만드는 중인데, 언어 문법이 C# 코드 안에 너무 묻혀 있으면 조금 아쉽더군요.

## 실제로는 어떻게 실행되나?

현재 파이프라인은 이렇습니다.

```text
SmallLang source
-> generated lexer
-> generated parser
-> AST
-> semantic analysis
-> LLVM IR
-> clang object
-> lld-link exe
```

LLVM은 저장소에 넣지 않습니다. 빌드 스크립트가 없으면 `.tools` 아래로 내려받고, 도구와 산출물은 Git에 들어가지 않게 했습니다.

이번 샘플은 컴파일 시점에 전체 문자열 하나로 접어버릴 수도 있습니다. 하지만 일부러 런타임 함수 호출이 보이도록 했습니다.

생성된 LLVM IR에는 이런 형태가 들어갑니다.

```llvm
define internal i64 @smalllang_fn_square(i64 %it) #0 {
entry:
  %mul0 = mul nsw i64 %it, %it
  ret i64 %mul0
}
```

그리고 `main` 쪽에서는 실제로 이렇게 호출합니다.

```llvm
%call4 = call i64 @smalllang_fn_square(i64 7)
```

출력은 아직 `print` 하나입니다. 표면에서는:

```smalllang
"Hello, {name}. square = {num}" -> print
```

이지만 내부적으로는 문자열 조각을 UTF-8 정적 데이터로 두고, 정수는 런타임에서 십진수로 변환해 `WriteFile`로 바로 씁니다. CRT는 붙이지 않았습니다.

## 아직 남은 것들

아직 정해야 할 게 많습니다.

타입 시스템, 모듈 시스템, 메모리 모델, 크로스 플랫폼 출력, 오류 처리, 문자열 escape, `println` 여부…

후덜덜하네요 ^^;

그래도 첫 느낌은 괜찮습니다. 아주 작은 문법에서 시작해서, 직접 토큰화하고, 파싱하고, LLVM으로 내려가고, 실제 실행 파일이 만들어지는 흐름까지는 연결됐습니다.

다음은 문법을 조금씩 키워보면서도 "단순함"을 잃지 않는 쪽으로 가보려고 합니다.

가장 작은 언어가 어디까지 아름다워질 수 있을까요?

불타보아요… ^^
