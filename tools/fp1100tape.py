#!/usr/bin/env python3
"""Cintas del Casio FP-1000/FP-1100: WAV <-> CAS <-> TZX (y TAP, WAV limpio).

    fp1100tape.py ENTRADA [SALIDA ...] [opciones]

    ENTRADA   .wav (PCM 8/16/24/32 bits, mono o estereo, cualquier frecuencia),
              .cas (el formato de abajo) o .tzx
    SALIDA    .cas, .tzx, .wav (audio limpio regenerado) o .tap (el formato
              "TAP" de los emuladores de Takeda: eFP-1100 lo carga)
              Sin salidas solo informa de lo que hay en la cinta.

    ejemplos:
      fp1100tape.py juego.wav                      # que hay y si lee bien
      fp1100tape.py juego.wav juego.cas juego.tzx  # las dos a la vez
      fp1100tape.py juego.cas juego.wav            # WAV limpio para el core
      fp1100tape.py juego.wav -v                   # con volcado hex de los bloques

Opciones:
    --canal L|R|M     de un WAV estereo: izquierdo, derecho o mezcla (M, def.)
    --invertir        lee el WAV con la polaridad invertida. Por defecto se
                      prueban las dos y se usa la que lee mejor; importa,
                      porque la maquina mide de flanco de subida a flanco de
                      subida y al reves un 0 seguido de 1 cae en el umbral
    --normal          no probar la polaridad invertida
    --umbral US       periodo que separa 2400 de 1200 Hz (def.: automatico,
                      alrededor de 625 us, el del circuito de la maquina)
    --baudios 1200|300|auto   (def. auto)
    --frecuencia HZ   de los WAV que se escriben (def. 22050)
    --bits 8|16       de los WAV que se escriben (def. 8)
    -v                volcado hexadecimal de cada bloque

-----------------------------------------------------------------------------
COMO GRABA EL FP-1100 (sacado del circuito, rtl/fp1100_cmt.v, y de cintas)
-----------------------------------------------------------------------------
Audio FSK: un bit 1 son dos ciclos de 2400 Hz y un bit 0 un ciclo de 1200 Hz
(1200 baudios). A 300 baudios, ocho ciclos de 2400 y cuatro de 1200 (Kansas
City). La maquina solo mira el periodo entre flancos de subida: menos de 625
us es 2400 Hz.

Bytes: 1 bit de arranque (0), 8 de datos empezando por el MENOS
significativo, paridad PAR y 2 de parada (1): 12 bits por byte. Entre bytes
puede haber unos de relleno. Cada bloque empieza con una guia de unos (2400
Hz continuos, ~3 s). Una cinta de BASIC tiene dos: la cabecera, que empieza
por 'H' (48h) y lleva el nombre (8 caracteres) en los bytes 2-9, y los
datos, que empiezan por 'D' (44h). Tras los datos la ROM graba unos bits que
no forman bytes: se guardan tal cual (fragmento "bits" del CAS).

-----------------------------------------------------------------------------
FORMATO CAS DEL FP-1100 (definido aqui: no existia ninguno)
-----------------------------------------------------------------------------
No hay CAS "oficial" para esta maquina, asi que este guarda la cinta al
nivel de bits que ve la maquina, sin perder nada, y con los bytes a la vista:

    cabecera   "FP1100CAS" 1Ah   (10 bytes)
               version  1 byte   (1)
               baudios  2 bytes  (LE: 1200 o 300)
               reservado 3 bytes (0)
    fragmentos, uno tras otro:
      01 n16        guia: n bits 1 seguidos (2400 Hz)
      02 n16 datos  n bytes, cada uno con su marco (arranque, 8 datos LSB
                    primero, paridad par, 2 de parada)
      03 n16 datos  n bits sueltos, en ceil(n/8) bytes, el primero en el bit
                    7 (lo que no forma bytes validos)
      04 n16        silencio de n milisegundos
      00            fin
    n16 = 2 bytes little endian (los fragmentos largos se parten).

Para reconstruir el audio: 1 = 2 ciclos de 2400 Hz, 0 = 1 ciclo de 1200 Hz
(x4 a 300 baudios), cada ciclo empezando por el flanco de subida.

TZX: bloques 19h (Generalized Data Block, TZX 1.20) con dos simbolos: 0 =
dos pulsos de 1458 T (1200 Hz a 3,5 MHz) y 1 = cuatro de 729 T (2400 Hz); la
pausa de cada bloque es el silencio que le sigue. Los TZX de entrada pueden
llevar ademas bloques 10h-15h y 20h.
"""
import sys, os, struct, math

