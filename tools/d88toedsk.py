#!/usr/bin/env python3
"""Convierte imagenes D88 (emulador de Takeda) a EDSK (extended DSK) para el
core, y al reves. Tambien crea un disquete 2D vacio formateado.

    d88toedsk.py disco.d88 disco.dsk
    d88toedsk.py --edsk2d88 disco.dsk disco.d88
    d88toedsk.py --nuevo disco.dsk        (40 pistas x 2 caras x 16 x 256, E5)

Formato del FP-1100: 5,25" 2D, 40 pistas, 2 caras, 16 sectores de 256 bytes.
"""
import struct, sys

def leer_d88(data):
    """Devuelve dict {(cil, cara): [ (c,h,r,n, st1, st2, datos) ...]}"""
    nombre = data[0:17].rstrip(b'\0')
    wp = data[0x1a]; tipo = data[0x1b]
    size = struct.unpack_from('<I', data, 0x1c)[0]
    pistas = {}
    for t in range(164):
        off = struct.unpack_from('<I', data, 0x20 + 4*t)[0]
        if off == 0 or off >= size: continue
        cil, cara = t // 2, t % 2
        sectores = []
        p = off
        nsec = None
        while True:
            c, h, r, n, ns, dens, del_, st, = struct.unpack_from('<BBBBHBBB', data, p)
            tam = struct.unpack_from('<H', data, p + 0x0e)[0]
            datos = data[p + 0x10: p + 0x10 + tam]
            sectores.append((c, h, r, n, st, del_, datos))
            p += 0x10 + tam
            if nsec is None: nsec = ns
            if len(sectores) >= nsec: break
        pistas[(cil, cara)] = sectores
    return pistas, wp

def escribir_edsk(pistas, fich):
    cils = 1 + max(c for c, _ in pistas)
    caras = 1 + max(h for _, h in pistas)
    cab = bytearray(b'EXTENDED CPC DSK File\r\nDisk-Info\r\n')
    cab += b'FP1100 d88toedsk'.ljust(14)[:14]
    cab += bytes([cils, caras, 0, 0])
    cuerpo = bytearray()
    tamanos = []
    for c in range(cils):
        for h in range(caras):
            secs = pistas.get((c, h), [])
            if not secs:
                tamanos.append(0); continue
            tp = bytearray(b'Track-Info\r\n\0\0\0\0')
            tp += bytes([c, h, 0, 0, secs[0][3], len(secs), 0x4e, 0xe5])
            datos = bytearray()
            for (sc, sh, sr, sn, st, del_, d) in secs:
                st1 = 0x20 if (st & 0xf0) == 0xb0 else 0    # CRC error de datos
                st2 = (0x40 if del_ else 0) | (0x20 if st1 else 0)
                tp += bytes([sc, sh, sr, sn, st1, st2]) + struct.pack('<H', len(d))
                datos += d
            tp = tp.ljust(256, b'\0')
            total = len(tp) + len(datos)
            total = (total + 255) & ~255
            tamanos.append(total >> 8)
            cuerpo += (tp + datos).ljust(total, b'\0')
    cab += bytes(tamanos).ljust(204, b'\0')
    with open(fich, 'wb') as f:
        f.write(cab); f.write(cuerpo)

def leer_edsk(data):
    assert data[:8] == b'EXTENDED', 'no es un EDSK'
    cils, caras = data[0x30], data[0x31]
    tam = data[0x34:0x34 + cils * caras]
    pistas = {}
    p = 0x100
    for c in range(cils):
        for h in range(caras):
            t = tam[c * caras + h] << 8
            if t == 0: continue
            n = data[p + 0x14]; nsec = data[p + 0x15]
            secs = []; q = p + 0x100
            for i in range(nsec):
                sc, sh, sr, sn, st1, st2, tamd = struct.unpack_from('<BBBBBBH', data, p + 0x18 + 8 * i)
                secs.append((sc, sh, sr, sn, 0, bool(st2 & 0x40), data[q:q + tamd])); q += tamd
            pistas[(c, h)] = secs
            p += t
    return pistas

def escribir_d88(pistas, fich):
    cils = 1 + max(c for c, _ in pistas)
    cuerpo = bytearray(); offs = []
    for t in range(164):
        c, h = t // 2, t % 2
        secs = pistas.get((c, h))
        if not secs: offs.append(0); continue
        offs.append(0x2b0 + len(cuerpo))
        for (sc, sh, sr, sn, st, del_, d) in secs:
            cuerpo += struct.pack('<BBBBHBBB', sc, sh, sr, sn, len(secs), 0, 0x10 if del_ else 0, 0)
            cuerpo += b'\0' * 5 + struct.pack('<H', len(d)) + d
    cab = bytearray(0x2b0)
    cab[0:6] = b'FP1100'
    cab[0x1b] = 0x00                               # 2D
    struct.pack_into('<I', cab, 0x1c, 0x2b0 + len(cuerpo))
    for i, o in enumerate(offs): struct.pack_into('<I', cab, 0x20 + 4 * i, o)
    with open(fich, 'wb') as f:
        f.write(cab); f.write(cuerpo)

def nuevo():
    return {(c, h): [(c, h, r, 1, 0, False, b'\xe5' * 256) for r in range(1, 17)]
            for c in range(40) for h in range(2)}

if __name__ == '__main__':
    a = sys.argv[1:]
    if a[0] == '--nuevo':
        escribir_edsk(nuevo(), a[1])
    elif a[0] == '--edsk2d88':
        escribir_d88(leer_edsk(open(a[1], 'rb').read()), a[2])
    else:
        pistas, wp = leer_d88(open(a[0], 'rb').read())
        escribir_edsk(pistas, a[1])
        print('%d pistas, protegido=%d' % (len(pistas), wp))
