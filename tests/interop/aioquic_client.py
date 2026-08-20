import argparse
import asyncio
import json
import ssl
import sys

from aioquic.asyncio.client import connect
from aioquic.asyncio.protocol import QuicConnectionProtocol
from aioquic.quic.configuration import QuicConfiguration
from aioquic.quic.events import ConnectionTerminated, HandshakeCompleted
from aioquic.quic.logger import QuicLogger
from aioquic.quic.packet import QuicProtocolVersion


class LoggingProtocol(QuicConnectionProtocol):
    def quic_event_received(self, event) -> None:
        if isinstance(event, HandshakeCompleted):
            print("event=handshake-completed", file=sys.stderr, flush=True)
        elif isinstance(event, ConnectionTerminated):
            print(
                f"event=connection-terminated,error={event.error_code},"
                f"frame={event.frame_type},reason={event.reason_phrase}",
                file=sys.stderr,
                flush=True,
            )
        super().quic_event_received(event)


async def roundtrip(
    host: str,
    port: int,
    version: int,
    qlog: str | None,
    split_fin: bool,
) -> None:
    quic_logger = QuicLogger()
    configuration = QuicConfiguration(
        alpn_protocols=["h3"],
        is_client=True,
        verify_mode=ssl.CERT_NONE,
        quic_logger=quic_logger,
    )
    configuration.supported_versions = [QuicProtocolVersion(version)]
    try:
        async with connect(
            host,
            port,
            configuration=configuration,
            create_protocol=LoggingProtocol,
            wait_connected=True,
        ) as protocol:
            reader, writer = await protocol.create_stream()
            writer.write(b"ping")
            if not split_fin:
                writer.write_eof()
            await writer.drain()
            response = await asyncio.wait_for(reader.read(), timeout=5)
            if response != b"pong":
                raise RuntimeError(f"unexpected response: {response!r}")
            if split_fin:
                writer.write_eof()
                await writer.drain()
            print(f"aioquic={version},{response.decode('ascii')}")
    finally:
        if qlog is not None:
            with open(qlog, "w", encoding="utf-8") as output:
                json.dump(quic_logger.to_dict(), output)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=44_433)
    parser.add_argument("--version", type=lambda value: int(value, 0), default=1)
    parser.add_argument("--qlog")
    parser.add_argument("--split-fin", action="store_true")
    args = parser.parse_args()
    asyncio.run(asyncio.wait_for(
        roundtrip(args.host, args.port, args.version, args.qlog, args.split_fin),
        timeout=15,
    ))


if __name__ == "__main__":
    main()
