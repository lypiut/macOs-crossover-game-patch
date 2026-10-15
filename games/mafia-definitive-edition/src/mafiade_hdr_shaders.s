.section __TEXT,__hdrdata
.p2align 4
.globl _proxy_vs_start
_proxy_vs_start:
.incbin "proxy-vertex.dxbc"
.globl _proxy_vs_end
_proxy_vs_end:
.p2align 4
.globl _proxy_ps_start
_proxy_ps_start:
.incbin "proxy-pixel.dxbc"
.globl _proxy_ps_end
_proxy_ps_end:
