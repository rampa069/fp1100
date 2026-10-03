import struct, sys
def lee(fn):
    d=open(fn,'rb').read()
    nt=d[0x30]; ns=d[0x31]; tsz=d[0x34:0x34+nt*ns]; off=0x100; img={}; pos={}
    for t in range(nt*ns):
        sz=tsz[t]*256
        if not sz: continue
        tb=d[off:off+sz]; trk,side,nsec=tb[0x10],tb[0x11],tb[0x15]; p=off+0x100
        for k in range(nsec):
            c,h,r,n,s1,s2,al=struct.unpack_from('<BBBBBBH',tb,0x18+8*k); img[(trk,side,r)]=d[p:p+al]; pos[(trk,side,r)]=p; p+=al
        off+=sz
    lin=b''.join(img.get((t,s,r),b'\0'*256) for t in range(40) for s in range(2) for r in range(1,17))
    return d, lin, pos
