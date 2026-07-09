안녕하세요. 이번에는 SmallLang에 WebAssembly 타깃을 붙여봤습니다.

처음에는 Windows x64 실행 파일을 만들고, 그 다음에는 WSL을 통해 Linux x64까지 붙였는데요.
이번에는 LLVM에서 WASM으로 내려가서 브라우저에서 실행되는 흐름까지 연결했습니다.

아직은 아주 작은 단계입니다. 그래도 SmallLang 코드가 `.wasm`이 되고, 그걸 브라우저가 직접 실행해서 화면에 출력하는 흐름까지 보니 꽤 재미있네요.

## 이번 샘플

새로 추가한 예제는 이렇습니다.

```smalllang
title: -> Text {
    "SmallLang WebAssembly"
}

square: Int -> Int {
    it * it
}

main {
    title() -> runtimeName
    8 -> square() -> value
    1..5 -> fold 0 sum, i {
        sum + i
    } -> total

    "Hello from {runtimeName}" -> println()
    "8 squared = {value}" -> println()
    "1..5 sum = {total}" -> println()
}
```

출력은 이렇게 나옵니다.

```text
Hello from SmallLang WebAssembly
8 squared = 64
1..5 sum = 15
```

이제 이 출력이 콘솔 exe만이 아니라 브라우저 화면에서도 나옵니다.

## 어떻게 붙였나?

파이프라인은 기존 LLVM 흐름을 최대한 그대로 사용했습니다.

```text
SmallLang source
-> Lexer / Parser
-> Semantic lowering
-> LLVM IR
-> clang wasm32 object
-> wasm-ld
-> .wasm
-> browser
```

새 타깃 이름은 `wasm32-browser`입니다.

```powershell
.\scripts\smalllang.ps1 `
  -Source examples\23-webassembly-browser.sl `
  -Output artifacts\23-webassembly-browser.wasm `
  -Target wasm32-browser `
  -KeepTemps
```

브라우저 쪽은 아주 단순하게 만들었습니다.

WASM 모듈은 `smalllang_start`와 `memory`를 export하고, 출력은 브라우저가 제공하는 import 함수로 넘깁니다.

```text
env.smalllang_browser_write(ptr, len)
```

JavaScript는 이 포인터와 길이로 WASM linear memory에서 UTF-8 바이트를 읽고, 화면의 `<pre>`에 붙입니다.

뭔가 거창한 런타임을 넣은 것은 아니고요.
지금은 stdout에 해당하는 가장 작은 경계만 만든 셈입니다.

## 브라우저에서 실행

정적 파일 서버만 있으면 됩니다.

```powershell
python -m http.server 5080
```

그리고 브라우저에서 열면 됩니다.

```text
http://localhost:5080/examples/browser/
```

이번에 실제로 확인한 `.wasm` 크기는 622 bytes였습니다.

물론 아직 기능이 작아서 가능한 크기입니다. 앞으로 런타임이 커지면 당연히 달라지겠죠. 그래도 첫 브라우저 실행 결과로는 나쁘지 않은 출발입니다.

## 일부러 하지 않은 것

이번에는 `readInt`를 브라우저 prompt로 억지 매핑하거나, 파일 API를 LocalStorage 같은 것으로 슬쩍 바꾸지는 않았습니다.

그런 식의 fallback은 나중에 원인을 숨기기 쉽더군요.

그래서 현재 브라우저 타깃은 출력만 명확히 지원합니다. 입력이나 파일 런타임은 일단 명시적으로 실패하도록 두었습니다. 나중에 브라우저용 런타임 모델을 정하면 그때 제대로 붙이는 쪽이 좋겠다고 봤습니다.

## 확인한 것

이번 변경은 이렇게 확인했습니다.

```text
dotnet build SmallLang.slnx
dotnet run --project tests\SmallLang.ExampleTests\SmallLang.ExampleTests.csproj --no-build
```

예제 테스트는 12개 모두 통과했습니다.

그리고 Node에서 직접 WASM을 instantiate해서 `exit=0`과 출력도 확인했고, Chrome headless로 실제 브라우저 페이지 DOM에 출력이 들어오는 것도 확인했습니다.

작은 언어를 만들고 있는데, 어느새 같은 코드가 native exe도 되고, Linux ELF도 되고, 브라우저 WASM도 되네요.

아직 갈 길은 멉니다.
그런데 이런 작은 연결점들이 하나씩 생기는 게 꽤 즐겁습니다.

SmallLang이 어디까지 작고 단순하게 갈 수 있을지 계속 이어가보겠습니다.