T2400 = 1.0 / 2400
T1200 = 1.0 / 1200
UMBRAL_HW = 625e-6       # F21 del circuito: 48 x 13 us

# ---------------------------------------------------------------------------
# Lectura de WAV -> flancos de subida
# ---------------------------------------------------------------------------
def leer_wav(fich, canal='M', invertir=False):
    d = open(fich, 'rb').read()
    if d[:4] != b'RIFF' or d[8:12] != b'WAVE':
        raise SystemExit('%s: no es un WAV' % fich)
    i = 12; fmt = None; datos = None
    while i + 8 <= len(d):
        cid = d[i:i+4]; sz = struct.unpack_from('<I', d, i + 4)[0]
        if cid == b'fmt ':
            fmt = struct.unpack_from('<HHIIHH', d, i + 8)
        elif cid == b'data':
            datos = d[i+8:i+8+sz]
        i += 8 + sz + (sz & 1)
    if fmt is None or datos is None:
        raise SystemExit('%s: WAV sin fmt o sin data' % fich)
    tag, nch, rate, _, align, bits = fmt
    if tag not in (1, 0xFFFE) or bits not in (8, 16, 24, 32):
        raise SystemExit('%s: solo PCM entero de 8/16/24/32 bits' % fich)
    bps = bits // 8
    n = len(datos) // align
    # un canal o la mezcla, como enteros con signo
    if bits == 8:
        raw = [b - 128 for b in datos]
    elif bits == 16:
        raw = list(struct.unpack('<%dh' % (len(datos) // 2), datos[:len(datos) // 2 * 2]))
    elif bits == 32:
        raw = list(struct.unpack('<%di' % (len(datos) // 4), datos[:len(datos) // 4 * 4]))
    else:
        raw = [int.from_bytes(datos[k:k+3], 'little', signed=True)
               for k in range(0, len(datos) - 2, 3)]
    if nch == 1:
        x = raw[:n]
    elif canal == 'L':
        x = raw[0:n * nch:nch]
    elif canal == 'R':
        x = raw[1:n * nch:nch]
    else:
        x = [sum(raw[k:k + nch]) for k in range(0, n * nch, nch)]
    if invertir:
        x = [-v for v in x]
    return rate, x, (nch, bits)

def flancos_wav(rate, x):
    """Flancos de subida (segundos), con filtro de continua, disparador de
    Schmitt que sigue la envolvente (cintas de verdad con ruido) y una
    puerta de ruido: por debajo de un cuarto del nivel tipico de la senal no
    se cuenta nada (el silencio entre bloques no genera bits)."""
    a = math.exp(-2 * math.pi * 60.0 / rate)          # paso alto de 60 Hz
    hp = [0.0] * len(x); h_ = 0.0; prev = 0.0
    for k, v in enumerate(x):
        h_ = a * (h_ + v - prev); prev = v; hp[k] = h_
    muestra = sorted(abs(v) for v in hp[::16])
    ref = muestra[int(len(muestra) * 0.9)] if muestra else 0
    puerta = 0.25 * ref
    env = 0.0; caida = math.exp(-1.0 / (0.02 * rate))  # envolvente de 20 ms
    alto = False; ult = 0.0
    fl = []
    for k, v in enumerate(hp):
        m = v if v >= 0 else -v
        env = m if m > env else env * caida
        h = max(0.15 * env, 0.05 * ref)
        if env < puerta:
            alto = False
        elif not alto and v > h:
            alto = True
            fr = (v - h) / (v - ult) if v != ult else 0.0
            fl.append((k - min(max(fr, 0.0), 1.0)) / rate)
        elif alto and v < -h:
            alto = False
        ult = v
    return fl

# ---------------------------------------------------------------------------
# Pulsos (TZX) -> flancos de subida
# ---------------------------------------------------------------------------
def flancos_pulsos(pulsos):
    """pulsos: lista de (duracion_s, nivel) o ('pausa', s). El nivel cambia al
    principio de cada pulso."""
    t = 0.0; nivel = 0; fl = []
    for p in pulsos:
        if p[0] == 'pausa':
            nivel = 0; t += p[1]; continue
        dur, nuevo = p
        if nuevo is None:
            nuevo = 1 - nivel
        if nuevo == 1 and nivel == 0:
            fl.append(t)
        nivel = nuevo; t += dur
    return fl

def leer_tzx(fich):
    d = open(fich, 'rb').read()
    if d[:8] != b'ZXTape!\x1a':
        raise SystemExit('%s: no es un TZX' % fich)
    TS = 1.0 / 3500000
    i = 10; pulsos = []
    def u16(o): return d[o] | d[o+1] << 8
    def u24(o): return d[o] | d[o+1] << 8 | d[o+2] << 16
    def u32(o): return struct.unpack_from('<I', d, o)[0]
    def datos_std(p0, p1, bits_ult, datos):
        for n, b in enumerate(datos):
            nb = bits_ult if n == len(datos) - 1 else 8
            for k in range(nb):
                l = p1 if b & (0x80 >> k) else p0
                pulsos.extend([(l * TS, None), (l * TS, None)])
    def pausa(ms):
        if ms:
            pulsos.append(('pausa', ms / 1000.0))
    while i < len(d):
        bid = d[i]; i += 1
        if bid == 0x10:
            ms = u16(i); n = u16(i + 2); dat = d[i+4:i+4+n]
            npil = 8063 if dat and dat[0] < 128 else 3223
            pulsos.extend([(2168 * TS, None)] * npil + [(667 * TS, None), (735 * TS, None)])
            datos_std(855, 1710, 8, dat); pausa(ms); i += 4 + n
        elif bid == 0x11:
            pil, s1, s2, p0, p1, npil = struct.unpack_from('<6H', d, i)
            ub = d[i+12]; ms = u16(i + 13); n = u24(i + 15); dat = d[i+18:i+18+n]
            pulsos.extend([(pil * TS, None)] * npil + [(s1 * TS, None), (s2 * TS, None)])
            datos_std(p0, p1, ub, dat); pausa(ms); i += 18 + n
        elif bid == 0x12:
            l, n = u16(i), u16(i + 2); pulsos.extend([(l * TS, None)] * n); i += 4
        elif bid == 0x13:
            n = d[i]; pulsos.extend([(u16(i + 1 + 2*k) * TS, None) for k in range(n)]); i += 1 + 2*n
        elif bid == 0x14:
            p0, p1 = u16(i), u16(i + 2); ub = d[i+4]; ms = u16(i + 5); n = u24(i + 7)
            datos_std(p0, p1, ub, d[i+10:i+10+n]); pausa(ms); i += 10 + n
        elif bid == 0x15:
            tpm = u16(i); ms = u16(i + 2); ub = d[i+4]; n = u24(i + 5); dat = d[i+8:i+8+n]
            tot = (n - 1) * 8 + ub
            for k in range(tot):
                lv = (dat[k // 8] >> (7 - k % 8)) & 1
                pulsos.append((tpm * TS, lv))
            pausa(ms); i += 8 + n
        elif bid == 0x19:
            lon = u32(i); o = i + 4
            ms = u16(o); totp = u32(o + 2); npp = d[o+6]; asp = d[o+7] or 256
            totd = u32(o + 8); npd = d[o+12]; asd = d[o+13] or 256
            o += 14
            def tabla(o, n, np_):
                t = []
                for _ in range(n):
                    fl = d[o]; pl = [u16(o + 1 + 2*k) for k in range(np_)]
                    t.append((fl & 3, pl)); o += 1 + 2 * np_
                return t, o
            def simbolo(fl, pl):
                primero = True
                for l in pl:
                    if l == 0: break
                    if primero and fl in (2, 3):
                        pulsos.append((l * TS, fl - 2))
                    elif primero and fl == 1:
                        pulsos.append((l * TS, 'igual'))
                    else:
                        pulsos.append((l * TS, None))
                    primero = False
            if totp:
                tp, o = tabla(o, asp, npp)
                for k in range(totp):
                    s = d[o]; rep = u16(o + 1); o += 3
                    for _ in range(rep): simbolo(*tp[s])
            if totd:
                td, o = tabla(o, asd, npd)
                nb = max(1, math.ceil(math.log2(asd)))
                bitpos = 0
                for _ in range(totd):
                    v = 0
                    for _ in range(nb):
                        v = v << 1 | (d[o + bitpos // 8] >> (7 - bitpos % 8)) & 1
                        bitpos += 1
                    simbolo(*td[v])
            pausa(ms); i += 4 + lon
        elif bid == 0x20:
            ms = u16(i); pausa(ms if ms else 1000); i += 2
        elif bid in (0x21, 0x30):
            i += 1 + d[i]
        elif bid in (0x22,):
            pass
        elif bid == 0x32:
            i += 2 + u16(i)
        elif bid in (0x31,):
            i += 2 + d[i + 1]
        elif bid in (0x33,):
            i += 1 + 3 * d[i]
        elif bid == 0x35:
            i += 20 + u32(i + 16)
        elif bid == 0x5A:
            i += 9
        else:
            raise SystemExit('%s: bloque TZX %02Xh no soportado' % (fich, bid))
    # 'igual' = mismo nivel que el anterior
    out = []; nivel = 0
    for p in pulsos:
        if p[0] != 'pausa' and p[1] == 'igual':
            p = (p[0], nivel)
        if p[0] == 'pausa':
            nivel = 0
        else:
            nivel = (1 - nivel) if p[1] is None else p[1]
        out.append(p)
    return flancos_pulsos(out)

# ---------------------------------------------------------------------------
# Flancos -> bits -> fragmentos
# ---------------------------------------------------------------------------
def a_bits(fl, umbral=None, baudios='auto', avisos=None):
    """Devuelve (lista de simbolos, baudios, umbral). Simbolos: '0', '1', o
    ('silencio', segundos). Se agrupan los periodos en rachas de cortos y
    largos: a 1200 baudios dos cortos son un 1 y un largo un 0."""
    per = [(fl[k], fl[k+1] - fl[k]) for k in range(len(fl) - 1)]
    if umbral is None:
        # calibrado con los cortos: la guia es muy larga y domina
        cortos = sorted(p for _, p in per if 250e-6 < p < UMBRAL_HW)
        if cortos:
            med = cortos[len(cortos) // 2]
            umbral = med * 1.5 if abs(med / (T2400) - 1) > 0.06 else UMBRAL_HW
        else:
            umbral = UMBRAL_HW
    silencio = 4 * umbral
    # rachas
    rachas = []                      # (t, 'S'|'L'|'G', n o segundos)
    for t, p in per:
        c = 'G' if p > silencio else ('S' if p < umbral else 'L')
        if c == 'G':
            rachas.append((t, 'G', p))
        elif rachas and rachas[-1][1] == c:
            rachas[-1] = (rachas[-1][0], c, rachas[-1][2] + 1)
        else:
            rachas.append((t, c, 1))
    if baudios == 'auto':
        largos = [n for _, c, n in rachas if c == 'L']
        baudios = 300 if largos and sum(1 for n in largos if n % 4 == 0) > 0.9 * len(largos) else 1200
    else:
        baudios = int(baudios)
    n0 = 1 if baudios == 1200 else 4
    # Trozos minusculos entre silencios (ruido): silencio
    limpio = []; k = 0
    while k < len(rachas):
        if rachas[k][1] == 'G':
            limpio.append(rachas[k]); k += 1; continue
        j = k; ciclos = 0
        while j < len(rachas) and rachas[j][1] != 'G':
            ciclos += rachas[j][2]; j += 1
        if ciclos < 24:
            dur = sum(p for t, p in per if rachas[k][0] <= t < (rachas[j][0] if j < len(rachas) else 1e99))
            limpio.append((rachas[k][0], 'G', dur))
        else:
            limpio.extend(rachas[k:j])
        k = j
    rachas = limpio
    sim = []; malos = 0
    for idx, (t, c, n) in enumerate(rachas):
        # la ultima racha antes de un silencio o del final pierde su ultimo
        # ciclo (no hay flanco de subida que lo cierre): no es un error
        cola = (idx + 1 == len(rachas) or rachas[idx + 1][1] == 'G' or
                idx == 0 or rachas[idx - 1][1] == 'G' or
                (idx + 2 < len(rachas) and rachas[idx + 2][1] == 'G' and rachas[idx + 1][2] < 4))
        if cola and c == 'S' and n % (2 * n0):
            n += 1
        if c == 'G':
            sim.append(('silencio', n)); continue
        if c == 'L':
            k, r = divmod(n, n0)
            sim.extend('0' * max(k, 1 if r else 0))
            if r: malos += 1; avisos is not None and avisos.append((t, 'racha de %d ciclos de 1200 Hz' % n))
        else:
            k, r = divmod(n, 2 * n0)
            if r:
                malos += 1
                avisos is not None and avisos.append((t, 'racha de %d ciclos de 2400 Hz' % n))
                k += 1 if r >= n0 else 0
            sim.extend('1' * k)
    return sim, baudios, umbral, malos

def marco_ok(b, i):
    if i + 12 > len(b) or b[i] != '0': return None
    f = b[i:i+12]
    if any(c not in '01' for c in f): return None
    d = f[1:9]
    if (d.count('1') + (f[9] == '1')) % 2 or f[10:12] != '11': return None
    return int(d[::-1], 2)

def a_fragmentos(sim):
    """Simbolos -> fragmentos: ('guia', n) ('bytes', bytearray) ('bits', str)
    ('silencio', ms)."""
    frag = []
    def add(tipo, v):
        if frag and frag[-1][0] == tipo and tipo != 'silencio':
            frag[-1] = (tipo, frag[-1][1] + v)
        elif frag and tipo == 'silencio' and frag[-1][0] == 'silencio':
            frag[-1] = (tipo, frag[-1][1] + v)
        else:
            frag.append((tipo, v))
    # trozos entre silencios
    trozo = []
    def procesa(b):
        b = ''.join(b); i = 0; crudo = False
        while i < len(b):
            if b[i] == '1':
                j = i
                while j < len(b) and b[j] == '1': j += 1
                if not crudo or j - i >= 32:
                    add('guia', j - i); crudo = False
                else:
                    add('bits', b[i:j])
                i = j; continue
            v = marco_ok(b, i)
            if v is not None and (not crudo or marco_ok(b, i + 12) is not None):
                crudo = False
                add('bytes', bytearray([v])); i += 12
            else:
                crudo = True
                add('bits', b[i]); i += 1
    for s in sim:
        if isinstance(s, tuple):
            procesa(trozo); trozo = []
            add('silencio', s[1] * 1000.0)
        else:
            trozo.append(s)
    procesa(trozo)
    return [(t, round(v) if t == 'silencio' else v) for t, v in frag
            if not (t == 'silencio' and round(v) == 0)]

# ---------------------------------------------------------------------------
# CAS
# ---------------------------------------------------------------------------
MAGIA = b'FP1100CAS\x1a'

def escribir_cas(fich, frag, baudios):
    o = bytearray(MAGIA) + bytes([1]) + struct.pack('<H', baudios) + bytes(3)
    for t, v in frag:
        if t == 'guia':
            while v > 0:
                n = min(v, 0xFFFF); o += bytes([1]) + struct.pack('<H', n); v -= n
        elif t == 'bytes':
            for k in range(0, len(v), 0xFFFF):
                c = v[k:k + 0xFFFF]; o += bytes([2]) + struct.pack('<H', len(c)) + c
        elif t == 'bits':
            for k in range(0, len(v), 0xFFF8):
                c = v[k:k + 0xFFF8]
                o += bytes([3]) + struct.pack('<H', len(c))
                c2 = c + '0' * (-len(c) % 8)
                o += bytes(int(c2[j:j+8], 2) for j in range(0, len(c2), 8))
        elif t == 'silencio':
            while v > 0:
                n = min(v, 0xFFFF); o += bytes([4]) + struct.pack('<H', n); v -= n
    o += bytes([0])
    open(fich, 'wb').write(o)

def leer_cas(fich):
    d = open(fich, 'rb').read()
    if d[:10] != MAGIA:
        raise SystemExit('%s: no es un CAS del FP-1100 (de esta herramienta)' % fich)
    baudios = struct.unpack_from('<H', d, 11)[0]
    i = 16; frag = []
    while i < len(d):
        t = d[i]; i += 1
        if t == 0: break
        n = struct.unpack_from('<H', d, i)[0]; i += 2
        if t == 1: frag.append(('guia', n))
        elif t == 2: frag.append(('bytes', bytearray(d[i:i+n]))); i += n
        elif t == 3:
            nb = (n + 7) // 8
            frag.append(('bits', ''.join(format(b, '08b') for b in d[i:i+nb])[:n])); i += nb
        elif t == 4: frag.append(('silencio', n))
        else: raise SystemExit('%s: fragmento %02Xh desconocido' % (fich, t))
    return frag, baudios

# ---------------------------------------------------------------------------
# Fragmentos -> bits -> pulsos / audio
# ---------------------------------------------------------------------------
def bits_de(frag):
    """Fragmentos -> lista de trozos: str de bits o ('silencio', ms)."""
    out = []; cur = []
    for t, v in frag:
        if t == 'silencio':
            if cur: out.append(''.join(cur)); cur = []
            out.append(('silencio', v))
        elif t == 'guia':
            cur.append('1' * v)
        elif t == 'bits':
            cur.append(v)
        else:
            for b in v:
                d = format(b, '08b')[::-1]
                cur.append('0' + d + ('1' if d.count('1') % 2 else '0') + '11')
    if cur: out.append(''.join(cur))
    return out

def pulsos_de(frag, baudios):
    """Semiperiodos: lista de (segundos, nivel)."""
    n0 = 1 if baudios == 1200 else 4
    p = []
    for tr in bits_de(frag):
        if isinstance(tr, tuple):
            p.append((tr[1] / 1000.0, 2)); continue       # 2 = silencio
        for c in tr:
            if c == '1':
                p.extend([(T2400 / 2, 1), (T2400 / 2, 0)] * (2 * n0))
            else:
                p.extend([(T1200 / 2, 1), (T1200 / 2, 0)] * n0)
    return p

def muestras(pulsos, rate, previo=0.2, final=0.5):
    """Nivel por muestra (0 bajo, 1 alto, 2 silencio), con los flancos en
    su sitio exacto (sin deriva: se acumula el tiempo, no las muestras)."""
    out = bytearray(); t = previo
    out += bytes([2]) * int(previo * rate)
    for dur, nv in pulsos:
        t += dur
        fin = int(round(t * rate))
        if fin > len(out):
            out += bytes([nv]) * (fin - len(out))
    out += bytes([2]) * int(final * rate)
    return out

def escribir_wav(fich, frag, baudios, rate=22050, bits=8):
    s = muestras(pulsos_de(frag, baudios), rate)
    if bits == 8:
        datos = bytes((28, 228, 128)[v] for v in s)
    else:
        niv = (struct.pack('<h', -24000), struct.pack('<h', 24000), struct.pack('<h', 0))
        datos = b''.join(niv[v] for v in s)
    ba = bits // 8
    hdr = b'RIFF' + struct.pack('<I', 36 + len(datos)) + b'WAVE'
    hdr += b'fmt ' + struct.pack('<IHHIIHH', 16, 1, 1, rate, rate * ba, ba, bits)
    hdr += b'data' + struct.pack('<I', len(datos))
    open(fich, 'wb').write(hdr + datos)

def escribir_tap(fich, frag, baudios, rate=48000):
    """TAP de los emuladores de Takeda (eFP-1100): frecuencia (4 bytes LE) y
    una muestra de 1 bit por bit, el primero en el bit 7."""
    s = muestras(pulsos_de(frag, baudios), rate)
    s = s + bytes(-len(s) % 8)
    o = bytearray(struct.pack('<I', rate))
    for k in range(0, len(s), 8):
        v = 0
        for j in range(8): v = v << 1 | (s[k + j] & 1)
        o.append(v)
    open(fich, 'wb').write(o)

def escribir_tzx(fich, frag, baudios):
    n0 = 1 if baudios == 1200 else 4
    L0, L1 = 1458, 729                       # T a 3,5 MHz
    s0 = [L0] * (2 * n0); s1 = [L1] * (4 * n0)
    npd = len(s1)
    o = bytearray(b'ZXTape!\x1a') + bytes([1, 20])
    texto = b'Casio FP-1100, %d baudios' % baudios
    o += bytes([0x30, len(texto)]) + texto
    trozos = bits_de(frag)
    k = 0
    while k < len(trozos):
        tr = trozos[k]
        if isinstance(tr, tuple):
            # silencio suelto (al principio o dos seguidos)
            o += bytes([0x20]) + struct.pack('<H', max(1, min(tr[1], 0xFFFF)))
            k += 1; continue
        ms = 0
        if k + 1 < len(trozos) and isinstance(trozos[k+1], tuple):
            ms = min(trozos[k+1][1], 0xFFFF); k += 1
        k += 1
        tabla = bytearray()
        for sim in (s0, s1):
            tabla += bytes([0]) + b''.join(struct.pack('<H', l) for l in sim + [0] * (npd - len(sim)))
        b = tr + '0' * (-len(tr) % 8)
        datos = bytes(int(b[j:j+8], 2) for j in range(0, len(b), 8))
        cuerpo = struct.pack('<HIBBIBB', ms, 0, 0, 0, len(tr), npd, 2) + tabla + datos
        o += bytes([0x19]) + struct.pack('<I', len(cuerpo)) + cuerpo
    open(fich, 'wb').write(o)

# ---------------------------------------------------------------------------
# Informe
# ---------------------------------------------------------------------------
def informe(frag, baudios, volcado=False, t_bits=None):
    print('baudios: %d' % baudios)
    t = 0.0; nb = 0
    tb = 1.0 / (1200 if baudios == 1200 else 300)
    for tipo, v in frag:
        if tipo == 'silencio':
            print('  %7.2f s  silencio %d ms' % (t, v)); t += v / 1000.0
        elif tipo == 'guia':
            if v >= 64: print('  %7.2f s  guia de %d bits (%.1f s)' % (t, v, v * tb))
            t += v * tb
        elif tipo == 'bits':
            print('  %7.2f s  %d bits que no forman bytes' % (t, len(v))); t += len(v) * tb
        else:
            nb += 1
            desc = ''
            if v[0] == 0x48 and len(v) >= 10:
                nombre = bytes(v[2:10]).decode('latin-1').rstrip()
                desc = "cabecera 'H', nombre \"%s\"" % nombre
            elif v[0] == 0x44:
                desc = "datos 'D'"
            print('  %7.2f s  bloque de %d bytes  %s' % (t, len(v), desc))
            if volcado:
                for k in range(0, len(v), 16):
                    c = v[k:k+16]
                    print('             %04x  %-48s %s' % (k, ' '.join('%02x' % x for x in c),
                          ''.join(chr(x) if 32 <= x < 127 else '.' for x in c)))
            t += len(v) * 12 * tb
    print('duracion: %.1f s' % t)

def main():
    args = sys.argv[1:]
    op = {'canal': 'M', 'invertir': False, 'polaridad_fija': False, 'umbral': None, 'baudios': 'auto',
          'frecuencia': 22050, 'bits': 8, 'v': False}
    pos = []; i = 0
    while i < len(args):
        a = args[i]
        if a == '--canal': op['canal'] = args[i+1].upper(); i += 2
        elif a == '--invertir': op['invertir'] = True; i += 1
        elif a == '--normal': op['polaridad_fija'] = True; i += 1
        elif a == '--umbral': op['umbral'] = float(args[i+1]) * 1e-6; i += 2
        elif a == '--baudios': op['baudios'] = args[i+1]; i += 2
        elif a == '--frecuencia': op['frecuencia'] = int(args[i+1]); i += 2
        elif a == '--bits': op['bits'] = int(args[i+1]); i += 2
        elif a == '-v': op['v'] = True; i += 1
        elif a in ('-h', '--help'): print(__doc__); return
        else: pos.append(a); i += 1
    if not pos:
        print(__doc__.split('-----')[0]); sys.exit(1)
    ent, salidas = pos[0], pos[1:]
    ext = os.path.splitext(ent)[1].lower()
    avisos = []
    if ext == '.cas':
        frag, baudios = leer_cas(ent)
    else:
        if ext == '.wav':
            rate, x, (nch, bits) = leer_wav(ent, op['canal'], op['invertir'])
            print('%s: %d Hz, %d bits, %d canal(es), %.1f s' % (ent, rate, bits, nch, len(x) / rate))
            fl = flancos_wav(rate, x)
            if not op['invertir'] and not op['polaridad_fija']:
                # La polaridad importa: la maquina mide de flanco de subida a
                # flanco de subida, y con el audio invertido un 0 seguido de
                # un 1 da un periodo de 625 us, justo en el umbral. Se prueba
                # al reves y se queda la que tenga menos sitios dudosos.
                fl2 = flancos_wav(rate, [-v for v in x])
                m1 = a_bits(fl, op['umbral'], op['baudios'])[3]
                m2 = a_bits(fl2, op['umbral'], op['baudios'])[3]
                if m2 < m1:
                    print('el audio esta INVERTIDO: se lee al reves (%d sitios dudosos contra %d)' % (m2, m1))
                    fl = fl2
        elif ext == '.tzx':
            fl = leer_tzx(ent)
        else:
            raise SystemExit('%s: extension desconocida (wav, cas, tzx)' % ent)
        sim, baudios, umbral, malos = a_bits(fl, op['umbral'], op['baudios'], avisos)
        print('umbral 2400/1200 Hz: %.0f us' % (umbral * 1e6))
        frag = a_fragmentos(sim)
        if malos:
            print('AVISO: %d sitios dudosos en el audio (ciclos sueltos):' % malos)
            for t, m in avisos[:10]:
                print('   %8.3f s  %s' % (t, m))
            if len(avisos) > 10: print('   ...')
    informe(frag, baudios, op['v'])
    for s in salidas:
        e = os.path.splitext(s)[1].lower()
        if e == '.cas': escribir_cas(s, frag, baudios)
        elif e == '.tzx': escribir_tzx(s, frag, baudios)
        elif e == '.wav': escribir_wav(s, frag, baudios, op['frecuencia'], op['bits'])
        elif e == '.tap': escribir_tap(s, frag, baudios)
        else: raise SystemExit('%s: salida desconocida (cas, tzx, wav, tap)' % s)
        print('escrito %s (%d bytes)' % (s, os.path.getsize(s)))

if __name__ == '__main__':
    main()
