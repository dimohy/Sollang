# Sollang Standard-Library Evolution

Status: active structured backlog
Reviewed: 2026-09-02

This document compares the current Sollang runtime and standard library with
current general-purpose language libraries. It is a prioritization contract,
not a promise to copy another ecosystem's API surface. Each addition must keep
Sollang's visible ownership and effects, reachable-module inclusion, native
Windows/Linux parity, browser capability diagnostics, and pure Sollang
implementation where an operating-system boundary is not required.

## Reference baseline

- Rust 1.98 models an internet endpoint as IPv4 or IPv6 `SocketAddr`, supports
  fallible text parsing, and groups general collections by actual data-structure
  behavior: <https://doc.rust-lang.org/std/net/enum.SocketAddr.html> and
  <https://doc.rust-lang.org/std/collections/>.
- Rust 1.98 keeps I/O and synchronization behind owned values and traits, while
  `Instant` and `Duration` remain distinct monotonic-time contracts:
  <https://doc.rust-lang.org/stable/std/io/> and
  <https://doc.rust-lang.org/stable/std/time/>.
- Rust 1.98 separates process configuration, a running child, standard-I/O
  ownership, exit status, and collected output. Its documentation also makes
  pipe-buffer deadlock and the need to reap children explicit. Go 1.27 adds
  cancellation and a wait delay that bounds a child or inherited pipe that does
  not close; Python 3.14 requires concurrent `communicate`-style draining and
  warns that collected output is memory-buffered; .NET exposes explicit stream
  redirection and asynchronous waiting. Sollang adopts the lifecycle and
  deadlock lessons, but requires explicit capture limits and an affine child
  state instead of ambient shell execution or unbounded collection:
  <https://doc.rust-lang.org/std/process/>,
  <https://pkg.go.dev/os/exec>,
  <https://docs.python.org/3.14/library/subprocess.html>, and
  <https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.processstartinfo.redirectstandardoutput>.
- Rust 1.98 slices provide allocation-free in-place unstable sorting with
  worst-case `O(n log n)` and binary-search/partition-point operations; Go 1.27
  `slices.BinarySearch` returns the earliest match or insertion position plus a
  found flag; Java SE 25 also treats array sorting and binary search as paired
  foundations. Sollang adopts those contracts without copying their global
  utility-class presentation: <https://doc.rust-lang.org/std/primitive.slice.html>,
  <https://pkg.go.dev/slices@go1.27.0>, and
  <https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/util/Arrays.html>.
- Go 1.27 `net/netip` uses small value types, keeps numeric parsing separate
  from name resolution, and provides explicit loopback and unspecified values:
  <https://pkg.go.dev/net/netip>.
- Go's `encoding/binary` makes byte order an explicit value and bounds 64-bit
  varints to ten bytes; `hash/crc32` separates the polynomial/table policy from
  reusable incremental state. Rust's fixed-width integers likewise distinguish
  big- and little-endian byte conversion instead of making native byte order a
  portable default: <https://pkg.go.dev/encoding/binary>,
  <https://pkg.go.dev/hash/crc32>, and
  <https://doc.rust-lang.org/std/primitive.u32.html>.
- Python 3.14 documents a broad portable module library while keeping socket
  address family details and DNS behavior observable:
  <https://docs.python.org/3/library/index.html> and
  <https://docs.python.org/3/library/socket.html>.
- Python 3.14 explicitly separates pure Windows/POSIX path values from concrete
  filesystem paths. Rust 1.98 and Java 25 put lexical inspection, joining, and
  normalization on the path instance while distinguishing filesystem-backed
  canonicalization or `toRealPath`; Go distinguishes purely lexical `IsLocal`
  from symlink-aware traversal. Sollang's portable path methods must therefore
  stay callable without `uses File`, while canonicalization/query remains an
  explicit effectful instance operation backed by a raw OS boundary:
  <https://docs.python.org/3.14/library/pathlib.html>,
  <https://doc.rust-lang.org/stable/std/path/struct.Path.html>,
  <https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/file/Path.html>,
  and <https://pkg.go.dev/path/filepath>.
- Python 3.14 groups gzip, zlib, bzip2, LZMA, and Zstandard under
  `compression`; its `compression.zstd` separates one-shot operations,
  incremental compressor/decompressor state, multi-frame behavior, dictionaries,
  and bounded output production. .NET 10 exposes Brotli as a reusable stream
  instance over caller-selected storage, with explicit read/write, flush, and
  asynchronous operations. Go 1.27 separates RFC 1951 DEFLATE from RFC 1950
  zlib and RFC 1952 gzip wrappers and exposes reusable reader/writer instances:
  <https://docs.python.org/3/library/compression.html>,
  <https://docs.python.org/3.14/library/compression.zstd.html>,
  <https://learn.microsoft.com/en-us/dotnet/api/system.io.compression.brotlistream?view=net-10.0>,
  <https://pkg.go.dev/compress/flate>, and <https://pkg.go.dev/compress/gzip>.
  Wire conformance is governed by RFC 7932 for ordinary Brotli and RFC 8878
  for Zstandard. RFC 9841 extends Brotli with shared dictionaries, large
  windows, and a framing container; that extension is a distinct later slice,
  not an implicit claim of the first Brotli implementation:
  <https://www.rfc-editor.org/info/rfc7932>,
  <https://www.rfc-editor.org/info/rfc8878>, and
  <https://www.rfc-editor.org/info/rfc9841>.
- .NET's core libraries treat collections, URI, date/time, streams, HTTP, and
  JSON as foundational reusable contracts:
  <https://learn.microsoft.com/en-us/dotnet/standard/class-library-overview>.
- .NET 10 separates QUIC into a reusable listener, a connection that owns no
  application bytes itself, and uni/bidirectional streams. Closing a listener
  stops later accepts without invalidating already accepted connections. This
  is the right responsibility boundary for Sollang as well, while affine
  ownership and direct intrinsic calls replace garbage-collected disposal:
  <https://learn.microsoft.com/en-us/dotnet/api/system.net.quic.quiclistener?view=net-10.0>,
  <https://learn.microsoft.com/en-us/dotnet/api/system.net.quic.quicconnection?view=net-10.0>,
  and <https://learn.microsoft.com/en-us/dotnet/api/system.net.quic.quicstream?view=net-10.0>.
- Current .NET, Rust 1.98, and Go all keep TCP I/O and lifecycle on the stream
  instance. They distinguish directional shutdown from resource close and make
  deadlines/timeouts or nonblocking behavior explicit. Rust additionally makes
  duplicated OS handles an explicit fallible `try_clone`, while Go names the
  common half-close operations `CloseRead` and `CloseWrite`. Sollang keeps its
  affine default and will not add implicit handle sharing, but should expose the
  same lifecycle and policy capabilities as typed instance operations:
  <https://learn.microsoft.com/en-us/dotnet/api/system.net.sockets.socket?view=net-10.0>,
  <https://doc.rust-lang.org/stable/std/net/struct.TcpStream.html>, and
  <https://pkg.go.dev/net>.
