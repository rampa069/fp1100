"""Lector de imagenes Teledisk (TD0), con la compresion "avanzada" (LZSS +
Huffman adaptativo, el lzhuf de Okumura/Yoshizaki que usa Teledisk)."""
import struct

N, F, THRESHOLD = 4096, 60, 2
N_CHAR = 256 - THRESHOLD + F
T = N_CHAR * 2 - 1
R = T - 1
MAX_FREQ = 0x8000

def _tablas():
    d_code, d_len = [], []
    for code, cnt, ln in [(0, 32, 3), (1, 16, 4), (2, 16, 4), (3, 16, 4), (4, 8, 5), (5, 8, 5), (6, 8, 5), (7, 8, 5),
                          (8, 8, 5), (9, 8, 5), (10, 8, 5), (11, 8, 5)]:
        d_code += [code] * cnt; d_len += [ln] * cnt
    for code in range(12, 24): d_code += [code] * 4; d_len += [6] * 4
    for code in range(24, 48): d_code += [code] * 2; d_len += [7] * 2
    for code in range(48, 64): d_code += [code]; d_len += [8]
    assert len(d_code) == 256
    return d_code, d_len
D_CODE, D_LEN = _tablas()

class LZHUF:
    def __init__(self, data, pos):
        self.data = data; self.pos = pos
        self.getbuf = 0; self.getlen = 0
        self.freq = [0] * (T + 1); self.prnt = [0] * (T + N_CHAR); self.son = [0] * T
        for i in range(N_CHAR):
            self.freq[i] = 1; self.son[i] = i + T; self.prnt[i + T] = i
        i, j = 0, N_CHAR
        while j <= R:
            self.freq[j] = self.freq[i] + self.freq[i + 1]
            self.son[j] = i; self.prnt[i] = self.prnt[i + 1] = j
            i += 2; j += 1
        self.freq[T] = 0xffff; self.prnt[R] = 0
        self.text = bytearray([0x20] * (N + F - 1)); self.r = N - F
        self.pend = []

    def _llena(self):
        while self.getlen <= 8:
            b = self.data[self.pos] if self.pos < len(self.data) else 0
            self.pos += 1
            self.getbuf |= b << (8 - self.getlen); self.getlen += 8
    def getbit(self):
        self._llena(); i = self.getbuf; self.getbuf = (self.getbuf << 1) & 0xffff; self.getlen -= 1
        return (i & 0x8000) >> 15
    def getbyte(self):
        self._llena(); i = self.getbuf; self.getbuf = (self.getbuf << 8) & 0xffff; self.getlen -= 8
        return (i & 0xff00) >> 8

    def reconst(self):
        freq, son, prnt = self.freq, self.son, self.prnt
        j = 0
        for i in range(T):
            if son[i] >= T:
                freq[j] = (freq[i] + 1) // 2; son[j] = son[i]; j += 1
        i = 0
        for j in range(N_CHAR, T):
            k = i + 1
            f = freq[i] + freq[k]; freq[j] = f
            k = j - 1
            while f < freq[k]: k -= 1
            k += 1
            freq[k + 1:j + 1] = freq[k:j]; freq[k] = f
            son[k + 1:j + 1] = son[k:j]; son[k] = i
            i += 2
        for i in range(T):
            k = son[i]
            if k >= T: prnt[k] = i
            else: prnt[k] = prnt[k + 1] = i

    def update(self, c):
        freq, son, prnt = self.freq, self.son, self.prnt
        if freq[R] == MAX_FREQ: self.reconst()
        c = prnt[c + T]
        while True:
            freq[c] += 1; k = freq[c]
            l = c + 1
            if k > freq[l]:
                while k > freq[l + 1]: l += 1
                freq[c] = freq[l]; freq[l] = k
                i = son[c]; prnt[i] = l
                if i < T: prnt[i + 1] = l
                j = son[l]; son[l] = i
                prnt[j] = c
                if j < T: prnt[j + 1] = c
                son[c] = j
                c = l
            c = prnt[c]
            if c == 0: break

    def decode_char(self):
        c = self.son[R]
        while c < T:
            c += self.getbit(); c = self.son[c]
        c -= T; self.update(c); return c
    def decode_position(self):
        i = self.getbyte(); c = D_CODE[i] << 6; j = D_LEN[i] - 2
        while j:
            i = (i << 1) + self.getbit(); j -= 1
        return c | (i & 0x3f)

    def read(self, n):
        out = bytearray()
        while len(out) < n:
            if self.pend:
                out.append(self.pend.pop(0)); continue
            if self.pos >= len(self.data) + 8: raise EOFError
            c = self.decode_char()
            if c < 256:
                self.text[self.r] = c; self.r = (self.r + 1) & (N - 1); out.append(c)
            else:
                i = (self.r - self.decode_position() - 1) & (N - 1)
                for k in range(c - 255 + THRESHOLD):
                    ch = self.text[(i + k) & (N - 1)]
                    self.text[self.r] = ch; self.r = (self.r + 1) & (N - 1)
                    self.pend.append(ch)
        return bytes(out)

