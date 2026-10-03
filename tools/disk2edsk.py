#!/usr/bin/env python3
"""Convierte imagenes de disco del FP-1100 a EDSK para el core:
IMD (ImageDisk), TD0 (Teledisk, tambien con compresion avanzada) y D88.

    disk2edsk.py entrada.imd|.td0|.d88 [salida.dsk]

Si un TD0 esta "pasado por UTF-8" (bytes altos convertidos a dos bytes, como
los de la coleccion que circula), se deshace antes de leerlo.
"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from d88toedsk import leer_d88, escribir_edsk
from imd import leer_imd
from td0 import leer_td0

def normaliza(secs):
    out = []
    for s in secs:
        if len(s) == 8:      # td0: (c,h,r,n,st,del,crcerr,datos)
            c, h, r, n, st, dl, err, d = s
            out.append((c, h, r, n, 0xb0 if err else 0, dl, d))
        elif len(s) == 7 and isinstance(s[4], bytes):   # imd: (c,h,r,n,datos,del,err)
            c, h, r, n, d, dl, err = s
            out.append((c, h, r, n, 0xb0 if err else 0, dl, d))
        else:
            out.append(s)
    return out

def cargar(fich):
    data = open(fich, 'rb').read()
    ext = fich.lower().rsplit('.', 1)[-1]
    if data[:3] == b'IMD':
        cab, pistas = leer_imd(data)
        return cab.splitlines()[1] if len(cab.splitlines()) > 1 else '', {k: normaliza(v[1]) for k, v in pistas.items()}
    if data[:2] in (b'TD', b'td') or ext == 'td0':
        if data[:2] not in (b'TD', b'td'):
            data = data.decode('utf-8').encode('latin-1')
        try:
            com, pistas = leer_td0(data)
        except Exception:
            data = data.decode('utf-8').encode('latin-1')
            com, pistas = leer_td0(data)
        return com.strip().split('\n')[0], {k: normaliza(v) for k, v in pistas.items()}
    pistas, wp = leer_d88(data)
    return data[0:17].rstrip(b'\0').decode('latin-1', 'replace'), pistas

if __name__ == '__main__':
    ent = sys.argv[1]
    sal = sys.argv[2] if len(sys.argv) > 2 else ent.rsplit('.', 1)[0] + '.dsk'
    com, pistas = cargar(ent)
    escribir_edsk(pistas, sal)
    s1 = [s for s in pistas.get((0, 0), []) if s[2] == 1]
    arranca = s1 and s1[0][6][:1] == b'\xc3'
    print('%-14s -> %-14s %3d pistas  %s  %s' % (os.path.basename(ent), os.path.basename(sal), len(pistas),
          'ARRANCABLE' if arranca else 'no arranca', com[:60]))
