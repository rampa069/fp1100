# Disco del FP-1100 con AJUSTE.BAS (texto, tipo 30h) que arranca solo.
# Plantilla: la estructura EDSK de GAMDEMO2 (40 pistas, 2 caras, 16 x 256).
import sys, struct
sys.path.insert(0, __import__('os').path.dirname(__file__))
from lindsk import lee
d, lin, pos = lee(sys.argv[1]); d = bytearray(d)
def sec_off(linoff):
    s = linoff // 256; t = s // 32; side = (s // 16) % 2; r = s % 16 + 1
    return pos[(t, side, r)]
def escribe(linoff, data):
    for k in range(0, len(data), 256):
        o = sec_off(linoff + k); blk = data[k:k+256]
        d[o:o+len(blk)] = blk
txt = open(sys.argv[2], 'rb').read().replace(b'\r\n', b'\n').replace(b'\n', b'\r\n') + b'\x1a'
# FAT (sector en 2000h): byte 0 y clusteres 0-7 (sistema) como estaban; el
# resto libre (FF). La entrada del cluster c esta en 2000h + c + 1.
fat = bytearray(lin[0x2000:0x2100])
for c in range(8, 0xA0): fat[c + 1] = 0xFF
c0 = 8; n = (len(txt) + 2047) // 2048
for i in range(n):
    c = c0 + i
    if i < n - 1: fat[c + 1] = c + 1
    else: fat[c + 1] = 0xC0 + (len(txt) - 2048 * i + 255) // 256
escribe(0x2000, bytes(fat))
# Directorio (2100h-27FFh): vacio y una entrada
dirb = bytearray(0x700)
e = bytearray(32)
e[0] = 0x30                                   # BASIC en texto (como COPY.FIL)
e[1:12] = b'AJUSTE     '
e[12:20] = b'\xff' * 8
e[28] = c0
dirb[0:32] = e
escribe(0x2100, bytes(dirb))
# Datos
pad = txt + b'\x00' * (n * 2048 - len(txt))
escribe(c0 * 2048, pad)
# Arranque: el sector 1 de la pista 0 lleva  LOAD"0:SELECT.FIL",R ; se cambia
# el nombre (mismo largo)
b0 = bytearray(lin[0:256])
i = b0.find(b'0:SELECT.FIL')
nombre = b'0:AJUSTE'
b0[i:i+22] = (nombre + b' ' * 22)[:22]
escribe(0, bytes(b0))
open(sys.argv[3], 'wb').write(d)
print('hecho', len(txt), 'bytes de programa,', n, 'cluster(es)')