class Plano:
    def __init__(self, data, pos): self.data = data; self.pos = pos
    def read(self, n):
        r = self.data[self.pos:self.pos + n]; self.pos += n
        if len(r) < n: raise EOFError
        return r

def leer_td0(data):
    firma = data[0:2]
    assert firma in (b'TD', b'td'), 'no es un TD0'
    ver = data[4]; step = data[7]; caras = data[9]
    src = LZHUF(data, 12) if firma == b'td' else Plano(data, 12)
    comentario = ''
    if step & 0x80:
        c = src.read(10); n = struct.unpack_from('<H', c, 2)[0]
        comentario = src.read(n).decode('latin-1', 'replace').replace('\0', '\n')
    pistas = {}
    while True:
        h = src.read(4)
        nsec, cyl, head = h[0], h[1], h[2] & 1
        if nsec == 0xff: break
        secs = []
        for _ in range(nsec):
            s = src.read(6)
            c, hh, r, n, flags = s[0], s[1], s[2], s[3], s[4]
            tam = 128 << n
            if flags & 0x30:
                d = b'\xe5' * tam
            else:
                ln = struct.unpack('<H', src.read(2))[0]
                blk = src.read(ln)
                met = blk[0]; b = blk[1:]
                if met == 0:
                    d = b
                elif met == 1:
                    cnt = struct.unpack_from('<H', b, 0)[0]; d = b[2:4] * cnt
                elif met == 2:
                    d = bytearray(); p = 0
                    while p < len(b) and len(d) < tam:
                        t = b[p]; p += 1
                        if t == 0:
                            k = b[p]; p += 1; d += b[p:p + k]; p += k
                        else:
                            k = b[p]; p += 1; pat = b[p:p + 2 * t]; p += 2 * t; d += pat * k
                    d = bytes(d)
                else:
                    raise ValueError('metodo %d' % met)
                d = d[:tam].ljust(tam, b'\xe5')
            secs.append((c, hh, r, n, 0, bool(flags & 0x04), bool(flags & 0x02), d))
        pistas[(cyl, head)] = secs
    return comentario, pistas

if __name__ == '__main__':
    import sys
    for f in sys.argv[1:]:
        d = open(f, 'rb').read()
        try: d = d.decode('utf-8').encode('latin-1')
        except Exception: pass
        com, pistas = leer_td0(d)
        cils = sorted(set(c for c, _ in pistas)); heads = sorted(set(h for _, h in pistas))
        geo = {}
        for k, secs in pistas.items(): geo[(len(secs), secs[0][3] if secs else None)] = geo.get((len(secs), secs[0][3] if secs else None), 0) + 1
        print(f.split('/')[-1], '|', com.strip().replace('\n', ' / ')[:80], '| cils', cils[0], '-', cils[-1], 'caras', heads, '| geo', geo)
        s1 = [s for s in pistas.get((0, 0), []) if s[2] == 1]
        if s1: print('   sector 1:', s1[0][7][:16].hex())
