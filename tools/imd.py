import sys
def leer_imd(data):
    i = data.index(b'\x1a'); cab = data[:i].decode('latin-1'); p = i + 1
    pistas = {}
    while p < len(data):
        mode, cyl, head, nsec, ssz = data[p:p+5]; p += 5
        if nsec == 0: continue
        size = 128 << ssz if ssz < 7 else None
        smap = list(data[p:p+nsec]); p += nsec
        cmap = list(data[p:p+nsec]) if head & 0x80 else [cyl]*nsec
        if head & 0x80: p += nsec
        hmap = list(data[p:p+nsec]) if head & 0x40 else [head & 0x3f]*nsec
        if head & 0x40: p += nsec
        secs = []
        for k in range(nsec):
            t = data[p]; p += 1
            if t == 0: d = b''; err = True; delet = False
            else:
                if t in (1,3,5,7): d = data[p:p+size]; p += size
                else: d = bytes([data[p]])*size; p += 1
                delet = t in (3,4,7,8); err = t in (5,6,7,8)
            secs.append((cmap[k], hmap[k], smap[k], ssz, d, delet, err))
        pistas[(cyl, head & 0x3f)] = (mode, secs)
    return cab, pistas
if __name__ == '__main__':
    for f in sys.argv[1:]:
        cab, pistas = leer_imd(open(f,'rb').read())
        geo = {}
        for (c,h),(mode,secs) in pistas.items():
            geo.setdefault((mode,len(secs),secs[0][3] if secs else None),[]).append((c,h))
        cils = sorted(set(c for c,h in pistas)); heads = sorted(set(h for c,h in pistas))
        print(f.split('/')[-1], '|', cab.splitlines()[1] if len(cab.splitlines())>1 else '', '| cils', cils[0],'-',cils[-1], 'caras', heads, '| geo', {k:len(v) for k,v in geo.items()})
        c0=pistas.get((0,0)); 
        if c0: print('   pista 0:', [s[2] for s in c0[1]], 'sector1 primeros bytes:', [s for s in c0[1] if s[2]==1][0][4][:16].hex())
