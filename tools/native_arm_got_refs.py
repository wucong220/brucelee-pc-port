#!/usr/bin/env python3
"""Find candidate ARM-state PIC register-index loads of an ELF virtual GOT slot."""
from __future__ import annotations
import argparse
import hashlib
import json
import struct
import sys
from pathlib import Path

try:
    from capstone import Cs, CS_ARCH_ARM, CS_MODE_ARM, CS_MODE_LITTLE_ENDIAN
    from capstone.arm import (ARM_CC_AL, ARM_CC_INVALID, ARM_OP_IMM, ARM_OP_MEM,
                              ARM_OP_REG, ARM_REG_PC, ARM_SFT_INVALID,
                              ARM_REG_R0, ARM_REG_R1, ARM_REG_R2, ARM_REG_R3, ARM_REG_R12, ARM_REG_LR)
except ImportError:
    if __name__ == '__main__':
        print('error: Python capstone is required (tested with capstone 5.0.7)', file=sys.stderr)
        raise SystemExit(1)
    raise
from native_hierarchy_links import HierarchyLinkError, file_offset

MASK = 0xffffffff


def scan(code: bytes, start: int, read_word, target: int, window: int = 512):
    """Track ARM constants with heuristic forward-branch state propagation.

    Values expire after window bytes. Branch merging is approximate; predication,
    memory writes, and Thumb execution are not modeled. Hits are candidates.
    """
    md = Cs(CS_ARCH_ARM, CS_MODE_ARM | CS_MODE_LITTLE_ENDIAN)
    md.detail = True
    md.skipdata = True
    regs = {}
    results = []
    pending = {}
    for ins in md.disasm(code, start):
        if ins.id == 0:
            regs.clear()
            continue
        addr = ins.address
        # Heuristic union: keep fallthrough values when both paths have one.
        # This may mix paths, so a hit requires independent control-flow review.
        if addr in pending:
            for incoming in pending.pop(addr):
                regs = {**incoming, **regs}
        regs = {r: v for r, v in regs.items() if addr - min(item[0] for item in v[2]) <= window}
        ops = ins.operands
        unconditional = ins.cc in (ARM_CC_AL, ARM_CC_INVALID)
        mnemonic = ins.mnemonic
        # AAPCS calls preserve r4-r11; linear conditional branches follow only
        # fallthrough and do not merge the taken path. Results remain candidates.
        if ins.group(2):
            for reg in (ARM_REG_R0, ARM_REG_R1, ARM_REG_R2, ARM_REG_R3, ARM_REG_R12, ARM_REG_LR):
                regs.pop(reg, None)
            continue
        if ins.group(1) or ins.group(3):
            if not unconditional and len(ops) == 1 and ops[0].type == ARM_OP_IMM and ops[0].imm > addr:
                pending.setdefault(ops[0].imm, []).append(regs.copy())
            else:
                regs.clear()
            continue
        produced = None
        hit = None
        if unconditional and mnemonic == 'ldr' and len(ops) == 2 and ops[0].type == ARM_OP_REG and ops[1].type == ARM_OP_MEM:
            mem = ops[1].mem
            if mem.base == ARM_REG_PC and mem.index == 0 and not ins.writeback:
                literal = (addr + 8 + mem.disp) & MASK
                try:
                    value = read_word(literal)
                    produced = (ops[0].reg, value, [(addr, ins.mnemonic + ' ' + ins.op_str, literal, value)])
                except (ValueError, struct.error, IndexError):
                    pass
            elif mem.index and mem.base in regs and mem.index in regs and not ins.writeback and ops[1].shift.type == ARM_SFT_INVALID:
                base, index = regs[mem.base], regs[mem.index]
                # subtracted register-index forms have a negative sign.
                sign = -1 if ops[1].subtracted else 1
                effective = (base[1] + sign * index[1] + mem.disp) & MASK
                if effective == target:
                    hit = {'ldr': addr, 'instruction': ins.mnemonic + ' ' + ins.op_str,
                           'slot': effective, 'base': base[1], 'index': index[1],
                           'provenance': sorted(set(base[2] + index[2]))}
        elif unconditional and mnemonic == 'add' and len(ops) == 3 and ops[0].type == ARM_OP_REG and ops[1].type == ARM_OP_REG and ops[2].type in (ARM_OP_REG, ARM_OP_IMM) and ops[2].shift.type == ARM_SFT_INVALID:
            def value(op):
                if op.type == ARM_OP_IMM:
                    return (op.imm & MASK, [])
                if op.reg == ARM_REG_PC:
                    return ((addr + 8) & MASK, [])
                return (regs[op.reg][1], regs[op.reg][2]) if op.reg in regs else None
            a, b = value(ops[1]), value(ops[2])
            if a is not None and b is not None:
                val = (a[0] + b[0]) & MASK
                produced = (ops[0].reg, val, a[1] + b[1] + [(addr, ins.mnemonic + ' ' + ins.op_str, None, val)])
        # Invalidate all explicit and implicit writes, even unsupported operations.
        try:
            _, writes = ins.regs_access()
            for reg in writes:
                regs.pop(reg, None)
        except Exception:
            regs.clear()
        if produced:
            regs[produced[0]] = produced
        if hit:
            results.append(hit)
    return results


def executable_segments(elf):
    if len(elf) < 52 or elf[:6] != b'\x7fELF\x01\x01' or struct.unpack_from('<H', elf, 18)[0] != 40:
        raise HierarchyLinkError('expected little-endian ARM ELF32')
    phoff = struct.unpack_from('<I', elf, 28)[0]
    entsize, count = struct.unpack_from('<HH', elf, 42)
    if entsize < 32 or phoff + entsize * count > len(elf):
        raise HierarchyLinkError('invalid program headers')
    for i in range(count):
        typ, off, va, _, filesz, _, flags, _ = struct.unpack_from('<IIIIIIII', elf, phoff + i * entsize)
        if typ == 1 and flags & 1:
            if off + filesz > len(elf) or va % 4:
                raise HierarchyLinkError('invalid executable segment')
            yield va, elf[off:off + filesz]


def find(elf, target, window=512):
    def read_word(address):
        offset = file_offset(elf, address)
        if file_offset(elf, address + 3) != offset + 3:
            raise ValueError('literal spans segments')
        return struct.unpack_from('<I', elf, offset)[0]
    hits = []
    for va, code in executable_segments(elf):
        hits.extend(scan(code, va, read_word, target, window))
    return hits


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('elf', type=Path)
    parser.add_argument('--slot', type=lambda x: int(x, 0), default=0x604d50)
    parser.add_argument('--window', type=int, default=512, help='maximum provenance age in bytes (default: 512)')
    args = parser.parse_args()
    if not 0 <= args.slot <= MASK or args.window < 4:
        parser.error('slot must be uint32 and window must be >= 4')
    try:
        elf = args.elf.read_bytes()
        hits = find(elf, args.slot, args.window)
        print(json.dumps({'sha256': hashlib.sha256(elf).hexdigest(), 'slot': args.slot,
                          'window_bytes': args.window, 'hits': hits}, indent=2))
    except (OSError, ValueError, struct.error, IndexError) as exc:
        print(f'error: {exc}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