- High-throughput async socket designs separate the reusable operation context
  from the socket owner. .NET's caller-maintained `SocketAsyncEventArgs` avoids
  repeated per-operation allocation and makes synchronous completion observable;
  Java asynchronous channels expose pending-result or completion-handler forms,
  explicit asynchronous-close failure, and implementation-defined one-read/
  one-write outstanding limits. Rust's task contract records a waker when an
  operation is pending, while Tokio's readiness guard requires a real
  `WouldBlock` observation before clearing only the affected readiness bit.
  Sollang's next slice therefore needs bounded reusable operation slots,
  explicit pending/completed/cancelled ownership, synchronous-completion
  handling, and direction-specific readiness acknowledgement. A global callback
  registry, hidden task allocation, unconditional readiness clearing, or a
  readiness event presented as transferred bytes is not an acceptable shortcut:
  <https://learn.microsoft.com/en-us/dotnet/api/system.net.sockets.socketasynceventargs?view=net-10.0>,
  <https://docs.oracle.com/en/java/javase/26/docs/api/java.base/java/nio/channels/AsynchronousChannel.html>,
  <https://docs.oracle.com/en/java/javase/26/docs/api/java.base/java/nio/channels/AsynchronousSocketChannel.html>,
  <https://doc.rust-lang.org/std/task/>, and
  <https://docs.rs/tokio/latest/tokio/io/unix/struct.AsyncFd.html>.
- Native completion and readiness must remain distinct below that portable
  operation contract. Windows IOCP queues a completion key, operation identity,
  transferred-byte count, and success/failure, and can dequeue completion
  packets in batches. Linux `epoll` reports readiness instead; edge-triggered
  use requires nonblocking descriptors and preserving readiness until an
  operation actually reaches `EAGAIN`, with an explicit fairness policy to
  avoid starving other descriptors. The runtime may specialize each target,
  but it must normalize these differences only after preserving operation
  identity, exact byte counts, errors, cancellation, and bounded batch size:
  <https://learn.microsoft.com/en-us/windows/win32/fileio/i-o-completion-ports>,
  <https://learn.microsoft.com/en-us/windows/win32/api/ioapiset/nf-ioapiset-getqueuedcompletionstatus>,
  and <https://www.man7.org/linux/man-pages/man7/epoll.7.html>.
- Rust 1.98 keeps working directory, environment overrides/removals, inheritance
  clearing, and standard-I/O policy on `Command`; it explicitly warns that a
  relative program combined with a child working directory is platform
  ambiguous. Go's `Cmd.Wait` owns both process reaping and completion of pipe
  copy loops, with `WaitDelay` bounding a child or pipes that fail to finish.
  .NET 10 likewise states that a no-shell `WorkingDirectory` configures the
  child and does not locate its executable. Sollang therefore keeps executable
  lookup independent from `Command.workingDirectory`, makes environment
  inheritance an explicit instance policy, and will couple bounded collection
  with simultaneous stdout/stderr draining. On Windows, a non-null
  `CreateProcessW.lpApplicationName` accepts a partial path but does not search
  `PATH`; it also takes the child environment block and current directory as
  separate arguments. The runtime must therefore resolve a bare executable in
  the parent before applying the child directory, rather than relying on an
  accidental platform search order:
  <https://doc.rust-lang.org/std/process/struct.Command.html>,
  <https://pkg.go.dev/os/exec>, and
  <https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.processstartinfo.workingdirectory?view=net-10.0>,
  <https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-createprocessw>.
- Go's `net/http` keeps reusable client transport state separate from one
  request/response and distinguishes immediate server close from graceful
  shutdown. Sollang adopts those visible lifecycle distinctions, but not an
  ambient default client or unbounded background work:
  <https://pkg.go.dev/net/http>.
- .NET 10, Java SE 25, and Go 1.26 all make the HTTP client a reusable
  instance rather than a per-request convenience allocation. Java documents
  that each client normally owns its own connection pool; Go exposes a
  stateful transport with cached connections; .NET separates a client-wide
  timeout from per-request cancellation. Redirect and preferred protocol are
  explicit policies, and Go additionally withholds sensitive authorization and
  cookie headers from an unrelated redirect target. Sollang therefore makes
  `Client` the affine owner of bounded reusable transports, returns an affine
  streaming response body for each request, and returns a connection to the
  pool only after that body is completed or explicitly discarded. Client and
  request deadlines remain distinct; redirect count, HTTPS-to-HTTP downgrade,
  sensitive-header forwarding, decompression formats/output limits, and
  protocol fallback are visible policies rather than ambient behavior. .NET's
  handler also exposes pool idle/lifetime, per-server connection, response
  drain-byte/time, connect, and response-head limits; Go restricts automatic
  transport retry to idempotent requests whose bodies are absent or replayable;
  Java requires a streaming body to be read, closed, or cancelled before its
  exchange resources are reclaimed. Sollang keeps those bounds and replay
  preconditions typed, and reports native socket transport as unsupported on a
  browser target instead of manufacturing a hidden fallback:
  <https://learn.microsoft.com/en-us/dotnet/api/system.net.http.httpclient?view=net-10.0>,
  <https://learn.microsoft.com/en-us/dotnet/api/system.net.http.httpclient.timeout?view=net-10.0>,
  <https://learn.microsoft.com/en-us/dotnet/api/system.net.http.socketshttphandler?view=net-10.0>,
  <https://docs.oracle.com/en/java/javase/25/docs/api/java.net.http/java/net/http/HttpClient.html>,
  <https://docs.oracle.com/en/java/javase/25/docs/api/java.net.http/java/net/http/HttpResponse.BodyHandlers.html>,
  <https://docs.oracle.com/en/java/javase/25/docs/api/java.net.http/java/net/http/HttpClient.Redirect.html>,
  and <https://pkg.go.dev/net/http@go1.26.5>.
- Java SE 25's minimal HTTP server makes connection, idle-connection,
  request-header count/size, request time, and response time ceilings visible,
  while its own documentation limits that implementation to simple embedded
  use. Python 3.14 likewise exposes an instance-owned HTTP server but explicitly
  warns that it is not production-grade and unavailable on WASI. Sollang takes
  the explicit resource and capability boundaries, not either convenience
  server's hidden defaults or production claims:
  <https://docs.oracle.com/en/java/javase/25/docs/api/jdk.httpserver/module-summary.html>
  and <https://docs.python.org/3.14/library/http.server.html>.
- .NET 11 Preview 6 moves async suspension toward runtime ownership and adds
  zero-allocation Base64 overloads, caller-controlled process handles, ZIP CRC32
  validation, and Zstandard. These validate Sollang's runtime-scheduler and
  bounded destination-buffer directions without making preview APIs normative:
  <https://learn.microsoft.com/en-us/dotnet/core/whats-new/dotnet-11/runtime> and
  <https://learn.microsoft.com/en-us/dotnet/core/whats-new/dotnet-11/libraries>.
- Java SE 25 groups foundational collections, time, random, regex, streams,
  archives, and networking in stable modules:
  <https://docs.oracle.com/en/java/javase/25/docs/api/overview-summary.html>.
- Kotlin 2.3 makes `Clock` an injectable source instead of requiring direct
  ambient time access: <https://kotlinlang.org/api/core/kotlin-stdlib/kotlin.time/-clock/>.
- Swift's standard library centers common algorithms on `Sequence` and
  `Collection`, with explicit `Result` and strict concurrency contracts:
  <https://developer.apple.com/documentation/swift>.
- Node.js 26 enables Temporal by default and continues to expose stream
  backpressure plus caller-supplied I/O buffers. Sollang should take the
  explicit time domains and buffer ownership, not JavaScript's ambient runtime
  surface: <https://nodejs.org/en/blog/release/v26.0.0> and
  <https://nodejs.org/en/blog/release/v26.4.0>.
