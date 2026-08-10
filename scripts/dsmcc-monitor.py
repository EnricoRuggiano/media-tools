#!/usr/bin/env python3

import sys
import subprocess
import base64
import re

HEX_RE = re.compile(r'\b[0-9A-Fa-f]{2}\b')

BASE64_CHARS = set(
    b"ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    b"abcdefghijklmnopqrstuvwxyz"
    b"0123456789+/="
)


def parse_ts_dump_line(line)-> bytes:
    if "* dump:" not in line:
        raise Exception("Invalid tsduck output")
    parts    = line.split(",")
    hex_part = parts[-1].strip()
    return bytes.fromhex(hex_part)


def extract_ts_payload(packet):

    if len(packet) < 188:
        raise Exception(f"Packet has size {len(packet)} instead of 188")

    # TS header
    pusi = (packet[1] & 0x40) != 0
    if not pusi:
        return None

    payload_offset = 4

    afc = (packet[3] >> 4) & 0x3
    if afc == 2:
        return None
    if afc == 3:
        afl = packet[4]
        payload_offset += 1 + afl

    if payload_offset >= len(packet):
        return None
    return packet[payload_offset:]


def extract_dsmcc_section(packet):

    payload = extract_ts_payload(packet)

    if not payload:
        return None

    pointer_field = payload[0]

    section = payload[1 + pointer_field:]

    if len(section) < 8:
        return None

    if section[0] != 0x3D:
        return None

    section_length = (
        ((section[1] & 0x0F) << 8)
        | section[2]
    )

    total_length = 3 + section_length

    if total_length > len(section):
        return None

    return section[:total_length]


def parse_section(section):

    table_id = section[0]

    section_length = (
        ((section[1] & 0x0F) << 8)
        | section[2]
    )

    event_id = (
        (section[3] << 8)
        | section[4]
    )

    version_byte = section[5]

    version = (version_byte >> 1) & 0x1F

    section_number = section[6]
    last_section_number = section[7]

    body = section[8:-4]

    crc = section[-4:]

    return {
        "table_id": table_id,
        "section_length": section_length,
        "event_id": event_id,
        "version": version,
        "section_number": section_number,
        "last_section_number": last_section_number,
        "body": body,
        "crc": crc,
    }


def locate_base64(body):

    #
    # Find first AQEA marker
    #
    marker = b"AQEA"

    pos = body.find(marker)

    if pos < 0:
        return None

    end = pos

    while end < len(body):
        if body[end] not in BASE64_CHARS:
            break
        end += 1

    return pos, body[pos:end]


def decode_scte35(b64_bytes):

    try:
        payload = base64.b64decode(b64_bytes)

        # Remove DSM-CC header/padding: 01 01 00 00
        padding = bytes.fromhex("01010000")

        if payload.startswith(padding):
            payload = payload[len(padding):]
    except Exception:
        return None

    return payload


def print_event(section_info):

    body = section_info["body"]

    located = locate_base64(body)

    if not located:
        return

    base64_offset, b64 = located


    scte35 = decode_scte35(b64)

    print("=" * 80)

    print(f"table_id           : 0x{section_info['table_id']:02X}")
    print(f"section_length     : {section_info['section_length']}")
    print(f"event_id           : {section_info['event_id']}")
    print(f"version            : {section_info['version']}")
    print(f"section_number     : {section_info['section_number']}")
    print(f"last_section_number: {section_info['last_section_number']}")

    print()

    print(f"body_length        : {len(body)}")
    print(f"base64_offset      : {base64_offset}")
    print(f"base64_length      : {len(b64)}")

    print()

    print("base64_payload:")
    print(b64.decode())

    print()

    if scte35:

        print(f"scte35_length      : {len(scte35)}")

        print("scte35_hex:")
        print(scte35.hex())    

        if scte35[0] != 0xFC:
            print()
            print(
                "*** WARNING: decoded SCTE35 "
                "does not start with 0xFC ***"
            )

    print()

    print("crc32:")
    print(section_info["crc"].hex())

    print("=" * 80)
    print()


def main():

    if len(sys.argv) != 3:
        print(
            f"Usage: {sys.argv[0]} <ip:port> <pid>",
            file=sys.stderr,
        )
        sys.exit(1)

    source = sys.argv[1]
    pid = sys.argv[2]

    cmd = [
        "tsp",
        "-I", "srt", source,
        "-P", "dump",
        "--pid", pid,
        "--log",
        "-O", "drop"
    ]

    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1
    )

    try:
        for line in proc.stdout:
            print(f"Tsduck captured output: {line}")
            packet = parse_ts_dump_line(line)
            section = extract_dsmcc_section(packet)
            key = section.hex()
            info = parse_section(section)
            print_event(info)


    except KeyboardInterrupt:
        pass

    finally:
        proc.terminate()


if __name__ == "__main__":
    main()