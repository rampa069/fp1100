# Pruebas del core FP-1100.
#   make lint    comprobacion de todo el RTL de la maquina con Verilator
#   make sim     simulacion de la maquina completa: carga FP1100.ROM,
#                arranca BASIC y vuelca la pantalla a trama_N.ppm
#   make teclas  lo mismo, tecleando PRINT 1+2 al final
#   make disco   lo mismo con un disquete EDSK vacio en la unidad A: se ve
#                al IPL encontrar el FDC pack, recalibrar y leer el sector
#                de arranque por DRQ, y volver a BASIC al no haber sistema
#
# El Z80 (T80, VHDL) se sustituye por el tv80 (Verilog) con el mismo
# comportamiento de bus, y la SDRAM por el modelo del core NewBrain.
# Verilator hace ~1,3 M ciclos/s: un segundo de maquina son ~30 s.
RTL := ../rtl
MM  := ../common/mist-modules
SRC := $(RTL)/fp1100.v $(RTL)/fp1100_main.v $(RTL)/fp1100_sub.v \
       $(RTL)/fp1100_upd7801.sv $(RTL)/upd7800/upd7800.sv $(RTL)/fp1100_video.v $(RTL)/fp1100_display.v $(RTL)/fp1100_vfetch.v \
       $(RTL)/fp1100_kbd.v $(RTL)/fp1100_dpram.v $(RTL)/fp1100_sdram.v \
       $(RTL)/fp1100_fdc.v $(RTL)/u765/u765.sv $(RTL)/fp1100_cmt.v $(RTL)/fp1100_tape.v
SIM := tb_fp1100.sv sdram_model.v t80pa_tv80.v tv80_core.v tv80_alu.v tv80_mcode.v tv80_reg.v
# make sim DEFS=+define+VRAM_SDRAM   la VRAM en la SDRAM, como en la SiDi
# (hace falta make clean al cambiar DEFS)
DEFS ?=
VL  := verilator --binary --timing -Wno-fatal -Wno-lint -Wno-style -Wno-TIMESCALEMOD -I$(RTL)/upd7800 $(DEFS)

lint:
	@verilator --lint-only -Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
	    -Wno-PINCONNECTEMPTY -Wno-CASEINCOMPLETE -Wno-TIMESCALEMOD -Wno-fatal \
	    --top-module fp1100 -I$(RTL)/upd7800 $(DEFS) $(SRC) t80pa_stub.v 2>&1 | grep "^%" | grep -v upd7800 ; echo "lint: hecho"

build_sim/sim: $(SIM) $(SRC)
	@$(VL) --top-module tb_fp1100 -Mdir build_sim -o sim $(SIM) $(SRC) 2>&1 | grep "%Error" ; true

sim: build_sim/sim
	@build_sim/sim +CICLOS=40000000 | grep -v "crtc R"

teclas: build_sim/sim
	@build_sim/sim +CICLOS=40000000 +TECLEAR=1 | grep -v "crtc R"
	@python3 -c "from PIL import Image; import glob; n=max(int(f[6:-4]) for f in glob.glob('trama_*.ppm')); im=Image.open(f'trama_{n}.ppm').point(lambda v: v*255); im.save('trama_fin.png'); print('trama_fin.png')"

disco: build_sim/sim
	@python3 ../tools/d88toedsk.py --nuevo vacio.dsk
	@build_sim/sim +CICLOS=40000000 +DSK=vacio.dsk | grep -E "765|SD |slot_exp|fin:"

# make cpm DSK=../../discos/fp1000fl.dsk   arranca CP/M y teclea DIR
cpm: build_sim/sim
	@build_sim/sim +CICLOS=128000000 +DSK=$(DSK) +TECLEAR=2 | grep -E "fin:|volcada"

# ida y vuelta por la cinta (SAVE, NEW, LOAD, LIST) y volcado a hola.wav;
# luego cintawav carga ese WAV por el reproductor de fp1100_tape
cinta: build_sim/sim
	@build_sim/sim +CICLOS=40000000 +TECLEAR=3 | grep -E "CINTA|WAV|fin:"

cintawav: build_sim/sim
	@build_sim/sim +CICLOS=40000000 +TECLEAR=4 | grep -E "CINTA|WAV|fin:"

# make wav WAV=../../cintas/juego.wav   LOAD "CAS0:" desde un WAV por el
# reproductor del core; informa cada segundo de la posicion de la cinta.
# Lento: unos 2,5 minutos de simulacion por segundo de maquina.
wav: build_sim/sim
	@build_sim/sim +CICLOS=40000000 +TECLEAR=5 +WAV=$(WAV) | grep -a -E "CINTA|volcada|fin:"

clean:
	@rm -rf build_sim build_lint run_* *.vvp *.ppm *.png *.log vacio.dsk hola.wav

.PHONY: lint sim teclas wav clean