- RFC 8259 defines JSON's interoperable grammar. Go 1.27 makes the stricter,
  configurable `encoding/json/v2` plus low-level `jsontext` contract a standard
  library foundation, while Rust `serde_json::StreamDeserializer` provides
  token/stream-oriented processing,
  while .NET keeps maximum depth and non-standard comment/trailing-comma
  behavior explicit: <https://www.rfc-editor.org/rfc/rfc8259>,
  <https://pkg.go.dev/encoding/json/jsontext>,
  <https://docs.rs/serde_json/latest/serde_json/struct.StreamDeserializer.html>,
  and <https://learn.microsoft.com/en-us/dotnet/api/system.text.json.jsonreaderoptions>.
- Go 1.27 adds a standard UUID value and task-leak runtime profile; Python 3.14
  exposes running async-task inspection. Sollang should adopt the portable
  value and observability contracts rather than their process-global
  presentation: <https://go.dev/blog/go1.27> and
  <https://docs.python.org/3/library/asyncio.html>.
- RFC 9562 replaces RFC 4122 and defines UUIDs as 16 network-order octets, the
  8-4-4-4-12 hexadecimal presentation, variant bits in octet 8, and version
  bits in octet 6. It also standardizes sortable UUIDv7, so parsing, value
  storage, and generation sources remain separate contracts:
  <https://www.rfc-editor.org/rfc/rfc9562>.

## Current Sollang baseline

Sollang already has storage-explicit arrays and dictionaries, `Set`, `Deque`,
`BinaryHeap`, `BitSet`, lazy streams, `Option`/`Result`, affine file and socket
resources, structured async/parallel flow, Unicode `Text`, paths/directories,
an affine spawn/wait child-process lifecycle, clocks, secure randomness,
TCP/UDP, and a reachable pure Sollang
QUIC/TLS/cryptography stack. Strict, bounded, streaming hexadecimal and Base64
codecs are also implemented in pure Sollang. Those are strengths to preserve,
not reasons to grow one monolithic ambient runtime.
The URI foundation now adds bounded RFC 3986 reference parsing and strict
component-aware percent encoding without DNS, IDNA, file, or network effects.
The JSON foundation adds a strict bounded token reader and an instance-owned,
transactional writer whose completed byte buffer transfers without copying.
The HTTP foundation adds a pure, bounded HTTP/1.0 and HTTP/1.1 request/response
head parser, an incremental RFC 9112 body-framing decoder, and instance-owned
request- and response-head writers. `BodyDecoder.writeRange` decodes directly from an exact
range of caller-owned receive storage, validates bounds before mutation, and
reports range-relative consumption so a pipelined suffix remains owned by the
caller without an intermediate input copy. It preserves
repeated field order and raw spans, rejects ambiguous line endings, obsolete
folding, conflicting framing, malformed chunks, invalid trailers, response
splitting, and caller-supplied framing fields. Decoded and response-body bytes
remain caller-owned, pipelined bytes remain unconsumed, and none of these
layers performs DNS or transport work.

## Prioritized contract backlog

Machine-readable status is authoritative in
`scripts/contracts/stdlib-evolution-progress.json`; the verifier rejects missing
or stale backlog rows. Current frozen-backlog progress is **fully accepted 5/22
(22.7%); in progress 16/22; blocked 1/22; started 21/22 (95.5%)**. A contract
counts as complete only after its remaining-capability and required-platform
gates are empty; partial implementation never rounds up.

