#!/usr/bin/env python3
"""Read-only targeted Objective-C inventory for 64-bit Apple Mach-O images."""
import argparse
import hashlib
import json
import mmap
import pathlib
import re
import struct
import sys

MASK = 0x0000FFFFFFFFFFFF


def u32(data, off):
    return struct.unpack_from("<I", data, off)[0]


def u64(data, off):
    return struct.unpack_from("<Q", data, off)[0] & MASK


def cstr(data, off, limit=4096):
    end = data.find(b"\0", off, min(len(data), off + limit))
    if end < 0:
        return ""
    return data[off:end].decode("utf-8", "replace")


def inspect(path, patterns, max_methods):
    path = path.resolve()
    digest = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(8 * 1024 * 1024), b""):
            digest.update(chunk)
    with path.open("rb") as f, mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ) as data:
        if data[:4] != bytes.fromhex("cffaedfe"):
            raise ValueError("Expected little-endian 64-bit Mach-O (arm64/arm64e).")
        cpu, subtype, filetype, ncmds, sizeofcmds = struct.unpack_from("<IIIII", data, 4)
        segments, sections, encryption, uuid = [], [], None, None
        pos = 32
        for _ in range(ncmds):
            cmd, size = struct.unpack_from("<II", data, pos)
            raw = data[pos:pos + size]
            if cmd == 0x19:
                segname = raw[8:24].split(b"\0", 1)[0].decode("ascii", "replace")
                vmaddr, vmsize, fileoff, filesize = struct.unpack_from("<QQQQ", raw, 24)
                segments.append((vmaddr, filesize, fileoff))
                count = u32(raw, 64)
                for i in range(count):
                    off = 72 + i * 80
                    name = raw[off:off + 16].split(b"\0", 1)[0].decode("ascii", "replace")
                    addr, length = struct.unpack_from("<QQ", raw, off + 32)
                    file_offset = u32(raw, off + 48)
                    sections.append((name, addr, length, file_offset, segname))
            elif cmd in (0x21, 0x2C):
                encryption = {
                    "command": hex(cmd),
                    "cryptid": u32(raw, 16),
                    "cryptoff": u32(raw, 8),
                    "cryptsize": u32(raw, 12),
                }
            elif cmd == 0x1B:
                uuid = bytes(raw[8:24]).hex()
            pos += size

        def offset(va):
            va &= MASK
            for start, file_size, file_off in segments:
                if start <= va < start + file_size:
                    return file_off + va - start
            raise ValueError(f"Unmapped VA {va:#x}")

        def string_at_va(va):
            try:
                return cstr(data, offset(va))
            except (ValueError, IndexError):
                return ""

        def methods_for(method_ptr):
            if not method_ptr:
                return []
            try:
                base = offset(method_ptr)
                flags = u32(data, base)
                count = u32(data, base + 4)
                stride = flags & 0xFFFF
                relative = bool(flags & 0x80000000)
                direct = bool(flags & 0x40000000)
                if stride < (12 if relative else 24) or count > 20000:
                    return []
                result = []
                for i in range(min(count, max_methods)):
                    entry_va = method_ptr + 8 + i * stride
                    entry = offset(entry_va)
                    if relative:
                        name_delta, type_delta, imp_delta = struct.unpack_from("<iii", data, entry)
                        name_va = entry_va + name_delta
                        if not direct:
                            name_va = u64(data, offset(name_va))
                        # Each signed relative pointer is based at its own field.
                        type_va = entry_va + 4 + type_delta
                        encoding = string_at_va(type_va)
                        selector = string_at_va(name_va)
                    else:
                        name_ptr, type_ptr, imp = struct.unpack_from("<QQQ", data, entry)
                        selector = string_at_va(name_ptr)
                        encoding = string_at_va(type_ptr)
                    if selector:
                        result.append({"selector": selector, "encoding": encoding})
                return result
            except (ValueError, struct.error, IndexError):
                return []

        class_section = next((s for s in sections if s[0] == "__objc_classlist"), None)
        if not class_section:
            raise ValueError("Mach-O has no __objc_classlist section.")
        _, _, class_size, class_fileoff, _ = class_section
        compiled = [re.compile(p, re.I) for p in patterns]
        found = []
        for off in range(class_fileoff, class_fileoff + class_size, 8):
            try:
                class_va = u64(data, off)
                class_off = offset(class_va)
                data_bits = u64(data, class_off + 32)
                ro = offset(data_bits & ~7)
                name = string_at_va(u64(data, ro + 24))
                if not name or not any(p.search(name) for p in compiled):
                    continue
                instance_methods = methods_for(u64(data, ro + 32))
                isa = u64(data, class_off)
                class_methods = []
                if isa:
                    meta_off = offset(isa)
                    meta_ro = offset(u64(data, meta_off + 32) & ~7)
                    class_methods = methods_for(u64(data, meta_ro + 32))
                found.append({
                    "class": name,
                    "class_va": hex(class_va),
                    "instance_methods": instance_methods,
                    "class_methods": class_methods,
                })
            except (ValueError, struct.error, IndexError):
                continue

        return {
            "file": str(path),
            "size_bytes": path.stat().st_size,
            "sha256": digest.hexdigest(),
            "cpu_type": hex(cpu),
            "cpu_subtype": hex(subtype),
            "file_type": filetype,
            "uuid": uuid,
            "encryption": encryption,
            "class_count_scanned": class_size // 8,
            "matching_class_count": len(found),
            "classes": found,
        }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mach_o", type=pathlib.Path)
    parser.add_argument("--pattern", action="append", default=[])
    parser.add_argument("--max-methods", type=int, default=250)
    parser.add_argument("--output", type=pathlib.Path)
    args = parser.parse_args()
    patterns = args.pattern or [
        r"IG.*(Feature|MobileConfig|Experiment|Privacy|Follower|Following|AccountSettings|InternalSettings)",
        r"(MobileConfig|Experiment|Privacy|Employee|Follower|Following|AccountFeature)",
    ]
    report = inspect(args.mach_o, patterns, args.max_methods)
    rendered = json.dumps(report, ensure_ascii=False, indent=2)
    if args.output:
        args.output.write_text(rendered + "\n", encoding="utf-8")
        print(json.dumps({k: report[k] for k in ("file", "size_bytes", "sha256", "uuid", "encryption", "class_count_scanned", "matching_class_count")}, indent=2))
    else:
        print(rendered)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(2)
