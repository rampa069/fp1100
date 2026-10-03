#!/usr/bin/env python3
"""Desensamblador del uPD7801 sacado de las tablas del emulador de Takeda
(ref/takeda_fp1100/upd7801.cpp).  Uso: upd7801dasm.py fichero.bin base_hex ini_hex fin_hex"""
import re, sys, os

SRC = os.path.join(os.path.dirname(__file__), '..', 'ref', 'takeda_fp1100', 'upd7801.cpp')
txt = open(SRC, encoding='utf-8', errors='ignore').read()
i = txt.index('int UPD7801::debug_dasm')
j = txt.index('return upd7801_dasm_ptr;', i)
body = txt[i:j]

tabla = {}   # (prefijo o None, opcode) -> (fmt, [args])
prefijo = None
nivel = 0
for line in body.split('\n'):
    s = line.strip()
    m = re.match(r'case 0x([0-9a-f]{2}):\s*$', s)
    if m and line.startswith('\tcase') and not line.startswith('\t\t'):
        prefijo = int(m.group(1), 16); continue
    m = re.match(r'case 0x([0-9a-f]{2}):(.*)break;', s)
    if not m: continue
    op = int(m.group(1), 16)
    stmt = m.group(2)
    fm = re.search(r'_T\("([^"]*)"\)', stmt)
    if not fm: continue
    fmt = fm.group(1).replace('%s', '%04xh')
    args = re.findall(r'get(wa|w|b)\(\)', stmt)
    pref = prefijo if line.startswith('\t\t') else None
    tabla[(pref, op)] = (fmt, args)

def dasm(mem, pc, base):
    def rd(a): return mem[a - base] if 0 <= a - base < len(mem) else 0xff
    p = pc
    b = rd(p); p += 1
    key = (None, b)
    if (b, ) and any(k[0] == b for k in tabla) and (None, b) not in tabla:
        b2 = rd(p); p += 1
        key = (b, b2)
    if key not in tabla:
        return p - pc, 'db %02xh' % b
    fmt, args = tabla[key]
    vals = []
    for a in args:
        if a == 'w':
            vals.append(rd(p) | (rd(p + 1) << 8)); p += 2
        else:
            vals.append(rd(p)); p += 1
    try: txt = fmt % tuple(vals)
    except TypeError: txt = fmt
    return p - pc, txt

if __name__ == '__main__':
    mem = open(sys.argv[1], 'rb').read()
    base = int(sys.argv[2], 16); ini = int(sys.argv[3], 16); fin = int(sys.argv[4], 16)
    pc = ini
    while pc < fin:
        n, t = dasm(mem, pc, base)
        print('%04x  %-10s %s' % (pc, mem[pc-base:pc-base+n].hex(' '), t))
        pc += n