| Priority | Contract | Required shape | Status |
| --- | --- | --- | --- |
| P0 | Instance-first public APIs | Stateful/domain operations are inherent methods with pipeline calls; constructors/parsers/global boundaries are explicit exceptions; zero wrapper/allocation/copy cost | Socket and QUIC migration in progress; QUIC transcript, application-key, connection, TLS client/server, crypto buffers, prepared AES-128/GCM/QUIC keys, streaming SHA-256 and HMAC-SHA256, RTT/congestion, stream flow/limits and connection-owned stream registry, sent-packet Journal, frame Ack, version-negotiation Information, version Packet, P2P PeerRecord, Zstandard Huffman tables, and every natural `sys.path.Path` operation are inherent methods; `frame_types` and `stream_types` were folded into their canonical `std.net.quic.frame` and `std.net.quic.stream_state` modules; projected growable-field mutation uses the exact owner field without wrappers; the public `std` audit finds 296 globals, 199 reviewed exceptions, 97 migration candidates, and zero stale entries after separating protocol/error identifiers, fixed field elements, immutable module-data tables, entropy/key/domain constructors, prepared-key factories, and byte decoders from true instance debt. Zstandard entropy-table construction and byte-description decoding are reviewed factory/parser boundaries, while Huffman stream decoding is owned by its `Table` instance. The prepared AES-128/GCM/QUIC instance path removed ten one-shot crypto and packet-protection globals after fixtures 888-890, 895, 917, 929, 938, 940-943, 949, 962-963, and 966 moved. `sha256.Hasher` now owns bounded 64-byte block state, supports incremental `update`, and consumes itself with `finish`; fixtures 881, 1224 and 1225 prove split operation, repeat-literal length, and independent empty/abc/exact-64-byte expected digests; the one-shot `sha256.digest` wrapper is removed and its callers use the same `Hasher` instance contract. `hmac_sha256.Hasher` borrows its key during construction, accepts message segments through `update`, and consumes itself with `finish`; empty updates and segment boundaries preserve the complete 32-byte MAC. Its one-shot `digest` wrapper is removed, and HKDF feeds previous output, info, and the counter directly into the same instance without a growable concatenation buffer. `transport_parameters.maximumStreamCount` remains a reviewed pure protocol constant; its former raw `validateStreamCount` debt is replaced by the one-word `StreamCount` factory plus direct `count -> value` instance load. Fixture 945 preserves the RFC 9000 transport-parameter/frame error split and the contract records the private-by-default field boundary as QG1 instead of hiding it behind a heap wrapper; the separate `sys.path` inventory has zero migration debt; fixtures 423, 881-882, 888-890, 892, 895, 901-906, 915-917, 929, 938, 940-943, 945, 949, 962-963, 965-966, 1015, 1205, and 1224-1225 retain managed execution; focused native lowering is a later promotion gate |
| P1 | CPU feature dispatch | Portable target baseline, typed required/allowed/forbidden features, separately attributed specialized functions, and once-resolved implementation selection retained by algorithm instances; no per-block probing | `scripts/contracts/cpu-target-features.json` canonically records three architectures, 16 typed feature entries, LLVM spellings, OS-state requirements, and AES/GCM/SHA specialization dependencies; its schema and focused verifier reject backend/cache drift and caught the previously omitted ARM64 AES registry edge. Managed and self-host target descriptors agree on architecture, dispatch policy, and feature masks. Windows/Linux x64 require SSE2 and allow runtime-detected optional features; browser remains baseline-only. The complete contract is part of incremental codegen cache identity, preventing reuse across incompatible CPU policies. `aes128.Key` owns one 176-byte schedule with descriptor-only hot calls; both managed and self-host emitters produce a process-stable SSE2/AES CPUID snapshot, once-resolve portable versus AES-NI functions, and keep exactly nine `aesenc` plus one `aesenclast` outside the portable body. Managed/self-host focused gates freeze allocator ABI, portable isolation, target attributes, no hot schedule copy or feature probe, readonly-reference receiver lowering, and fixture 889 execution. Fixture 1226 plus the forced verification-copy differential passes 3 vectors x 2 backends x 2 paths and now requires the exact windows-x64 LLVM triple plus AMD64 PE32+ headers for every linked artifact. The explicit seven-sample promotion benchmark freezes a 0.90 median-time ratio, 1.05 peak-memory ratio, and 16 MiB AES-NI peak ceiling on both backends. It also exposed and now guards C100: the self-host portable emitter had rebuilt immutable numeric slice tables on every call; fixture 1227 freezes exact static-storage parity before the portable baseline is accepted. Full feature discovery, ARM64 AES, accelerated GHASH/SHA, and platform fixed points remain; acceleration is not yet claimed complete |
| P0 | Numeric network endpoints | Semantic loopback/wildcard constructors; strict fallible parsing; no hidden DNS | Shared IPv4 foundation implemented in `std.net`; regression 1017 |
| P1 | Shared IP endpoint values | One IPv4/IPv6 address model reusable by socket, QUIC, DNS, URI, and HTTP without borrowed-lifetime leakage | IPv4/IPv6 value, strict parser, scope ID, flow info, unified enum, socket connect/bind, live local/remote socket observation, and QUIC IPv6 bind/connect/listen/accept/stream/datagram transport are implemented. Fixture 1355 performs a real IPv6 loopback round trip, verifies every observed endpoint remains IPv6, checks the selected listener port, transfers one stream byte plus FIN and one datagram, and passes focused self-host LLVM/native execution with managed differential. Formal Windows/Linux Stage2/Stage3 promotion remains before the shared endpoint contract is complete |
| P1 | Socket stream lifecycle and policy | `TcpListener`, `TcpStream`, and `UdpSocket` own affine native handles; stream/listener/socket operations remain instance methods; directional shutdown is distinct from consuming close; deadlines, nonblocking mode, keepalive, linger, no-delay, local/peer endpoints, peek, readiness, and bounded caller-buffer I/O stay explicit; any duplicated handle requires a named fallible clone and shared-handle semantics | Affine listener/stream/datagram owners, consuming close, `ShutdownDirection`, allocating receive plus caller-buffer `receiveInto`, allocation-free stream `peekInto`, send/sendText/sendRange, borrowed `SendBuffer` gather-write through `sendVectored`, owned reusable `ReceiveBuffer` scatter-read through `receiveVectored`, UDP sendTo/receiveFrom plus caller-buffer `receiveFromInto` returning source/count/truncation metadata, allocation-free `peekFromInto`, local/remote endpoint observation, local port, live no-delay and keep-alive toggles, `Option<Duration>` linger, typed synchronous read/write timeouts, live nonblocking mutation, typed single-socket readiness polling, fallible non-consuming `tryClone` on all three owners, and the instance-owned multi-socket `Reactor` readiness foundation are implemented with direct managed lowering. `Reactor` keeps explicit owner borrows plus application keys, reuses caller-owned `ReadyEvent` storage, and issues exactly one bounded `WSAPoll`/`poll` per wait without copying handles into another ownership layer. The separate completion foundation now implements pre-effect `CompletionReactorOptions` validation plus affine `OperationSlot` ownership of the original caller buffer; fixture 1693 passes current managed Windows/Linux exact execution, while submission, dequeue, cancellation, self-host promotion, and IOCP/epoll runtime integration remain. Windows uses `ioctlsocket(FIONBIO)`, `WSAPoll`, `WSARecvFrom`, bounded one-call `WSASend`/`WSARecv`, and `WSADuplicateSocketW`/`WSASocketW`; Linux uses `fcntl(F_GETFL/F_SETFL, O_NONBLOCK)`, `poll`, `MSG_TRUNC`, bounded one-call `sendmsg(MSG_NOSIGNAL)`/`recvmsg`, and `dup`. Clones are independent affine close owners over shared kernel socket state; no wrapper or user-space reference count is added. Truncated datagrams are successful partial receipts whose count is the bytes actually stored; gather send and scatter receive preserve exact prefix counts without concatenating or copying caller payloads. The one-socket poll and vectored descriptor tables stay on the stack. Fixtures 1363-1365 and 1371-1378 prove retained peek data, policy set/query/clear, `WouldBlock`, reversible nonblocking mutation, immediate timeout, readiness, explicit UDP truncation, ordered gather/scatter segments, shared clone options, independent clone close lifetime, two keyed reactor registrations on managed Windows/Linux, no wrapper allocation, and no function-name codegen branching. A blocking-state query is intentionally absent because Windows has no authoritative equivalent and Sollang does not shadow mutable kernel state. Focused current-source self-host Reactor execution now passes on Windows/Linux with managed differential through an explicit ManagedRecovery bridge; formal SLG Stage2/Stage3 promotion and asynchronous task wakeup/completion integration remain. This bounded readiness owner is not yet an IOCP/epoll completion engine. Preserve platform error differences and do not turn shutdown into close or implicit sharing |
| P1 | QUIC listener/connection/stream lifecycle | `Listener` repeatedly accepts independent `Connection` owners; `Connection` only opens/accepts streams and datagrams; each affine uni/bidirectional stream is the receiver for send/receive/finish/abort; listener close does not invalidate accepted connections; all hot calls stay statically dispatched without wrapper allocation | The transport/lifetime split and bidirectional receiver slice are implemented. `quic.bind(local)` creates the Endpoint UDP owner; `Endpoint.listen(move Identity)` creates a reusable Listener; repeated `Listener.accept(mut Endpoint)` returns independent Connections; Listener close stops only later accepts. Endpoint owns an allocation-free scalar CID route table plus a bounded pending queue, and Connection close unregisters only its route. `BiStream.send/receive/finish` use the explicit zero-wrapper form `stream -> send(connection!, endpoint!, bytes)`. Local FIN and peer FIN update independent write/read completion state through `id`, `isWriteFinished`, and `isReadFinished`; repeated reads after peer FIN return EOF immediately. Fixture 880 proves listener-close independence and exact Connection/Endpoint cleanup; fixture 1167 proves two-Connection demultiplexing and post-Listener-close operation on Windows/Linux. Connection-local `StreamRegistry` allocates role-correct IDs monotonically, rejects limit and capacity overflow before mutation, discovers implied lower peer IDs once, and returns them in family order; fixture 1205 covers that value layer. The live application pump retains STREAM, DATAGRAM, and MAX_STREAM_DATA frames in exact-ID queues, and `acceptBi` waits for real peer activity instead of manufacturing stream zero. Fixture 1206 interleaves streams 0 and 4 in opposite send/read orders. C92/C93 now pass the normalized Windows Stage2/Stage3 fixed point. Inline `ConnectionOptions` plus role-specific `ReceiveWindowSizes` configure wire receive credit separately from local identity/frame/byte queues before network effects; no wrapper or hot-path dispatch is added. STREAM admission completes capacity, flow, and identity validation before mutation, and local exhaustion returns exact `QueueLimitExceeded`. Fixture 1209 independently proves all three budgets and post-rejection usability under managed, native Windows Stage3, and the Linux Stage2/Stage3 fixed point. QS2 is implemented. QS3 is partial: distinct RESET_STREAM/STOP_SENDING codecs and bounded exact-ID connection queues preserve application error and final-size scalars; fixture 1210 passes managed and current Windows/Linux Stage3 exact execution. `BiStream.abortSend/requestStop` and inline owner transitions now preserve the opposite direction, return exact peer errors, and validate RESET final size against stream and connection flow; fixture 1211 passes managed live two-stream execution. Windows/Linux Stage2/Stage3 and ownership-gate proof for 1211 remain before QS3 can be called implemented. Struct fields are now private by default, and intended public data fields are explicit. Typed send-only/receive-only owners follow only after unidirectional transport parameters, rather than runtime `canRead`/`canWrite` checks. A later implicit parent borrow is allowed only after the compiler proves that the parent outlives every child stream without adding allocation or indirection |
| P1 | Encoding primitives | Streaming hex and Base64 codecs over byte slices with exact error offsets and bounded-output planning | Hex plus strict Basic/URL-safe padded/raw Base64 implemented in pure Sollang; managed and self-host Windows/Linux gates retained |
| P1 | Portable memory I/O | Instance readers/writers over caller-owned buffers; partial transfer returns a count without payload allocation; exact transfer is transactional; aggregate helpers require explicit limits | `std.io.MemoryReader.readInto` and `readExactInto` fill caller-owned mutable bytes directly. Exact short reads preserve both cursor and destination, allocating `read`/`readExact` remain conveniences, and fixture 1188 passes managed Windows/Linux partial, over-limit, short, and end paths. `Reader` and `Writer` preserve an associated typed failure, while `Writer.writeRange` borrows a growable input owner and carries the exact unwritten range. Immutable `TransferPolicy` owns maximum-transfer and reusable-buffer ceilings. Its statically specialized `copy` retries partial writes without prefix copying, rejects successful zero progress, never consumes a probe byte past the limit, and returns whether source end was actually observed. Fixture 1683 covers consumer-defined imported Writer implementations, partial writes, exact limit termination, zero progress, and invalid buffer policy; managed and current-source self-host LLVM/native execution now pass with exact output and managed differential. `ReplayBuffer.readExactFrom` now validates the complete request before source access, stages only the missing prefix in reusable adapter-owned storage, preserves caller output on failure, and retains short-read progress for the next logical read without claiming source rollback. Fixture 1684 covers pre-read limit rejection, retained-prefix recovery, exact source-read bounds, logical position, and invalid progress; managed and current-source self-host LLVM/native execution pass with exact output, managed differential, and zero diagnostics. `TransferPolicy.readAll` publishes an owned aggregate only after observing end, retains its over-limit probe for a lossless larger-limit retry, and rejects insufficient replay capacity before source access; fixture 1689 covers exact-limit EOF, retained-probe recovery, zero-byte input, and capacity rejection and passes focused Windows, Linux, and browser exact execution. `TcpStream` now implements both protocols through direct caller-buffer operations with `SocketError` and `uses Network`. Affine `ByteReader` and `ByteWriter` adapters consume native file owners, retain explicit positions, use direct caller-buffer positional I/O, advance only after successful progress, preserve EOF as zero progress, and support consuming owner recovery. Reactor implementations, real asynchronous buffering, and final accumulated Stage2/Stage3 promotion remain |
| P1 | URI and authority | Parsed components, IPv6 bracket rules, percent codec, and normalization policy without implicit network access | Raw reference parser, typed authority/host/port, percent codec, explicit normalization policy, and bounded instance-based relative resolution implemented. Managed fixtures 1697/1698 pass normalization policy and all 42 RFC 3986 section 5.4 cases plus two empty-query/fragment controls. Current self-host target acceptance is blocked by the independently isolated JSON integer-context compiler defect; it remains in progress until the accumulated candidate can execute the same cases |
| P1 | JSON | Token stream plus typed reader/writer; depth/size limits before allocation; deterministic number contract | Strict token reader and instance-owned writer implemented. Reader int64/uint64 conversions validate integer lexical form and exact range without cursor mutation; boolean/nullValue also verify token kind, source bounds, and actual source bytes. Writer int64/uint64 reuse transactional number output. Reader.skipValue consumes one validated nested value without materialization, preserves the next sibling/member, and retains all input/depth/token/string limits. Managed fixtures 1036, 1041, 1707, 1710, and 1714 pass, including exact 64-bit boundaries, lexical/range errors, forged token rejection, state preservation, and bounded skipping. A common self-host integer-context repair is validated in isolation; rebuilt self-host acceptance, typed model mapping, and floating/decimal conversion policy remain |
| P2 | HTTP | Reusable `Client`/transport state owns connection pooling and policy; one `Request` yields an affine streaming `Response`; `Server` accepts explicit TCP/TLS or QUIC transport and distinguishes graceful `shutdown(deadline)` from immediate consuming `close`; body framing, timeouts, redirects, limits, decompression, and cancellation remain visible | Strict bounded HTTP/1.x heads, RFC 9112 body framing, request/response-head writing, zero-copy socket range/send-all, and a synchronous close-mode server are implemented in pure Sollang. `BodyPolicy` selects framing with explicit limits; affine `BodyDecoder` writes to caller-owned output and stops before pipelined bytes. `Request.openBody` now consumes a Request into an affine `RequestBody`; `readInto` decodes stable initial over-read bytes or at most one separate reusable transport buffer, recognizes empty-body completion before transport I/O, and consuming `finish` returns one Request that preserves already-read leftover bytes. Parsed head views never borrow the reusable receive buffer. `RequestPolicy` uses a typed target and owns Host, Content-Length, and connection framing while retaining caller body storage; `ResponsePolicy` owns ordered head bytes and response framing authority while application bodies remain caller-owned. `Server`, `Connection`, and `Request` own the listener, accepted transport, backing bytes, and parsed spans without ambient state; endpoint methods expose routing context through retained resources. Fixtures 1229, 1233, 1240, 1335, 1336, 1338, 1339, 1341, 1385, and 1386 plus reusable contract gates pass managed and focused self-host execution; fixture 1341 proves two pipelined requests are dispatched sequentially from the preserved cursor over one affine server connection. The explicit-endpoint HTTP/1.1 `Client` now owns one TCP transport, consumes itself into one outstanding `Exchange`, and returns a reusable client only after the affine `ResponseBody` is complete; fixture 1386 proves two sequential exchanges use one accepted connection without hidden DNS or protocol downgrade. The next client slices are bounded multi-origin pooling, timeout/cancellation, redirects, decompression, TLS, and HTTP/2/3 policy. The next server gaps are TLS/QUIC adapters, graceful shutdown, and response streaming. |
| P2 | DNS resolution | Separate `uses Network` resolver returning ordered candidates and typed errors; numeric parsers remain pure | Managed and self-host Windows/Linux native foundation implemented with explicit family/host/result limits, ordered deduplicated endpoints, and browser capability diagnostic |
| P2 | General algorithms | Sorting, binary search, min/max/clamp, and iterator-style transforms specialized without hidden collection materialization | In progress: `std.algorithm.Ordering` provides instance-first unstable heapsort, first-match/insertion-position binary search, and min/max/clamp under a pure associated-item `Comparison` and explicit direction. Sorting mutably borrows caller-owned growable storage; search borrows the same storage; selection retains the first equivalent value and rejects reversed clamp bounds. The implemented slice is limited to inline-copyable elements. `scripts/contracts/general-algorithms.json` and `scripts/verify-general-algorithms-focused.ps1` freeze three positive fixtures (1712, 1713, 1718), three ownership/type negative controls, 65 independently computed .NET output lines, LLVM assembly/direct-call closure, preserved owner/length/capacity, nonempty library-body inspection, and zero allocation/bulk-copy calls in the inspected algorithm bodies. Managed Windows focused checks pass 6/6; this does not establish selfhost or other-platform acceptance. Earlier native generic closure and dictionary ownership evidence remains in `artifacts/scratch/windows-completion/generic-closure-regression-native.log`, `generic-closure-symbolic-native.log`, `dictionary-closure-feedback-native.log`, `dictionary-absent-entry-order-native.log`, `dictionary-absent-final-native.log`, `scalar-borrow-transfer-native.log`, and `scalar-borrow-feedback-native.log`. Generic readonly-slice/reference integration, noncopyable permutation, remaining sequence coverage, and final platform/fixed-point verification remain pending. Do not replace the intended API with public global-function workarounds |
| P2 | Time values | `Instant`, `Duration`, wall clock, monotonic clock, formatting, and injectable clock sources kept distinct | `Duration`, `UtcInstant`, effectful `MonotonicClock`/`WallClock`, and deterministic mutable manual clocks are implemented. `MonotonicInstant` now carries an unforgeable module-owned source identity; system source zero and explicit nonzero manual sources reject cross-clock comparison with `DifferentClock`. Source-bound checked `Deadline.remaining/isDue`, pure `FixedClock`, and overflow-checked signed `OffsetClock` are implemented. `ClockCapabilities` now exposes millisecond resolution, maximum delay, and typed suspend behavior; Windows reports include-suspend, Linux reports exclude-suspend, and browser builds report unspecified. Fixture 1694 passes current managed and self-host Windows/Linux execution plus browser compilation, completing T1/T2/T3/T5. T4 now has an affine owner-returning `Timer.wait` built on the real Task timer queue, explicit Burst/Skip/Delay policies, consuming idle cancel/close, managed Windows/Linux exact execution, and an explicit browser diagnostic; self-host structured-async parity remains before T4 can complete. Pure UtcInstant.formatRfc3339 writes exactly 24 bytes into caller-owned storage for Gregorian years 0001..9999, rejects range/short-buffer errors before mutation, and performs no internal allocation or locale/clock lookup. Fixture 1711 passes managed execution and seven independent .NET calendar comparisons, with boundary/short-buffer controls and zero formatter allocation calls; self-host/platform acceptance remains. T6 network/process deadline consumers and a shared effect-aware source trait remain. Legacy `sys.time` and its global aliases stay removed |
| P2 | UUID values | RFC 9562 16-octet network-order value; strict 8-4-4-4-12 hex parser, canonical lowercase formatter, version/variant inspection, Nil/Max values, and explicit random or time-ordered construction | Pure `Codec`/`Uuid` value foundation plus instance-owned `Generator` v4/v7 implemented with explicit secure entropy and wall clock; deterministic `Codec.v4(entropy)` and `Codec.v7(instant, entropy)` validate exact source lengths without ambient effects; explicit `Codec.parseBraced` and case-insensitive `Codec.parseUrn` preserve source-relative error offsets without weakening strict `parse`; fixture 1091 passes managed and current Stage2-native `llvm-as`/O0 exact execution plus Stage3 public-stdlib parity |
| P2 | Async task observability | Inspect owned task trees, suspension sites, cancellation, and permanently blocked tasks without changing scheduling semantics | Compiler suspension/cancel metadata exists, but runtime task identity and parent/blocked state do not; begin with an explicitly enabled `DiagnosticSession` instance owning stable task IDs and snapshots, require production-off overhead measurement, and do not add an ambient mutable registry |
| P2 | Child processes | `sys.process.Command` owns literal executable/argv, environment, directory, and typed `Stdio`; `spawn(move self)` returns an affine `Child`; `wait`, `tryWait`, `kill`, and bounded `collect` expose status, signal, timeout, truncation, and simultaneous stdout/stderr draining; no implicit shell | The owned lifecycle, child-only working directory, instance environment configuration, and directional stdio policy are implemented: `process.command(program)` creates the instance; `arg`/`args`, `workingDirectory`, `setEnvironment`, `removeEnvironment`, and `clearEnvironment` configure it; stdin supports inherit/file/null and stdout/stderr support inherit/file/null without changing parent descriptors. `spawn(move)` returns `Child`; `Child.id` is a zero-wrapper captured `ProcessId`; `wait(move)` reaps to typed `ExitStatus`; scope drop kills then reaps. `Command.collect(CaptureLimits)` overrides stdout/stderr with private pipes, drains both concurrently, retains each stream only to its explicit byte ceiling, and reports independent truncation even at zero limits. Environment inheritance stays explicit, and unchanged inheritance takes the zero-copy parent path. Legacy `run`/`runToFile` route through the same configured primitives. Managed and current Windows self-host fixtures 87, 1132-1133, 1160-1163, and 1179-1183 prove argv, launch failure, explicit wait/drop, directory/environment isolation, file/null stdio, bounded concurrent capture, zero-limit draining, ABI parity, and natural multiline source; Linux fixed-point proof for the newest stdio/capture slice is pending. Executable lookup must not silently reinterpret a relative program against the child directory. Public pipe endpoints remain withheld until `Child` can own their lifetime and backpressure explicitly. `Child.tryWait(mut)` performs one nonblocking native poll and caches terminal status; repeated polls, a later consuming wait, and final drop never reap or close twice. `Child.kill(mut)` now requests `TerminateProcess` or `SIGKILL` without consuming or reaping the owner; cached terminal state is an idempotent no-op, and only `tryWait`/`wait` observes and reaps termination. Child token/completion fields are private. Managed public Windows fixture 1737 proves live forced termination, retained-owner wait, and cached no-op behavior; fixture 1716, Windows exit-code259 fixture 1717, privacy negatives, and extracted platform-runtime/boundary probes cover nonblocking observation. Linux and current selfhost kill execution remain focused promotion gates. Wait/I/O timeout, richer signal/forced status, and public pipe handles remain; retain a separately named opt-in shell command only if later justified |
| P2 | GZIP/DEFLATE compression | Checksummed instance codec first; reusable streaming encoder/decoder next; explicit input, output, ratio, member, checksum, and malformed-input limits | Deterministic level-0 and fixed-Huffman/LZ77 writers, stored/fixed/dynamic reader, transactional stored-block streaming Encoder, and an affine incremental Decoder are implemented in pure Sollang. `DecoderLimits` makes compressed-input and member count ceilings explicit. Each write advances header, bit reservoir, Huffman, LZ history, CRC32/ISIZE, and member state without retaining or reparsing complete compressed input; consuming finish transfers only the fully verified aggregate. Fixture 1214 covers concatenation, one-shot/streaming parity, and failure transactionality. Routing complete one-shot input through the byte-resumable Decoder was measured at a 24.7% median regression, so the bulk path remains until a shared core proves parity without performance loss. Fixture 1215 delivers stored, fixed, dynamic, and concatenated streams one byte per write; managed proof passes and the formal Windows/Linux self-host gate retains it. A dynamic writer remains afterward |
| P2 | Binary and checksum codecs | Immutable `ByteOrder` creates bounded cursor/writer instances; exact-offset integer and ten-byte canonical varint errors; immutable CRC policy creates reusable mutable hashers over caller-visible buffers | Pure Sollang `ByteOrder` Reader/Writer and IEEE/Castagnoli `Polynomial`/Hasher implemented without public globals; managed fixtures 1085-1087 pass and the native O0/O2 exact-output gate is integrated; fixture 1087 constructs fixed input inside a loop and requires function-entry-hoisted stack storage plus no heap owner or indirect dispatch across the complete statically reachable O0 call graph; ordinary direct method symbols remain valid because instance structure must not depend on optimizer inlining; fixture 1090 proves the fixed-Huffman GZIP trailer and public IEEE Hasher agree under managed and current Stage2-native execution; fixed-point execution and Linux remain; remove GZIP's duplicate private CRC only after throughput parity; needed before ZIP, framed protocols, and portable persistence |
| P2 | Text data and paths | CSV records, path component operations, globbing, and regex/search contracts with bounded work and no implicit filesystem access | All eleven natural `sys.path.Path` operations, including effectful `queryRaw`, are zero-wrapper instance methods; their host ABI plus target `nativeStyle` live in `sys/runtime/path.slg`. Only `fromText` construction and target-style selection remain global. `std.text.csv` has an instance-owned bounded UTF-8 field reader with explicit CRLF/LF policy, source/record/column/decoded-byte limits, caller-buffer decoding, exact offsets, and per-field retry transactionality. Fixture 1721 executes 105 lines covering quoting, UTF-8, empty fields, all 13 reader failure kinds, and storage preservation; four shared-format cases match 20 independently parsed .NET output lines. Focused Windows reader verification passes 8/8 including both reachable ownership negatives after the common SourceText-return origin fix. `Format.writer` creates a bounded transactional record writer over caller-owned output: explicit CRLF/LF, minimal quoting and doubled quotes, cumulative encoded-byte/record budgets, decoded field limits, exact short-buffer retry, private counters, and no hidden allocation or I/O. Fixture 1724 produces 41 lines; Windows focused verification passes 11/11 including seven independent encoding/parser roundtrips, ten error kinds, LLVM allocation/closure checks, and both privacy/alias negatives before LLVM. Verified output and published golden bytes have identical hashes. Exact managed Linux reader/writer execution passes 2/2. `std.path.Components` adds a bounded lexical iterator over borrowed UTF-8 with one existing Style identity, root/drive/UNC and dot/dot-dot metadata, explicit prefix and resource limits, transactional errors, and no normalization, source copy or filesystem access. Fixture 1726 passes Windows focused9/9 and Linux exact1/1 with 59 reference-checked lines, whole-module structural no-allocation, reachable source-escape rejection, and official golden byte equality. `std.text.glob.Pattern` provides allocation-free bounded whole-text matching with Unicode-scalar `*`/`?` and explicit escapes; fixture 1728 passes Windows10/10 and Linux1/1. `std.text.regex.Pattern` adds an allocation-free caller-scratch two-bank NFA for the declared bounded profile; fixture 1729 matches 41 independent Go leftmost-longest cases plus 43 boundary observations, Windows10/10 and Linux1/1. The owned Path migration is not complete. Selfhost closure and the remaining text/path capabilities are pending. Move the portable value vocabulary to `std.path` with its existing file/directory consumers and compiler type identity, leaving irreducible host primitives in `sys`; keep `normalizeConfined` distinct from symlink-aware canonicalization and reject regex resource exhaustion by construction |
| P2 | Structured logging | Logger instance with typed level/fields and explicit sink; no ambient mutable global logger | Complete: `std.log.Logger` owns immutable minimum-level policy and produces `Option<Record>` before field construction; `None` performs zero sink calls. The caller supplies structured fields and invokes a statically dispatched concrete `Sink`, whose typed `std.log.Error` is preserved without fallback. Fixture 1696 proves filtered-call count, accepted fields, and sink failure under managed and self-host Windows/Linux execution; browser compilation passes. No ambient registry, default sink, hidden formatting, or destination effect exists |
| P3 | Archives/modern compression | Streaming ZIP, RFC 7932 Brotli, and RFC 8878 Zstandard. Brotli and Zstandard use explicit immutable codec options plus affine encoder/decoder instances over caller-owned buffers or `std.io` streams; output, expansion ratio, window, frame/member count, trailing data, memory, and work limits are mandatory. Zstandard dictionary identity/training and multi-frame policy remain explicit rather than ambient. RFC 9841 shared dictionaries, large-window Brotli, and its framing container are a distinct later slice | The pure Sollang Zstandard foundation has a deterministic single-segment raw-block writer, affine incremental raw/RLE decoder, bounded frames, and optional checksums. The pure Sollang Brotli foundation adds a raw writer and affine incremental raw/metadata Decoder with transactional finish. The compressed path now has one bounded canonical prefix lookup, the complete simple/complex prefix-description parser, bounded context maps, aggregate-bounded tree groups, complete compressed-header composition, exact allocation-free literal context modes, block switching, and bounded one-shot command/literal/distance execution: up to 704 symbols, 15 bits, 1,080 entries per table, 16,384 context entries, 256 trees, 520 distance symbols, zero-RLE, inverse move-to-front, and short/direct/postfix distances, with no retained encoded input or per-symbol allocation. Prefix descriptions, context maps, consecutive tree groups, command/literal/distance execution, and the full block/context/tree header now resume across caller byte boundaries through affine instances and the shared bounded scalar window; malformed simple symbols are rejected instead of modulo-normalized. The exact RFC static dictionary is packed into 15,348 immutable `UInt64` module-data words and all 121 transforms resolve through an instance without runtime dictionary reconstruction or distance-ring mutation. Fixtures 1220, 1228, 1245-1252, 1265/1266/1268, and 1269-1279 pass focused managed execution; the independently produced .NET vector decodes to exactly 100 lowercase `a` bytes in bulk, split command, and public bytewise Decoder paths, while fixture 1272 forces command/literal/distance block switches one bit at a time and resolves `time` from the static dictionary. `HeaderReader`, `ContextReader`, and `TreeReader` reuse their bounded child owners through explicit consuming handoffs and reset without input retention, wrapper allocation, or table copying. `compressed_stream.Reader` composes those owners and the command reader through the public Decoder, transfers verified history without a completed-output copy, and keeps truncated caller output transactional. Zstandard entropy blocks/dictionaries, RFC 9841, formal fixed-point closure, and ZIP remain. Do not route them through file globals or an unbounded allocating convenience |

P2 text data and paths status refinement: `std.text.glob.Pattern` now provides
a pure, bounded, case-sensitive whole-text wildcard matcher over borrowed UTF-8.
The public factory validates limits and escapes; the instance method matches
Unicode scalars with constant auxiliary storage and no hidden filesystem work.
Fixture 1728 covers 29 independently compared match cases and 27 exact limit,
offset, reuse, and ownership lines. Focused managed Windows checks pass 10/10,
including official golden-byte equality, no-allocation reachability, private
state, and source-escape rejection; the same fixture passes Linux exact 1/1.
The bounded regex/search policy is now implemented by `std.text.regex.Pattern`:
41 independent Go leftmost-longest cases and 43 exact limit, scratch, ownership,
and diagnostic observations pass Windows 10/10 and Linux 1/1 without reachable
allocation. Owned Path migration, selfhost closure, and accumulated Stage2/Stage3
promotion remain pending, so the combined row is still in progress.

P1 portable memory I/O status refinement: the shared `Reader` and `Writer`
protocols now expose one caller-buffer partial primitive with exact progress
and an associated failure type; `MemoryReader` and `MemoryWriter`
implement them without removing or changing their inherent APIs. Fixtures 1094,
1188, and 1680 separately retain
concrete compatibility, transactional caller-buffer reads, and qualified
imported static dispatch. The contract remains in progress: consumer-defined
cross-module generic adapters, bounded replay, read-all/copy policy, and socket
and file adapters are implemented. The affine file adapters own native handles
and explicit positions, perform direct caller-buffer positional I/O, validate
write ranges before effects, preserve EOF as zero progress, and support
consuming owner recovery. Bounded transactional read-all now retains one
over-limit probe in `ReplayBuffer` and publishes only after observed end.
Reactor adapters and asynchronous buffering still require implementation. The
implemented portable protocols and their compiler trait
shape have completed the authoritative 359-fixture native-exact plan and
authenticated fixed points under Windows and Linux Stage2/Stage3; this promotion
does not complete the remaining adapters.

P3 Zstandard status refinement: the older table wording that leaves all
Zstandard entropy blocks pending is superseded. The pure Sollang decoder now
supports direct-weight and treeless Huffman literals plus predefined, RLE,
FSE-compressed, and same-frame repeat sequence tables. Variable sequence
counts, LL/OF/ML reverse interleaving, extra bits, frame-local repeat offsets,
overlap copies, transactional table replacement, and exact bit completion are
covered by fixtures 1310-1313, including independent `zstd` predefined and
compressed-FSE vectors. FSE-compressed Huffman weights and dictionaries remain.

P3 Brotli status refinement: fixtures 1275, 1277, 1278, and 1279 pass focused
managed native execution. `HeaderReader` composes exactly three affine
`BlockStreamReader` owners, `ContextReader` reuses one context-map owner for
literal and distance maps, and `TreeReader` reuses one tree-group owner for all
three alphabets. The independent vector advances one bit at a time through the
complete header and finishes the trees at byte 6 bit 5 without retaining caller
input. `compressed_stream.Reader` now carries this complete chain through the
existing resumable command reader inside public `Decoder.write`; only consuming
finish transfers verified output. Complete block/context/tree header
composition and main Decoder integration are no longer pending.

The QUIC identity slice also replaces the current client-opens/server-accepts
shortcut. `Connection` retains both peer `bidi_local` and `bidi_remote` byte
allowances plus the corresponding local receive allowances, selecting them by
the stream ID's initiator rather than by connection construction role.
`acceptBi` waits for a real peer STREAM frame, queues every implicitly opened
identity in sequence order, and preserves frames under their exact stream ID
within explicit count and byte limits. Identity queuing is not a claim of
out-of-order offset reassembly; that remains a separate bounded transport
contract.

## Async socket promotion contract

The readiness `Reactor` is the synchronous multi-socket foundation, not the
terminal async abstraction. Promote it only through the following ordered
contract; do not add an `async` spelling that blocks a worker thread or allocates
one hidden object per operation.

1. A bounded reactor configuration fixes registration, pending-operation, and
   completion-batch capacities before network effects. Capacity exhaustion is a
   typed error and cannot grow a hidden queue.
2. A reusable affine operation slot owns its application key, direction,
   buffer storage or exact borrow, native operation identity, and
   `Vacant/Pending/Completed/Cancelled` transition. Submitting a pending slot or
   reclaiming it twice is rejected before native I/O.
3. Submission reports synchronous completion directly. Only a genuinely
   pending operation records the async task wake target; wakeup schedules the
   task and never performs application I/O inside the native callback.
4. Completion returns the exact transferred count, terminal socket error, and
   original operation slot. Cancellation has one observable terminal result,
   preserves the buffer owner, and races with completion through one atomic
   winner rather than a silent success fallback.
5. Windows may use IOCP and batched completion dequeue. Linux may begin with
   bounded `epoll` readiness plus nonblocking I/O, but must acknowledge only a
   direction that actually reached `WouldBlock`; an io_uring specialization is
   acceptable only behind the same observable contract and an explicit target
   capability. Browser raw sockets remain an actionable unsupported-target
   diagnostic.
6. Acceptance requires zero steady-state operation allocation after capacity
   setup, no buffer copy, bounded native stack/ring storage, synchronous and
   pending completion fixtures, cancellation race fixtures, false-readiness and
   partial-I/O fixtures, managed/self-host Windows/Linux differential execution,
   and a measured throughput/peak-memory comparison before replacing the
   current `WSAPoll`/`poll` readiness path.

## Zero-cost resource encapsulation prerequisite

Native socket tokens already use a compiler-owned opaque-handle rule, but pure
Sollang affine resources such as `quic.BiStream` are ordinary public structs and
their representation is therefore still source-visible. Do not solve that gap
with a heap object, parent pointer, dynamic dispatch, or a QUIC-specific name
check. The language/compiler follow-up must provide one general nominal contract
with all of these properties:

- outside the defining module, construction and field access are rejected with
  a diagnostic that points to the public factory or instance method;
- a private helper type must not be a visibility substitute: inferred chains
  such as `value.state.secret` are a required negative fixture even when the
  caller never spells the private type name;
- the defining module and its split source fragments retain direct field access;
- inherent public methods remain statically resolved and keep the exact current
  value layout, drop behavior, and ABI;
- ownership analysis remains independent from visibility and distinguishes an
  affine resource from a copyable value; and
- managed, self-host, browser, debug metadata, public ABI, and Stage2/Stage3
  parity use the same visibility decision.

The selected language contract is field-level visibility: fields are private by
default and an explicit field `public` marker exports intentional data surfaces.
The repository migration makes formerly public fields explicit before enabling
the default, so the change does not silently reinterpret existing stdlib data
contracts. An optional `opaque` safety mode is rejected because correctness must
not depend on each developer remembering to opt in.

Compiler follow-up exposed by the time foundation: the managed backend stores a
propagated `Err` in the async Task result slot and completes the internal `i1`
readiness worker through its Boolean ABI. Fixture 1691 executes both the
successful and propagated-error paths. The current-source self-host LLVM
candidate now owns the first structured scheduler/timer slice: fixture 1066
executes a zero-parameter async function, returns an affine Task from the exact
`std.time.Duration.sleep` intrinsic, and consumes it through `await` without a
blocking compatibility shim. The focused gate passes 11/11 with native exact
execution, LLVM assembly, and direct-call closure. This is not broad async
parity: parameters and captures, multiple suspension states, typed spill/resume,
fallible completion, cancellation ownership, Windows/Linux differential
execution, and accumulated Stage2/Stage3 promotion remain. Fixture 1062 protects
the self-host value and instance-resolution foundation. A blocking sleep shim
remains forbidden.
`std.time` is the single public time API. Direct `sys.runtime` clock primitives
remain internal implementation boundaries only; the former compatibility
surface and global aliases are removed. Negative legacy durations are not
carried into the validated `std.time.Duration` contract.

## Acceptance gate for every item

1. Fix the public types, ownership, errors, effects, limits, and target matrix
   before implementation.
2. Put protocol/data logic in reachable pure Sollang modules; keep only the
   irreducible OS operation intrinsic.
3. Reject malformed or oversized input before expensive allocation, native
   linking, or network activity.
4. Retain positive, boundary, malformed, ownership, and unavailable-target
   fixtures. Verify managed and self-host compilers plus Windows/Linux native
   execution; add browser execution or an explicit capability diagnostic.
5. Update this backlog, the specification, the Agent guide, user examples, and
   the global Stage 3 installation when the shipped surface changes.
6. Prefer inherent methods whenever a natural receiver exists. Prove API
   migrations are zero-cost at O0 and O2; do not rely on optimizer inlining to
   erase an avoidable compatibility wrapper.
7. Run `scripts/verify-stdlib-instance-policy.ps1`; any new top-level
   `stdlib/std` function requires an explicit factory, parser, or flow-adapter
   classification, and stale global entries are rejected after migration.
