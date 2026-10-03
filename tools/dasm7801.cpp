// Desensamblador uPD7801 sacado de upd7801.cpp de Takeda Toshiya (GPL).
// uso: dasm7801 <mem_64k.bin> <inicio_hex> <fin_hex>
#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include <cstring>
static uint8_t mem[65536];
static const char* sym(const char* fmt, unsigned v) { static char b[64]; snprintf(b, sizeof b, fmt, v); return b; }
uint8_t upd7801_dasm_ops[4];
int upd7801_dasm_ptr;

uint8_t getb()
{
	return upd7801_dasm_ops[upd7801_dasm_ptr++];
}

uint16_t getw()
{
	uint16_t l = getb();
	return l | (getb() << 8);
}

uint8_t getwa()
{
	return getb();
}

int dasm(uint32_t pc, char *buffer, size_t buffer_len)
{
	for(int i = 0; i < 4; i++) upd7801_dasm_ops[i] = mem[(pc + i) & 0xffff];
	upd7801_dasm_ptr = 0;
	
	uint8_t b;
	uint16_t wa;
	
	switch(b = getb()) {
	case 0x00: snprintf(buffer, buffer_len, ("nop")); break;
	case 0x01: snprintf(buffer, buffer_len, ("hlt")); break;
	case 0x02: snprintf(buffer, buffer_len, ("inx sp")); break;
	case 0x03: snprintf(buffer, buffer_len, ("dcx sp")); break;
	case 0x04: snprintf(buffer, buffer_len, ("lxi sp,%s"), sym(("%04xh"), getw())); break;
	case 0x05: wa = getwa(); snprintf(buffer, buffer_len, ("aniw v.%02xh,%02xh"), wa, getb()); break;
//	case 0x06:
	case 0x07: snprintf(buffer, buffer_len, ("ani a,%02xh"), getb()); break;
	case 0x08: snprintf(buffer, buffer_len, ("ret")); break;
	case 0x09: snprintf(buffer, buffer_len, ("sio")); break;
	case 0x0a: snprintf(buffer, buffer_len, ("mov a,b")); break;
	case 0x0b: snprintf(buffer, buffer_len, ("mov a,c")); break;
	case 0x0c: snprintf(buffer, buffer_len, ("mov a,d")); break;
	case 0x0d: snprintf(buffer, buffer_len, ("mov a,e")); break;
	case 0x0e: snprintf(buffer, buffer_len, ("mov a,h")); break;
	case 0x0f: snprintf(buffer, buffer_len, ("mov a,l")); break;
	
	case 0x10: snprintf(buffer, buffer_len, ("ex")); break;
	case 0x11: snprintf(buffer, buffer_len, ("exx")); break;
	case 0x12: snprintf(buffer, buffer_len, ("inx b")); break;
	case 0x13: snprintf(buffer, buffer_len, ("dcx b")); break;
	case 0x14: snprintf(buffer, buffer_len, ("lxi b,%s"), sym(("%04xh"), getw())); break;
	case 0x15: wa = getwa(); snprintf(buffer, buffer_len, ("oriw v.%02xh,%02xh"), wa, getb()); break;
	case 0x16: snprintf(buffer, buffer_len, ("xri a,%02xh"), getb()); break;
	case 0x17: snprintf(buffer, buffer_len, ("ori a,%02xh"), getb()); break;
	case 0x18: snprintf(buffer, buffer_len, ("rets")); break;
	case 0x19: snprintf(buffer, buffer_len, ("stm")); break;
	case 0x1a: snprintf(buffer, buffer_len, ("mov b,a")); break;
	case 0x1b: snprintf(buffer, buffer_len, ("mov c,a")); break;
	case 0x1c: snprintf(buffer, buffer_len, ("mov d,a")); break;
	case 0x1d: snprintf(buffer, buffer_len, ("mov e,a")); break;
	case 0x1e: snprintf(buffer, buffer_len, ("mov h,a")); break;
	case 0x1f: snprintf(buffer, buffer_len, ("mov l,a")); break;
	
	case 0x20: snprintf(buffer, buffer_len, ("inrw v.%02xh"), getwa()); break;
	case 0x21: snprintf(buffer, buffer_len, ("table")); break;
	case 0x22: snprintf(buffer, buffer_len, ("inx d")); break;
	case 0x23: snprintf(buffer, buffer_len, ("dcx d")); break;
	case 0x24: snprintf(buffer, buffer_len, ("lxi d,%s"), sym(("%04xh"), getw())); break;
	case 0x25: wa = getwa(); snprintf(buffer, buffer_len, ("gtiw v.%02xh,%02xh"), wa, getb()); break;
	case 0x26: snprintf(buffer, buffer_len, ("adinc a,%02xh"), getb()); break;
	case 0x27: snprintf(buffer, buffer_len, ("gti a,%02xh"), getb()); break;
	case 0x28: snprintf(buffer, buffer_len, ("ldaw v.%02xh"), getwa()); break;
	case 0x29: snprintf(buffer, buffer_len, ("ldax b")); break;
	case 0x2a: snprintf(buffer, buffer_len, ("ldax d")); break;
	case 0x2b: snprintf(buffer, buffer_len, ("ldax h")); break;
	case 0x2c: snprintf(buffer, buffer_len, ("ldax d+")); break;
	case 0x2d: snprintf(buffer, buffer_len, ("ldax h+")); break;
	case 0x2e: snprintf(buffer, buffer_len, ("ldax d-")); break;
	case 0x2f: snprintf(buffer, buffer_len, ("ldax h-")); break;
	
	case 0x30: snprintf(buffer, buffer_len, ("dcrw v.%02xh"), getwa()); break;
	case 0x31: snprintf(buffer, buffer_len, ("block")); break;
	case 0x32: snprintf(buffer, buffer_len, ("inx h")); break;
	case 0x33: snprintf(buffer, buffer_len, ("dcx h")); break;
	case 0x34: snprintf(buffer, buffer_len, ("lxi h,%s"), sym(("%04xh"), getw())); break;
	case 0x35: wa = getwa(); snprintf(buffer, buffer_len, ("ltiw v.%02xh,%02xh"), wa, getb()); break;
	case 0x36: snprintf(buffer, buffer_len, ("suinb a,%02xh"), getb()); break;
	case 0x37: snprintf(buffer, buffer_len, ("lti a,%02xh"), getb()); break;
	case 0x38: snprintf(buffer, buffer_len, ("staw v.%02xh"), getwa()); break;
	case 0x39: snprintf(buffer, buffer_len, ("stax b")); break;
	case 0x3a: snprintf(buffer, buffer_len, ("stax d")); break;
	case 0x3b: snprintf(buffer, buffer_len, ("stax h")); break;
	case 0x3c: snprintf(buffer, buffer_len, ("stax d+")); break;
	case 0x3d: snprintf(buffer, buffer_len, ("stax h+")); break;
	case 0x3e: snprintf(buffer, buffer_len, ("stax d-")); break;
	case 0x3f: snprintf(buffer, buffer_len, ("stax h-")); break;
	
//	case 0x40:
	case 0x41: snprintf(buffer, buffer_len, ("inr a")); break;
	case 0x42: snprintf(buffer, buffer_len, ("inr b")); break;
	case 0x43: snprintf(buffer, buffer_len, ("inr c")); break;
	case 0x44: snprintf(buffer, buffer_len, ("call %s"), sym(("%04xh"), getw())); break;
	case 0x45: wa = getwa(); snprintf(buffer, buffer_len, ("oniw v.%02xh,%02xh"), wa, getb()); break;
	case 0x46: snprintf(buffer, buffer_len, ("adi a,%02xh"), getb()); break;
	case 0x47: snprintf(buffer, buffer_len, ("oni a,%02xh"), getb()); break;
	case 0x48:
		switch(b = getb()) {
		case 0x00: snprintf(buffer, buffer_len, ("skit intf0")); break;
		case 0x01: snprintf(buffer, buffer_len, ("skit intft")); break;
		case 0x02: snprintf(buffer, buffer_len, ("skit intf1")); break;
		case 0x03: snprintf(buffer, buffer_len, ("skit intf2")); break;
		case 0x04: snprintf(buffer, buffer_len, ("skit intfs")); break;
		case 0x0a: snprintf(buffer, buffer_len, ("sk cy")); break;
		case 0x0c: snprintf(buffer, buffer_len, ("sk z")); break;
		case 0x0e: snprintf(buffer, buffer_len, ("push v")); break;
		case 0x0f: snprintf(buffer, buffer_len, ("pop v")); break;
		case 0x10: snprintf(buffer, buffer_len, ("sknit f0")); break;
		case 0x11: snprintf(buffer, buffer_len, ("sknit ft")); break;
		case 0x12: snprintf(buffer, buffer_len, ("sknit f1")); break;
		case 0x13: snprintf(buffer, buffer_len, ("sknit f2")); break;
		case 0x14: snprintf(buffer, buffer_len, ("sknit fs")); break;
		case 0x1a: snprintf(buffer, buffer_len, ("skn cy")); break;
		case 0x1c: snprintf(buffer, buffer_len, ("skn z")); break;
		case 0x1e: snprintf(buffer, buffer_len, ("push b")); break;
		case 0x1f: snprintf(buffer, buffer_len, ("pop b")); break;
		case 0x20: snprintf(buffer, buffer_len, ("ei")); break;
		case 0x24: snprintf(buffer, buffer_len, ("di")); break;
		case 0x2a: snprintf(buffer, buffer_len, ("clc")); break;
		case 0x2b: snprintf(buffer, buffer_len, ("stc")); break;
		case 0x2c: snprintf(buffer, buffer_len, ("pen")); break;
		case 0x2d: snprintf(buffer, buffer_len, ("pex")); break;
		case 0x2e: snprintf(buffer, buffer_len, ("push d")); break;
		case 0x2f: snprintf(buffer, buffer_len, ("pop d")); break;
		case 0x30: snprintf(buffer, buffer_len, ("rll a")); break;
		case 0x31: snprintf(buffer, buffer_len, ("rlr a")); break;
		case 0x32: snprintf(buffer, buffer_len, ("rll c")); break;
		case 0x33: snprintf(buffer, buffer_len, ("rlr c")); break;
		case 0x34: snprintf(buffer, buffer_len, ("sll a")); break;
		case 0x35: snprintf(buffer, buffer_len, ("slr a")); break;
		case 0x36: snprintf(buffer, buffer_len, ("sll c")); break;
		case 0x37: snprintf(buffer, buffer_len, ("sll c")); break;
		case 0x38: snprintf(buffer, buffer_len, ("rld")); break;
		case 0x39: snprintf(buffer, buffer_len, ("rrd")); break;
		case 0x3c: snprintf(buffer, buffer_len, ("per")); break;
		case 0x3e: snprintf(buffer, buffer_len, ("push h")); break;
		case 0x3f: snprintf(buffer, buffer_len, ("pop h")); break;
		default: snprintf(buffer, buffer_len, ("db 48h,%02xh"), b);
		}
		break;
	case 0x49: snprintf(buffer, buffer_len, ("mvix b,%02xh"), getb()); break;
	case 0x4a: snprintf(buffer, buffer_len, ("mvix d,%02xh"), getb()); break;
	case 0x4b: snprintf(buffer, buffer_len, ("mvix h,%02xh"), getb()); break;
	case 0x4c:
		switch(b = getb()) {
		case 0xc0: snprintf(buffer, buffer_len, ("mov a,pa")); break;
		case 0xc1: snprintf(buffer, buffer_len, ("mov a,pb")); break;
		case 0xc2: snprintf(buffer, buffer_len, ("mov a,pc")); break;
		case 0xc3: snprintf(buffer, buffer_len, ("mov a,mk")); break;
		case 0xc4: snprintf(buffer, buffer_len, ("mov a,mb")); break;	// 未定義?
		case 0xc5: snprintf(buffer, buffer_len, ("mov a,mc")); break;	// 未定義?
		case 0xc6: snprintf(buffer, buffer_len, ("mov a,tm0")); break;	// 未定義?
		case 0xc7: snprintf(buffer, buffer_len, ("mov a,tm1")); break;	// 未定義?
		case 0xc8: snprintf(buffer, buffer_len, ("mov a,s")); break;
		default:
			if(b < 0xc0) {
				snprintf(buffer, buffer_len, ("in %02xh"), getb()); break;
			}
			snprintf(buffer, buffer_len, ("db 4ch,%02xh"), b);
		}
		break;
	case 0x4d:
		switch(b = getb()) {
		case 0xc0: snprintf(buffer, buffer_len, ("mov pa,a")); break;
		case 0xc1: snprintf(buffer, buffer_len, ("mov pb,a")); break;
		case 0xc2: snprintf(buffer, buffer_len, ("mov pc,a")); break;
		case 0xc3: snprintf(buffer, buffer_len, ("mov mk,a")); break;
		case 0xc4: snprintf(buffer, buffer_len, ("mov mb,a")); break;
		case 0xc5: snprintf(buffer, buffer_len, ("mov mc,a")); break;
		case 0xc6: snprintf(buffer, buffer_len, ("mov tm0,a")); break;
		case 0xc7: snprintf(buffer, buffer_len, ("mov tm1,a")); break;
		case 0xc8: snprintf(buffer, buffer_len, ("mov s,a")); break;
		default:
			if(b < 0xc0) {
				snprintf(buffer, buffer_len, ("out %02xh"), getb()); break;
			}
			snprintf(buffer, buffer_len, ("db 4dh,%02xh"), b);
		}
		break;
	case 0x4e: b = getb(); snprintf(buffer, buffer_len, ("jre %s"), sym(("%04xh"), pc + upd7801_dasm_ptr + b)); break;
	case 0x4f: b = getb(); snprintf(buffer, buffer_len, ("jre %s"), sym(("%04xh"), (pc + upd7801_dasm_ptr + b - 256) & 0xffff)); break;
	
//	case 0x50:
	case 0x51: snprintf(buffer, buffer_len, ("dcr a")); break;
	case 0x52: snprintf(buffer, buffer_len, ("dcr b")); break;
	case 0x53: snprintf(buffer, buffer_len, ("dcr c")); break;
	case 0x54: snprintf(buffer, buffer_len, ("jmp %s"), sym(("%04xh"), getw())); break;
	case 0x55: wa = getwa(); snprintf(buffer, buffer_len, ("offiw v.%02xh,%02xh"), wa, getb()); break;
	case 0x56: snprintf(buffer, buffer_len, ("aci a,%02xh"), getb()); break;
	case 0x57: snprintf(buffer, buffer_len, ("offi a,%02xh"), getb()); break;
	case 0x58: snprintf(buffer, buffer_len, ("bit 0,v.%02xh"), getwa()); break;
	case 0x59: snprintf(buffer, buffer_len, ("bit 1,v.%02xh"), getwa()); break;
	case 0x5a: snprintf(buffer, buffer_len, ("bit 2,v.%02xh"), getwa()); break;
	case 0x5b: snprintf(buffer, buffer_len, ("bit 3,v.%02xh"), getwa()); break;
	case 0x5c: snprintf(buffer, buffer_len, ("bit 4,v.%02xh"), getwa()); break;
	case 0x5d: snprintf(buffer, buffer_len, ("bit 5,v.%02xh"), getwa()); break;
	case 0x5e: snprintf(buffer, buffer_len, ("bit 6,v.%02xh"), getwa()); break;
	case 0x5f: snprintf(buffer, buffer_len, ("bit 7,v.%02xh"), getwa()); break;
	
	case 0x60:
		switch(b = getb()) {
		case 0x08: snprintf(buffer, buffer_len, ("ana v,a")); break;
		case 0x09: snprintf(buffer, buffer_len, ("ana a,a")); break;
		case 0x0a: snprintf(buffer, buffer_len, ("ana b,a")); break;
		case 0x0b: snprintf(buffer, buffer_len, ("ana c,a")); break;
		case 0x0c: snprintf(buffer, buffer_len, ("ana d,a")); break;
		case 0x0d: snprintf(buffer, buffer_len, ("ana e,a")); break;
		case 0x0e: snprintf(buffer, buffer_len, ("ana h,a")); break;
		case 0x0f: snprintf(buffer, buffer_len, ("ana l,a")); break;
		case 0x10: snprintf(buffer, buffer_len, ("xra v,a")); break;
		case 0x11: snprintf(buffer, buffer_len, ("xra a,a")); break;
		case 0x12: snprintf(buffer, buffer_len, ("xra b,a")); break;
		case 0x13: snprintf(buffer, buffer_len, ("xra c,a")); break;
		case 0x14: snprintf(buffer, buffer_len, ("xra d,a")); break;
		case 0x15: snprintf(buffer, buffer_len, ("xra e,a")); break;
		case 0x16: snprintf(buffer, buffer_len, ("xra h,a")); break;
		case 0x17: snprintf(buffer, buffer_len, ("xra l,a")); break;
		case 0x18: snprintf(buffer, buffer_len, ("ora v,a")); break;
		case 0x19: snprintf(buffer, buffer_len, ("ora a,a")); break;
		case 0x1a: snprintf(buffer, buffer_len, ("ora b,a")); break;
		case 0x1b: snprintf(buffer, buffer_len, ("ora c,a")); break;
		case 0x1c: snprintf(buffer, buffer_len, ("ora d,a")); break;
		case 0x1d: snprintf(buffer, buffer_len, ("ora e,a")); break;
		case 0x1e: snprintf(buffer, buffer_len, ("ora h,a")); break;
		case 0x1f: snprintf(buffer, buffer_len, ("ora l,a")); break;
		case 0x20: snprintf(buffer, buffer_len, ("addnc v,a")); break;
		case 0x21: snprintf(buffer, buffer_len, ("addnc a,a")); break;
		case 0x22: snprintf(buffer, buffer_len, ("addnc b,a")); break;
		case 0x23: snprintf(buffer, buffer_len, ("addnc c,a")); break;
		case 0x24: snprintf(buffer, buffer_len, ("addnc d,a")); break;
		case 0x25: snprintf(buffer, buffer_len, ("addnc e,a")); break;
		case 0x26: snprintf(buffer, buffer_len, ("addnc h,a")); break;
		case 0x27: snprintf(buffer, buffer_len, ("addnc l,a")); break;
		case 0x28: snprintf(buffer, buffer_len, ("gta v,a")); break;
		case 0x29: snprintf(buffer, buffer_len, ("gta a,a")); break;
		case 0x2a: snprintf(buffer, buffer_len, ("gta b,a")); break;
		case 0x2b: snprintf(buffer, buffer_len, ("gta c,a")); break;
		case 0x2c: snprintf(buffer, buffer_len, ("gta d,a")); break;
		case 0x2d: snprintf(buffer, buffer_len, ("gta e,a")); break;
		case 0x2e: snprintf(buffer, buffer_len, ("gta h,a")); break;
		case 0x2f: snprintf(buffer, buffer_len, ("gta l,a")); break;
		case 0x30: snprintf(buffer, buffer_len, ("subnb v,a")); break;
		case 0x31: snprintf(buffer, buffer_len, ("subnb a,a")); break;
		case 0x32: snprintf(buffer, buffer_len, ("subnb b,a")); break;
		case 0x33: snprintf(buffer, buffer_len, ("subnb c,a")); break;
		case 0x34: snprintf(buffer, buffer_len, ("subnb d,a")); break;
		case 0x35: snprintf(buffer, buffer_len, ("subnb e,a")); break;
		case 0x36: snprintf(buffer, buffer_len, ("subnb h,a")); break;
		case 0x37: snprintf(buffer, buffer_len, ("subnb l,a")); break;
		case 0x38: snprintf(buffer, buffer_len, ("lta v,a")); break;
		case 0x39: snprintf(buffer, buffer_len, ("lta a,a")); break;
		case 0x3a: snprintf(buffer, buffer_len, ("lta b,a")); break;
		case 0x3b: snprintf(buffer, buffer_len, ("lta c,a")); break;
		case 0x3c: snprintf(buffer, buffer_len, ("lta d,a")); break;
		case 0x3d: snprintf(buffer, buffer_len, ("lta e,a")); break;
		case 0x3e: snprintf(buffer, buffer_len, ("lta h,a")); break;
		case 0x3f: snprintf(buffer, buffer_len, ("lta l,a")); break;
		case 0x40: snprintf(buffer, buffer_len, ("add v,a")); break;
		case 0x41: snprintf(buffer, buffer_len, ("add a,a")); break;
		case 0x42: snprintf(buffer, buffer_len, ("add b,a")); break;
		case 0x43: snprintf(buffer, buffer_len, ("add c,a")); break;
		case 0x44: snprintf(buffer, buffer_len, ("add d,a")); break;
		case 0x45: snprintf(buffer, buffer_len, ("add e,a")); break;
		case 0x46: snprintf(buffer, buffer_len, ("add h,a")); break;
		case 0x47: snprintf(buffer, buffer_len, ("add l,a")); break;
		case 0x50: snprintf(buffer, buffer_len, ("adc v,a")); break;
		case 0x51: snprintf(buffer, buffer_len, ("adc a,a")); break;
		case 0x52: snprintf(buffer, buffer_len, ("adc b,a")); break;
		case 0x53: snprintf(buffer, buffer_len, ("adc c,a")); break;
		case 0x54: snprintf(buffer, buffer_len, ("adc d,a")); break;
		case 0x55: snprintf(buffer, buffer_len, ("adc e,a")); break;
		case 0x56: snprintf(buffer, buffer_len, ("adc h,a")); break;
		case 0x57: snprintf(buffer, buffer_len, ("adc l,a")); break;
		case 0x60: snprintf(buffer, buffer_len, ("sub v,a")); break;
		case 0x61: snprintf(buffer, buffer_len, ("sub a,a")); break;
		case 0x62: snprintf(buffer, buffer_len, ("sub b,a")); break;
		case 0x63: snprintf(buffer, buffer_len, ("sub c,a")); break;
		case 0x64: snprintf(buffer, buffer_len, ("sub d,a")); break;
		case 0x65: snprintf(buffer, buffer_len, ("sub e,a")); break;
		case 0x66: snprintf(buffer, buffer_len, ("sub h,a")); break;
		case 0x67: snprintf(buffer, buffer_len, ("sub l,a")); break;
		case 0x68: snprintf(buffer, buffer_len, ("nea v,a")); break;
		case 0x69: snprintf(buffer, buffer_len, ("nea a,a")); break;
		case 0x6a: snprintf(buffer, buffer_len, ("nea b,a")); break;
		case 0x6b: snprintf(buffer, buffer_len, ("nea c,a")); break;
		case 0x6c: snprintf(buffer, buffer_len, ("nea d,a")); break;
		case 0x6d: snprintf(buffer, buffer_len, ("nea e,a")); break;
		case 0x6e: snprintf(buffer, buffer_len, ("nea h,a")); break;
		case 0x6f: snprintf(buffer, buffer_len, ("nea l,a")); break;
		case 0x70: snprintf(buffer, buffer_len, ("sbb v,a")); break;
		case 0x71: snprintf(buffer, buffer_len, ("sbb a,a")); break;
		case 0x72: snprintf(buffer, buffer_len, ("sbb b,a")); break;
		case 0x73: snprintf(buffer, buffer_len, ("sbb c,a")); break;
		case 0x74: snprintf(buffer, buffer_len, ("sbb d,a")); break;
		case 0x75: snprintf(buffer, buffer_len, ("sbb e,a")); break;
		case 0x76: snprintf(buffer, buffer_len, ("sbb h,a")); break;
		case 0x77: snprintf(buffer, buffer_len, ("sbb l,a")); break;
		case 0x78: snprintf(buffer, buffer_len, ("eqa v,a")); break;
		case 0x79: snprintf(buffer, buffer_len, ("eqa a,a")); break;
		case 0x7a: snprintf(buffer, buffer_len, ("eqa b,a")); break;
		case 0x7b: snprintf(buffer, buffer_len, ("eqa c,a")); break;
		case 0x7c: snprintf(buffer, buffer_len, ("eqa d,a")); break;
		case 0x7d: snprintf(buffer, buffer_len, ("eqa e,a")); break;
		case 0x7e: snprintf(buffer, buffer_len, ("eqa h,a")); break;
		case 0x7f: snprintf(buffer, buffer_len, ("eqa l,a")); break;
		case 0x88: snprintf(buffer, buffer_len, ("ana a,v")); break;
		case 0x89: snprintf(buffer, buffer_len, ("ana a,a")); break;
		case 0x8a: snprintf(buffer, buffer_len, ("ana a,b")); break;
		case 0x8b: snprintf(buffer, buffer_len, ("ana a,c")); break;
		case 0x8c: snprintf(buffer, buffer_len, ("ana a,d")); break;
		case 0x8d: snprintf(buffer, buffer_len, ("ana a,e")); break;
		case 0x8e: snprintf(buffer, buffer_len, ("ana a,h")); break;
		case 0x8f: snprintf(buffer, buffer_len, ("ana a,l")); break;
		case 0x90: snprintf(buffer, buffer_len, ("xra a,v")); break;
		case 0x91: snprintf(buffer, buffer_len, ("xra a,a")); break;
		case 0x92: snprintf(buffer, buffer_len, ("xra a,b")); break;
		case 0x93: snprintf(buffer, buffer_len, ("xra a,c")); break;
		case 0x94: snprintf(buffer, buffer_len, ("xra a,d")); break;
		case 0x95: snprintf(buffer, buffer_len, ("xra a,e")); break;
		case 0x96: snprintf(buffer, buffer_len, ("xra a,h")); break;
		case 0x97: snprintf(buffer, buffer_len, ("xra a,l")); break;
		case 0x98: snprintf(buffer, buffer_len, ("ora a,v")); break;
		case 0x99: snprintf(buffer, buffer_len, ("ora a,a")); break;
		case 0x9a: snprintf(buffer, buffer_len, ("ora a,b")); break;
		case 0x9b: snprintf(buffer, buffer_len, ("ora a,c")); break;
		case 0x9c: snprintf(buffer, buffer_len, ("ora a,d")); break;
		case 0x9d: snprintf(buffer, buffer_len, ("ora a,e")); break;
		case 0x9e: snprintf(buffer, buffer_len, ("ora a,h")); break;
		case 0x9f: snprintf(buffer, buffer_len, ("ora a,l")); break;
		case 0xa0: snprintf(buffer, buffer_len, ("addnc a,v")); break;
		case 0xa1: snprintf(buffer, buffer_len, ("addnc a,a")); break;
		case 0xa2: snprintf(buffer, buffer_len, ("addnc a,b")); break;
		case 0xa3: snprintf(buffer, buffer_len, ("addnc a,c")); break;
		case 0xa4: snprintf(buffer, buffer_len, ("addnc a,d")); break;
		case 0xa5: snprintf(buffer, buffer_len, ("addnc a,e")); break;
		case 0xa6: snprintf(buffer, buffer_len, ("addnc a,h")); break;
		case 0xa7: snprintf(buffer, buffer_len, ("addnc a,l")); break;
		case 0xa8: snprintf(buffer, buffer_len, ("gta a,v")); break;
		case 0xa9: snprintf(buffer, buffer_len, ("gta a,a")); break;
		case 0xaa: snprintf(buffer, buffer_len, ("gta a,b")); break;
		case 0xab: snprintf(buffer, buffer_len, ("gta a,c")); break;
		case 0xac: snprintf(buffer, buffer_len, ("gta a,d")); break;
		case 0xad: snprintf(buffer, buffer_len, ("gta a,e")); break;
		case 0xae: snprintf(buffer, buffer_len, ("gta a,h")); break;
		case 0xaf: snprintf(buffer, buffer_len, ("gta a,l")); break;
		case 0xb0: snprintf(buffer, buffer_len, ("subnb a,v")); break;
		case 0xb1: snprintf(buffer, buffer_len, ("subnb a,a")); break;
		case 0xb2: snprintf(buffer, buffer_len, ("subnb a,b")); break;
		case 0xb3: snprintf(buffer, buffer_len, ("subnb a,c")); break;
		case 0xb4: snprintf(buffer, buffer_len, ("subnb a,d")); break;
		case 0xb5: snprintf(buffer, buffer_len, ("subnb a,e")); break;
		case 0xb6: snprintf(buffer, buffer_len, ("subnb a,h")); break;
		case 0xb7: snprintf(buffer, buffer_len, ("subnb a,l")); break;
		case 0xb8: snprintf(buffer, buffer_len, ("lta a,v")); break;
		case 0xb9: snprintf(buffer, buffer_len, ("lta a,a")); break;
		case 0xba: snprintf(buffer, buffer_len, ("lta a,b")); break;
		case 0xbb: snprintf(buffer, buffer_len, ("lta a,c")); break;
		case 0xbc: snprintf(buffer, buffer_len, ("lta a,d")); break;
		case 0xbd: snprintf(buffer, buffer_len, ("lta a,e")); break;
		case 0xbe: snprintf(buffer, buffer_len, ("lta a,h")); break;
		case 0xbf: snprintf(buffer, buffer_len, ("lta a,l")); break;
		case 0xc0: snprintf(buffer, buffer_len, ("add a,v")); break;
		case 0xc1: snprintf(buffer, buffer_len, ("add a,a")); break;
		case 0xc2: snprintf(buffer, buffer_len, ("add a,b")); break;
		case 0xc3: snprintf(buffer, buffer_len, ("add a,c")); break;
		case 0xc4: snprintf(buffer, buffer_len, ("add a,d")); break;
		case 0xc5: snprintf(buffer, buffer_len, ("add a,e")); break;
		case 0xc6: snprintf(buffer, buffer_len, ("add a,h")); break;
		case 0xc7: snprintf(buffer, buffer_len, ("add a,l")); break;
		case 0xc8: snprintf(buffer, buffer_len, ("ona a,v")); break;
		case 0xc9: snprintf(buffer, buffer_len, ("ona a,a")); break;
		case 0xca: snprintf(buffer, buffer_len, ("ona a,b")); break;
		case 0xcb: snprintf(buffer, buffer_len, ("ona a,c")); break;
		case 0xcc: snprintf(buffer, buffer_len, ("ona a,d")); break;
		case 0xcd: snprintf(buffer, buffer_len, ("ona a,e")); break;
		case 0xce: snprintf(buffer, buffer_len, ("ona a,h")); break;
		case 0xcf: snprintf(buffer, buffer_len, ("ona a,l")); break;
		case 0xd0: snprintf(buffer, buffer_len, ("adc a,v")); break;
		case 0xd1: snprintf(buffer, buffer_len, ("adc a,a")); break;
		case 0xd2: snprintf(buffer, buffer_len, ("adc a,b")); break;
		case 0xd3: snprintf(buffer, buffer_len, ("adc a,c")); break;
		case 0xd4: snprintf(buffer, buffer_len, ("adc a,d")); break;
		case 0xd5: snprintf(buffer, buffer_len, ("adc a,e")); break;
		case 0xd6: snprintf(buffer, buffer_len, ("adc a,h")); break;
		case 0xd7: snprintf(buffer, buffer_len, ("adc a,l")); break;
		case 0xd8: snprintf(buffer, buffer_len, ("offa a,v")); break;
		case 0xd9: snprintf(buffer, buffer_len, ("offa a,a")); break;
		case 0xda: snprintf(buffer, buffer_len, ("offa a,b")); break;
		case 0xdb: snprintf(buffer, buffer_len, ("offa a,c")); break;
		case 0xdc: snprintf(buffer, buffer_len, ("offa a,d")); break;
		case 0xdd: snprintf(buffer, buffer_len, ("offa a,e")); break;
		case 0xde: snprintf(buffer, buffer_len, ("offa a,h")); break;
		case 0xdf: snprintf(buffer, buffer_len, ("offa a,l")); break;
		case 0xe0: snprintf(buffer, buffer_len, ("sub a,v")); break;
		case 0xe1: snprintf(buffer, buffer_len, ("sub a,a")); break;
		case 0xe2: snprintf(buffer, buffer_len, ("sub a,b")); break;
		case 0xe3: snprintf(buffer, buffer_len, ("sub a,c")); break;
		case 0xe4: snprintf(buffer, buffer_len, ("sub a,d")); break;
		case 0xe5: snprintf(buffer, buffer_len, ("sub a,e")); break;
		case 0xe6: snprintf(buffer, buffer_len, ("sub a,h")); break;
		case 0xe7: snprintf(buffer, buffer_len, ("sub a,l")); break;
		case 0xe8: snprintf(buffer, buffer_len, ("nea a,v")); break;
		case 0xe9: snprintf(buffer, buffer_len, ("nea a,a")); break;
		case 0xea: snprintf(buffer, buffer_len, ("nea a,b")); break;
		case 0xeb: snprintf(buffer, buffer_len, ("nea a,c")); break;
		case 0xec: snprintf(buffer, buffer_len, ("nea a,d")); break;
		case 0xed: snprintf(buffer, buffer_len, ("nea a,e")); break;
		case 0xee: snprintf(buffer, buffer_len, ("nea a,h")); break;
		case 0xef: snprintf(buffer, buffer_len, ("nea a,l")); break;
		case 0xf0: snprintf(buffer, buffer_len, ("sbb a,v")); break;
		case 0xf1: snprintf(buffer, buffer_len, ("sbb a,a")); break;
		case 0xf2: snprintf(buffer, buffer_len, ("sbb a,b")); break;
		case 0xf3: snprintf(buffer, buffer_len, ("sbb a,c")); break;
		case 0xf4: snprintf(buffer, buffer_len, ("sbb a,d")); break;
		case 0xf5: snprintf(buffer, buffer_len, ("sbb a,e")); break;
		case 0xf6: snprintf(buffer, buffer_len, ("sbb a,h")); break;
		case 0xf7: snprintf(buffer, buffer_len, ("sbb a,l")); break;
		case 0xf8: snprintf(buffer, buffer_len, ("eqa a,v")); break;
		case 0xf9: snprintf(buffer, buffer_len, ("eqa a,a")); break;
		case 0xfa: snprintf(buffer, buffer_len, ("eqa a,b")); break;
		case 0xfb: snprintf(buffer, buffer_len, ("eqa a,c")); break;
		case 0xfc: snprintf(buffer, buffer_len, ("eqa a,d")); break;
		case 0xfd: snprintf(buffer, buffer_len, ("eqa a,e")); break;
		case 0xfe: snprintf(buffer, buffer_len, ("eqa a,h")); break;
		case 0xff: snprintf(buffer, buffer_len, ("eqa a,l")); break;
		default: snprintf(buffer, buffer_len, ("db 60h,%02xh"), b);
		}
		break;
	case 0x61: snprintf(buffer, buffer_len, ("daa")); break;
	case 0x62: snprintf(buffer, buffer_len, ("reti")); break;
	case 0x63: snprintf(buffer, buffer_len, ("calb")); break;
	case 0x64:
		switch(b = getb()) {
		case 0x08: snprintf(buffer, buffer_len, ("ani v,%02xh"), getb()); break;
		case 0x09: snprintf(buffer, buffer_len, ("ani a,%02xh"), getb()); break;
		case 0x0a: snprintf(buffer, buffer_len, ("ani b,%02xh"), getb()); break;
		case 0x0b: snprintf(buffer, buffer_len, ("ani c,%02xh"), getb()); break;
		case 0x0c: snprintf(buffer, buffer_len, ("ani d,%02xh"), getb()); break;
		case 0x0d: snprintf(buffer, buffer_len, ("ani e,%02xh"), getb()); break;
		case 0x0e: snprintf(buffer, buffer_len, ("ani h,%02xh"), getb()); break;
		case 0x0f: snprintf(buffer, buffer_len, ("ani l,%02xh"), getb()); break;
		case 0x10: snprintf(buffer, buffer_len, ("xri v,%02xh"), getb()); break;
		case 0x11: snprintf(buffer, buffer_len, ("xri a,%02xh"), getb()); break;
		case 0x12: snprintf(buffer, buffer_len, ("xri b,%02xh"), getb()); break;
		case 0x13: snprintf(buffer, buffer_len, ("xri c,%02xh"), getb()); break;
		case 0x14: snprintf(buffer, buffer_len, ("xri d,%02xh"), getb()); break;
		case 0x15: snprintf(buffer, buffer_len, ("xri e,%02xh"), getb()); break;
		case 0x16: snprintf(buffer, buffer_len, ("xri h,%02xh"), getb()); break;
		case 0x17: snprintf(buffer, buffer_len, ("xri l,%02xh"), getb()); break;
		case 0x18: snprintf(buffer, buffer_len, ("ori v,%02xh"), getb()); break;
		case 0x19: snprintf(buffer, buffer_len, ("ori a,%02xh"), getb()); break;
		case 0x1a: snprintf(buffer, buffer_len, ("ori b,%02xh"), getb()); break;
		case 0x1b: snprintf(buffer, buffer_len, ("ori c,%02xh"), getb()); break;
		case 0x1c: snprintf(buffer, buffer_len, ("ori d,%02xh"), getb()); break;
		case 0x1d: snprintf(buffer, buffer_len, ("ori e,%02xh"), getb()); break;
		case 0x1e: snprintf(buffer, buffer_len, ("ori h,%02xh"), getb()); break;
		case 0x1f: snprintf(buffer, buffer_len, ("ori l,%02xh"), getb()); break;
		case 0x20: snprintf(buffer, buffer_len, ("adinc v,%02xh"), getb()); break;
		case 0x21: snprintf(buffer, buffer_len, ("adinc a,%02xh"), getb()); break;
		case 0x22: snprintf(buffer, buffer_len, ("adinc b,%02xh"), getb()); break;
		case 0x23: snprintf(buffer, buffer_len, ("adinc c,%02xh"), getb()); break;
		case 0x24: snprintf(buffer, buffer_len, ("adinc d,%02xh"), getb()); break;
		case 0x25: snprintf(buffer, buffer_len, ("adinc e,%02xh"), getb()); break;
		case 0x26: snprintf(buffer, buffer_len, ("adinc h,%02xh"), getb()); break;
		case 0x27: snprintf(buffer, buffer_len, ("adinc l,%02xh"), getb()); break;
		case 0x28: snprintf(buffer, buffer_len, ("gti v,%02xh"), getb()); break;
		case 0x29: snprintf(buffer, buffer_len, ("gti a,%02xh"), getb()); break;
		case 0x2a: snprintf(buffer, buffer_len, ("gti b,%02xh"), getb()); break;
		case 0x2b: snprintf(buffer, buffer_len, ("gti c,%02xh"), getb()); break;
		case 0x2c: snprintf(buffer, buffer_len, ("gti d,%02xh"), getb()); break;
		case 0x2d: snprintf(buffer, buffer_len, ("gti e,%02xh"), getb()); break;
		case 0x2e: snprintf(buffer, buffer_len, ("gti h,%02xh"), getb()); break;
		case 0x2f: snprintf(buffer, buffer_len, ("gti l,%02xh"), getb()); break;
		case 0x30: snprintf(buffer, buffer_len, ("suinb v,%02xh"), getb()); break;
		case 0x31: snprintf(buffer, buffer_len, ("suinb a,%02xh"), getb()); break;
		case 0x32: snprintf(buffer, buffer_len, ("suinb b,%02xh"), getb()); break;
		case 0x33: snprintf(buffer, buffer_len, ("suinb c,%02xh"), getb()); break;
		case 0x34: snprintf(buffer, buffer_len, ("suinb d,%02xh"), getb()); break;
		case 0x35: snprintf(buffer, buffer_len, ("suinb e,%02xh"), getb()); break;
		case 0x36: snprintf(buffer, buffer_len, ("suinb h,%02xh"), getb()); break;
		case 0x37: snprintf(buffer, buffer_len, ("suinb l,%02xh"), getb()); break;
		case 0x38: snprintf(buffer, buffer_len, ("lti v,%02xh"), getb()); break;
		case 0x39: snprintf(buffer, buffer_len, ("lti a,%02xh"), getb()); break;
		case 0x3a: snprintf(buffer, buffer_len, ("lti b,%02xh"), getb()); break;
		case 0x3b: snprintf(buffer, buffer_len, ("lti c,%02xh"), getb()); break;
		case 0x3c: snprintf(buffer, buffer_len, ("lti d,%02xh"), getb()); break;
		case 0x3d: snprintf(buffer, buffer_len, ("lti e,%02xh"), getb()); break;
		case 0x3e: snprintf(buffer, buffer_len, ("lti h,%02xh"), getb()); break;
		case 0x3f: snprintf(buffer, buffer_len, ("lti l,%02xh"), getb()); break;
		case 0x40: snprintf(buffer, buffer_len, ("adi v,%02xh"), getb()); break;
		case 0x41: snprintf(buffer, buffer_len, ("adi a,%02xh"), getb()); break;
		case 0x42: snprintf(buffer, buffer_len, ("adi b,%02xh"), getb()); break;
		case 0x43: snprintf(buffer, buffer_len, ("adi c,%02xh"), getb()); break;
		case 0x44: snprintf(buffer, buffer_len, ("adi d,%02xh"), getb()); break;
		case 0x45: snprintf(buffer, buffer_len, ("adi e,%02xh"), getb()); break;
		case 0x46: snprintf(buffer, buffer_len, ("adi h,%02xh"), getb()); break;
		case 0x47: snprintf(buffer, buffer_len, ("adi l,%02xh"), getb()); break;
		case 0x48: snprintf(buffer, buffer_len, ("oni v,%02xh"), getb()); break;
		case 0x49: snprintf(buffer, buffer_len, ("oni a,%02xh"), getb()); break;
		case 0x4a: snprintf(buffer, buffer_len, ("oni b,%02xh"), getb()); break;
		case 0x4b: snprintf(buffer, buffer_len, ("oni c,%02xh"), getb()); break;
		case 0x4c: snprintf(buffer, buffer_len, ("oni d,%02xh"), getb()); break;
		case 0x4d: snprintf(buffer, buffer_len, ("oni e,%02xh"), getb()); break;
		case 0x4e: snprintf(buffer, buffer_len, ("oni h,%02xh"), getb()); break;
		case 0x4f: snprintf(buffer, buffer_len, ("oni l,%02xh"), getb()); break;
		case 0x50: snprintf(buffer, buffer_len, ("aci v,%02xh"), getb()); break;
		case 0x51: snprintf(buffer, buffer_len, ("aci a,%02xh"), getb()); break;
		case 0x52: snprintf(buffer, buffer_len, ("aci b,%02xh"), getb()); break;
		case 0x53: snprintf(buffer, buffer_len, ("aci c,%02xh"), getb()); break;
		case 0x54: snprintf(buffer, buffer_len, ("aci d,%02xh"), getb()); break;
		case 0x55: snprintf(buffer, buffer_len, ("aci e,%02xh"), getb()); break;
		case 0x56: snprintf(buffer, buffer_len, ("aci h,%02xh"), getb()); break;
		case 0x57: snprintf(buffer, buffer_len, ("aci l,%02xh"), getb()); break;
		case 0x58: snprintf(buffer, buffer_len, ("offi v,%02xh"), getb()); break;
		case 0x59: snprintf(buffer, buffer_len, ("offi a,%02xh"), getb()); break;
		case 0x5a: snprintf(buffer, buffer_len, ("offi b,%02xh"), getb()); break;
		case 0x5b: snprintf(buffer, buffer_len, ("offi c,%02xh"), getb()); break;
		case 0x5c: snprintf(buffer, buffer_len, ("offi d,%02xh"), getb()); break;
		case 0x5d: snprintf(buffer, buffer_len, ("offi e,%02xh"), getb()); break;
		case 0x5e: snprintf(buffer, buffer_len, ("offi h,%02xh"), getb()); break;
		case 0x5f: snprintf(buffer, buffer_len, ("offi l,%02xh"), getb()); break;
		case 0x60: snprintf(buffer, buffer_len, ("sui v,%02xh"), getb()); break;
		case 0x61: snprintf(buffer, buffer_len, ("sui a,%02xh"), getb()); break;
		case 0x62: snprintf(buffer, buffer_len, ("sui b,%02xh"), getb()); break;
		case 0x63: snprintf(buffer, buffer_len, ("sui c,%02xh"), getb()); break;
		case 0x64: snprintf(buffer, buffer_len, ("sui d,%02xh"), getb()); break;
		case 0x65: snprintf(buffer, buffer_len, ("sui e,%02xh"), getb()); break;
		case 0x66: snprintf(buffer, buffer_len, ("sui h,%02xh"), getb()); break;
		case 0x67: snprintf(buffer, buffer_len, ("sui l,%02xh"), getb()); break;
		case 0x68: snprintf(buffer, buffer_len, ("nei v,%02xh"), getb()); break;
		case 0x69: snprintf(buffer, buffer_len, ("nei a,%02xh"), getb()); break;
		case 0x6a: snprintf(buffer, buffer_len, ("nei b,%02xh"), getb()); break;
		case 0x6b: snprintf(buffer, buffer_len, ("nei c,%02xh"), getb()); break;
		case 0x6c: snprintf(buffer, buffer_len, ("nei d,%02xh"), getb()); break;
		case 0x6d: snprintf(buffer, buffer_len, ("nei e,%02xh"), getb()); break;
		case 0x6e: snprintf(buffer, buffer_len, ("nei h,%02xh"), getb()); break;
		case 0x6f: snprintf(buffer, buffer_len, ("nei l,%02xh"), getb()); break;
		case 0x70: snprintf(buffer, buffer_len, ("sbi v,%02xh"), getb()); break;
		case 0x71: snprintf(buffer, buffer_len, ("sbi a,%02xh"), getb()); break;
		case 0x72: snprintf(buffer, buffer_len, ("sbi b,%02xh"), getb()); break;
		case 0x73: snprintf(buffer, buffer_len, ("sbi c,%02xh"), getb()); break;
		case 0x74: snprintf(buffer, buffer_len, ("sbi d,%02xh"), getb()); break;
		case 0x75: snprintf(buffer, buffer_len, ("sbi e,%02xh"), getb()); break;
		case 0x76: snprintf(buffer, buffer_len, ("sbi h,%02xh"), getb()); break;
		case 0x77: snprintf(buffer, buffer_len, ("sbi l,%02xh"), getb()); break;
		case 0x78: snprintf(buffer, buffer_len, ("eqi v,%02xh"), getb()); break;
		case 0x79: snprintf(buffer, buffer_len, ("eqi a,%02xh"), getb()); break;
		case 0x7a: snprintf(buffer, buffer_len, ("eqi b,%02xh"), getb()); break;
		case 0x7b: snprintf(buffer, buffer_len, ("eqi c,%02xh"), getb()); break;
		case 0x7c: snprintf(buffer, buffer_len, ("eqi d,%02xh"), getb()); break;
		case 0x7d: snprintf(buffer, buffer_len, ("eqi e,%02xh"), getb()); break;
		case 0x7e: snprintf(buffer, buffer_len, ("eqi h,%02xh"), getb()); break;
		case 0x7f: snprintf(buffer, buffer_len, ("eqi l,%02xh"), getb()); break;
		case 0x88: snprintf(buffer, buffer_len, ("ani pa,%02xh"), getb()); break;
		case 0x89: snprintf(buffer, buffer_len, ("ani pb,%02xh"), getb()); break;
		case 0x8a: snprintf(buffer, buffer_len, ("ani pc,%02xh"), getb()); break;
		case 0x8b: snprintf(buffer, buffer_len, ("ani mk,%02xh"), getb()); break;
		case 0x90: snprintf(buffer, buffer_len, ("xri pa,%02xh"), getb()); break;
		case 0x91: snprintf(buffer, buffer_len, ("xri pb,%02xh"), getb()); break;
		case 0x92: snprintf(buffer, buffer_len, ("xri pc,%02xh"), getb()); break;
		case 0x93: snprintf(buffer, buffer_len, ("xri mk,%02xh"), getb()); break;
		case 0x98: snprintf(buffer, buffer_len, ("ori pa,%02xh"), getb()); break;
		case 0x99: snprintf(buffer, buffer_len, ("ori pb,%02xh"), getb()); break;
		case 0x9a: snprintf(buffer, buffer_len, ("ori pc,%02xh"), getb()); break;
		case 0x9b: snprintf(buffer, buffer_len, ("ori mk,%02xh"), getb()); break;
		case 0xa0: snprintf(buffer, buffer_len, ("adinc pa,%02xh"), getb()); break;
		case 0xa1: snprintf(buffer, buffer_len, ("adinc pb,%02xh"), getb()); break;
		case 0xa2: snprintf(buffer, buffer_len, ("adinc pc,%02xh"), getb()); break;
		case 0xa3: snprintf(buffer, buffer_len, ("adinc mk,%02xh"), getb()); break;
		case 0xa8: snprintf(buffer, buffer_len, ("gti pa,%02xh"), getb()); break;
		case 0xa9: snprintf(buffer, buffer_len, ("gti pb,%02xh"), getb()); break;
		case 0xaa: snprintf(buffer, buffer_len, ("gti pc,%02xh"), getb()); break;
		case 0xab: snprintf(buffer, buffer_len, ("gti mk,%02xh"), getb()); break;
		case 0xb0: snprintf(buffer, buffer_len, ("suinb pa,%02xh"), getb()); break;
		case 0xb1: snprintf(buffer, buffer_len, ("suinb pb,%02xh"), getb()); break;
		case 0xb2: snprintf(buffer, buffer_len, ("suinb pc,%02xh"), getb()); break;
		case 0xb3: snprintf(buffer, buffer_len, ("suinb mk,%02xh"), getb()); break;
		case 0xb8: snprintf(buffer, buffer_len, ("lti pa,%02xh"), getb()); break;
		case 0xb9: snprintf(buffer, buffer_len, ("lti pb,%02xh"), getb()); break;
		case 0xba: snprintf(buffer, buffer_len, ("lti pc,%02xh"), getb()); break;
		case 0xbb: snprintf(buffer, buffer_len, ("lti mk,%02xh"), getb()); break;
		case 0xc0: snprintf(buffer, buffer_len, ("adi pa,%02xh"), getb()); break;
		case 0xc1: snprintf(buffer, buffer_len, ("adi pb,%02xh"), getb()); break;
		case 0xc2: snprintf(buffer, buffer_len, ("adi pc,%02xh"), getb()); break;
		case 0xc3: snprintf(buffer, buffer_len, ("adi mk,%02xh"), getb()); break;
		case 0xc8: snprintf(buffer, buffer_len, ("oni pa,%02xh"), getb()); break;
		case 0xc9: snprintf(buffer, buffer_len, ("oni pb,%02xh"), getb()); break;
		case 0xca: snprintf(buffer, buffer_len, ("oni pc,%02xh"), getb()); break;
		case 0xcb: snprintf(buffer, buffer_len, ("oni mk,%02xh"), getb()); break;
		case 0xd0: snprintf(buffer, buffer_len, ("aci pa,%02xh"), getb()); break;
		case 0xd1: snprintf(buffer, buffer_len, ("aci pb,%02xh"), getb()); break;
		case 0xd2: snprintf(buffer, buffer_len, ("aci pc,%02xh"), getb()); break;
		case 0xd3: snprintf(buffer, buffer_len, ("aci mk,%02xh"), getb()); break;
		case 0xd8: snprintf(buffer, buffer_len, ("offi pa,%02xh"), getb()); break;
		case 0xd9: snprintf(buffer, buffer_len, ("offi pb,%02xh"), getb()); break;
		case 0xda: snprintf(buffer, buffer_len, ("offi pc,%02xh"), getb()); break;
		case 0xdb: snprintf(buffer, buffer_len, ("offi mk,%02xh"), getb()); break;
		case 0xe0: snprintf(buffer, buffer_len, ("sui pa,%02xh"), getb()); break;
		case 0xe1: snprintf(buffer, buffer_len, ("sui pb,%02xh"), getb()); break;
		case 0xe2: snprintf(buffer, buffer_len, ("sui pc,%02xh"), getb()); break;
		case 0xe3: snprintf(buffer, buffer_len, ("sui mk,%02xh"), getb()); break;
		case 0xe8: snprintf(buffer, buffer_len, ("nei pa,%02xh"), getb()); break;
		case 0xe9: snprintf(buffer, buffer_len, ("nei pb,%02xh"), getb()); break;
		case 0xea: snprintf(buffer, buffer_len, ("nei pc,%02xh"), getb()); break;
		case 0xeb: snprintf(buffer, buffer_len, ("nei mk,%02xh"), getb()); break;
		case 0xf0: snprintf(buffer, buffer_len, ("sbi pa,%02xh"), getb()); break;
		case 0xf1: snprintf(buffer, buffer_len, ("sbi pb,%02xh"), getb()); break;
		case 0xf2: snprintf(buffer, buffer_len, ("sbi pc,%02xh"), getb()); break;
		case 0xf3: snprintf(buffer, buffer_len, ("sbi mk,%02xh"), getb()); break;
		case 0xf8: snprintf(buffer, buffer_len, ("eqi pa,%02xh"), getb()); break;
		case 0xf9: snprintf(buffer, buffer_len, ("eqi pb,%02xh"), getb()); break;
		case 0xfa: snprintf(buffer, buffer_len, ("eqi pc,%02xh"), getb()); break;
		case 0xfb: snprintf(buffer, buffer_len, ("eqi mk,%02xh"), getb()); break;
		default: snprintf(buffer, buffer_len, ("db 64h,%02xh"), b);
		}
		break;
	case 0x65: wa = getwa(); snprintf(buffer, buffer_len, ("neiw v.%02xh,%02xh"), wa, getb()); break;
	case 0x66: snprintf(buffer, buffer_len, ("sui a,%02xh"), getb()); break;
	case 0x67: snprintf(buffer, buffer_len, ("nei a,%02xh"), getb()); break;
	case 0x68: snprintf(buffer, buffer_len, ("mvi v,%02xh"), getb()); break;
	case 0x69: snprintf(buffer, buffer_len, ("mvi a,%02xh"), getb()); break;
	case 0x6a: snprintf(buffer, buffer_len, ("mvi b,%02xh"), getb()); break;
	case 0x6b: snprintf(buffer, buffer_len, ("mvi c,%02xh"), getb()); break;
	case 0x6c: snprintf(buffer, buffer_len, ("mvi d,%02xh"), getb()); break;
	case 0x6d: snprintf(buffer, buffer_len, ("mvi e,%02xh"), getb()); break;
	case 0x6e: snprintf(buffer, buffer_len, ("mvi h,%02xh"), getb()); break;
	case 0x6f: snprintf(buffer, buffer_len, ("mvi l,%02xh"), getb()); break;
	
	case 0x70:
		switch(b = getb()) {
		case 0x0e: snprintf(buffer, buffer_len, ("sspd %s"), sym(("%04xh"), getw())); break;
		case 0x0f: snprintf(buffer, buffer_len, ("lspd %s"), sym(("%04xh"), getw())); break;
		case 0x1e: snprintf(buffer, buffer_len, ("sbcd %s"), sym(("%04xh"), getw())); break;
		case 0x1f: snprintf(buffer, buffer_len, ("lbcd %s"), sym(("%04xh"), getw())); break;
		case 0x2e: snprintf(buffer, buffer_len, ("sded %s"), sym(("%04xh"), getw())); break;
		case 0x2f: snprintf(buffer, buffer_len, ("lded %s"), sym(("%04xh"), getw())); break;
		case 0x3e: snprintf(buffer, buffer_len, ("shld %s"), sym(("%04xh"), getw())); break;
		case 0x3f: snprintf(buffer, buffer_len, ("lhld %s"), sym(("%04xh"), getw())); break;
		case 0x68: snprintf(buffer, buffer_len, ("mov v,%s"), sym(("%04xh"), getw())); break;
		case 0x69: snprintf(buffer, buffer_len, ("mov a,%s"), sym(("%04xh"), getw())); break;
		case 0x6a: snprintf(buffer, buffer_len, ("mov b,%s"), sym(("%04xh"), getw())); break;
		case 0x6b: snprintf(buffer, buffer_len, ("mov c,%s"), sym(("%04xh"), getw())); break;
		case 0x6c: snprintf(buffer, buffer_len, ("mov d,%s"), sym(("%04xh"), getw())); break;
		case 0x6d: snprintf(buffer, buffer_len, ("mov e,%s"), sym(("%04xh"), getw())); break;
		case 0x6e: snprintf(buffer, buffer_len, ("mov h,%s"), sym(("%04xh"), getw())); break;
		case 0x6f: snprintf(buffer, buffer_len, ("mov l,%s"), sym(("%04xh"), getw())); break;
		case 0x78: snprintf(buffer, buffer_len, ("mov %s,v"), sym(("%04xh"), getw())); break;
		case 0x79: snprintf(buffer, buffer_len, ("mov %s,a"), sym(("%04xh"), getw())); break;
		case 0x7a: snprintf(buffer, buffer_len, ("mov %s,b"), sym(("%04xh"), getw())); break;
		case 0x7b: snprintf(buffer, buffer_len, ("mov %s,c"), sym(("%04xh"), getw())); break;
		case 0x7c: snprintf(buffer, buffer_len, ("mov %s,d"), sym(("%04xh"), getw())); break;
		case 0x7d: snprintf(buffer, buffer_len, ("mov %s,e"), sym(("%04xh"), getw())); break;
		case 0x7e: snprintf(buffer, buffer_len, ("mov %s,h"), sym(("%04xh"), getw())); break;
		case 0x7f: snprintf(buffer, buffer_len, ("mov %s,l"), sym(("%04xh"), getw())); break;
		case 0x89: snprintf(buffer, buffer_len, ("anax b")); break;
		case 0x8a: snprintf(buffer, buffer_len, ("anax d")); break;
		case 0x8b: snprintf(buffer, buffer_len, ("anax h")); break;
		case 0x8c: snprintf(buffer, buffer_len, ("anax d+")); break;
		case 0x8d: snprintf(buffer, buffer_len, ("anax h+")); break;
		case 0x8e: snprintf(buffer, buffer_len, ("anax d-")); break;
		case 0x8f: snprintf(buffer, buffer_len, ("anax h-")); break;
		case 0x91: snprintf(buffer, buffer_len, ("xrax b")); break;
		case 0x92: snprintf(buffer, buffer_len, ("xrax d")); break;
		case 0x93: snprintf(buffer, buffer_len, ("xrax h")); break;
		case 0x94: snprintf(buffer, buffer_len, ("xrax d+")); break;
		case 0x95: snprintf(buffer, buffer_len, ("xrax h+")); break;
		case 0x96: snprintf(buffer, buffer_len, ("xrax d-")); break;
		case 0x97: snprintf(buffer, buffer_len, ("xrax h-")); break;
		case 0x99: snprintf(buffer, buffer_len, ("orax b")); break;
		case 0x9a: snprintf(buffer, buffer_len, ("orax d")); break;
		case 0x9b: snprintf(buffer, buffer_len, ("orax h")); break;
		case 0x9c: snprintf(buffer, buffer_len, ("orax d+")); break;
		case 0x9d: snprintf(buffer, buffer_len, ("orax h+")); break;
		case 0x9e: snprintf(buffer, buffer_len, ("orax d-")); break;
		case 0x9f: snprintf(buffer, buffer_len, ("orax h-")); break;
		case 0xa1: snprintf(buffer, buffer_len, ("addncx b")); break;
		case 0xa2: snprintf(buffer, buffer_len, ("addncx d")); break;
		case 0xa3: snprintf(buffer, buffer_len, ("addncx h")); break;
		case 0xa4: snprintf(buffer, buffer_len, ("addncx d+")); break;
		case 0xa5: snprintf(buffer, buffer_len, ("addncx h+")); break;
		case 0xa6: snprintf(buffer, buffer_len, ("addncx d-")); break;
		case 0xa7: snprintf(buffer, buffer_len, ("addncx h-")); break;
		case 0xa9: snprintf(buffer, buffer_len, ("gtax b")); break;
		case 0xaa: snprintf(buffer, buffer_len, ("gtax d")); break;
		case 0xab: snprintf(buffer, buffer_len, ("gtax h")); break;
		case 0xac: snprintf(buffer, buffer_len, ("gtax d+")); break;
		case 0xad: snprintf(buffer, buffer_len, ("gtax h+")); break;
		case 0xae: snprintf(buffer, buffer_len, ("gtax d-")); break;
		case 0xaf: snprintf(buffer, buffer_len, ("gtax h-")); break;
		case 0xb1: snprintf(buffer, buffer_len, ("subnbx b")); break;
		case 0xb2: snprintf(buffer, buffer_len, ("subnbx d")); break;
		case 0xb3: snprintf(buffer, buffer_len, ("subnbx h")); break;
		case 0xb4: snprintf(buffer, buffer_len, ("subnbx d+")); break;
		case 0xb5: snprintf(buffer, buffer_len, ("subnbx h+")); break;
		case 0xb6: snprintf(buffer, buffer_len, ("subnbx d-")); break;
		case 0xb7: snprintf(buffer, buffer_len, ("subnbx h-")); break;
		case 0xb9: snprintf(buffer, buffer_len, ("ltax b")); break;
		case 0xba: snprintf(buffer, buffer_len, ("ltax d")); break;
		case 0xbb: snprintf(buffer, buffer_len, ("ltax h")); break;
		case 0xbc: snprintf(buffer, buffer_len, ("ltax d+")); break;
		case 0xbd: snprintf(buffer, buffer_len, ("ltax h+")); break;
		case 0xbe: snprintf(buffer, buffer_len, ("ltax d-")); break;
		case 0xbf: snprintf(buffer, buffer_len, ("ltax h-")); break;
		case 0xc1: snprintf(buffer, buffer_len, ("addx b")); break;
		case 0xc2: snprintf(buffer, buffer_len, ("addx d")); break;
		case 0xc3: snprintf(buffer, buffer_len, ("addx h")); break;
		case 0xc4: snprintf(buffer, buffer_len, ("addx d+")); break;
		case 0xc5: snprintf(buffer, buffer_len, ("addx h+")); break;
		case 0xc6: snprintf(buffer, buffer_len, ("addx d-")); break;
		case 0xc7: snprintf(buffer, buffer_len, ("addx h-")); break;
		case 0xc9: snprintf(buffer, buffer_len, ("onax b")); break;
		case 0xca: snprintf(buffer, buffer_len, ("onax d")); break;
		case 0xcb: snprintf(buffer, buffer_len, ("onax h")); break;
		case 0xcc: snprintf(buffer, buffer_len, ("onax d+")); break;
		case 0xcd: snprintf(buffer, buffer_len, ("onax h+")); break;
		case 0xce: snprintf(buffer, buffer_len, ("onax d-")); break;
		case 0xcf: snprintf(buffer, buffer_len, ("onax h-")); break;
		case 0xd1: snprintf(buffer, buffer_len, ("adcx b")); break;
		case 0xd2: snprintf(buffer, buffer_len, ("adcx d")); break;
		case 0xd3: snprintf(buffer, buffer_len, ("adcx h")); break;
		case 0xd4: snprintf(buffer, buffer_len, ("adcx d+")); break;
		case 0xd5: snprintf(buffer, buffer_len, ("adcx h+")); break;
		case 0xd6: snprintf(buffer, buffer_len, ("adcx d-")); break;
		case 0xd7: snprintf(buffer, buffer_len, ("adcx h-")); break;
		case 0xd9: snprintf(buffer, buffer_len, ("offax b")); break;
		case 0xda: snprintf(buffer, buffer_len, ("offax d")); break;
		case 0xdb: snprintf(buffer, buffer_len, ("offax h")); break;
		case 0xdc: snprintf(buffer, buffer_len, ("offax d+")); break;
		case 0xdd: snprintf(buffer, buffer_len, ("offax h+")); break;
		case 0xde: snprintf(buffer, buffer_len, ("offax d-")); break;
		case 0xdf: snprintf(buffer, buffer_len, ("offax h-")); break;
		case 0xe1: snprintf(buffer, buffer_len, ("subx b")); break;
		case 0xe2: snprintf(buffer, buffer_len, ("subx d")); break;
		case 0xe3: snprintf(buffer, buffer_len, ("subx h")); break;
		case 0xe4: snprintf(buffer, buffer_len, ("subx d+")); break;
		case 0xe5: snprintf(buffer, buffer_len, ("subx h+")); break;
		case 0xe6: snprintf(buffer, buffer_len, ("subx d-")); break;
		case 0xe7: snprintf(buffer, buffer_len, ("subx h-")); break;
		case 0xe9: snprintf(buffer, buffer_len, ("neax b")); break;
		case 0xea: snprintf(buffer, buffer_len, ("neax d")); break;
		case 0xeb: snprintf(buffer, buffer_len, ("neax h")); break;
		case 0xec: snprintf(buffer, buffer_len, ("neax d+")); break;
		case 0xed: snprintf(buffer, buffer_len, ("neax h+")); break;
		case 0xee: snprintf(buffer, buffer_len, ("neax d-")); break;
		case 0xef: snprintf(buffer, buffer_len, ("neax h-")); break;
		case 0xf1: snprintf(buffer, buffer_len, ("sbbx b")); break;
		case 0xf2: snprintf(buffer, buffer_len, ("sbbx d")); break;
		case 0xf3: snprintf(buffer, buffer_len, ("sbbx h")); break;
		case 0xf4: snprintf(buffer, buffer_len, ("sbbx d+")); break;
		case 0xf5: snprintf(buffer, buffer_len, ("sbbx h+")); break;
		case 0xf6: snprintf(buffer, buffer_len, ("sbbx d-")); break;
		case 0xf7: snprintf(buffer, buffer_len, ("sbbx h-")); break;
		case 0xf9: snprintf(buffer, buffer_len, ("eqax b")); break;
		case 0xfa: snprintf(buffer, buffer_len, ("eqax d")); break;
		case 0xfb: snprintf(buffer, buffer_len, ("eqax h")); break;
		case 0xfc: snprintf(buffer, buffer_len, ("eqax d+")); break;
		case 0xfd: snprintf(buffer, buffer_len, ("eqax h+")); break;
		case 0xfe: snprintf(buffer, buffer_len, ("eqax d-")); break;
		case 0xff: snprintf(buffer, buffer_len, ("eqax h-")); break;
		default: snprintf(buffer, buffer_len, ("db 70h,%02xh"), b);
		}
		break;
	case 0x71: wa = getwa(); snprintf(buffer, buffer_len, ("mviw v.%02xh,%02xh"), wa, getb()); break;
	case 0x72: snprintf(buffer, buffer_len, ("softi")); break;
	case 0x73: snprintf(buffer, buffer_len, ("jb")); break;
	case 0x74:
		switch(b = getb()) {
		case 0x88: snprintf(buffer, buffer_len, ("anaw v.%02xh"), getwa()); break;
		case 0x90: snprintf(buffer, buffer_len, ("xraw v.%02xh"), getwa()); break;
		case 0x98: snprintf(buffer, buffer_len, ("oraw v.%02xh"), getwa()); break;
		case 0xa0: snprintf(buffer, buffer_len, ("addncw v.%02xh"), getwa()); break;
		case 0xa8: snprintf(buffer, buffer_len, ("gtaw v.%02xh"), getwa()); break;
		case 0xb0: snprintf(buffer, buffer_len, ("subnbw v.%02xh"), getwa()); break;
		case 0xb8: snprintf(buffer, buffer_len, ("ltaw v.%02xh"), getwa()); break;
		case 0xc0: snprintf(buffer, buffer_len, ("addw v.%02xh"), getwa()); break;
		case 0xc8: snprintf(buffer, buffer_len, ("onaw v.%02xh"), getwa()); break;
		case 0xd0: snprintf(buffer, buffer_len, ("adcw v.%02xh"), getwa()); break;
		case 0xd8: snprintf(buffer, buffer_len, ("offaw v.%02xh"), getwa()); break;
		case 0xe0: snprintf(buffer, buffer_len, ("subw v.%02xh"), getwa()); break;
		case 0xe8: snprintf(buffer, buffer_len, ("neaw v.%02xh"), getwa()); break;
		case 0xf0: snprintf(buffer, buffer_len, ("sbbw v.%02xh"), getwa()); break;
		case 0xf8: snprintf(buffer, buffer_len, ("eqaw v.%02xh"), getwa()); break;
		default: snprintf(buffer, buffer_len, ("db 74h,%02xh"), b);
		}
		break;
	case 0x75: wa = getwa(); snprintf(buffer, buffer_len, ("eqiw v.%02xh,%02xh"), wa, getb()); break;
	case 0x76: snprintf(buffer, buffer_len, ("sbi a,%02xh"), getb()); break;
	case 0x77: snprintf(buffer, buffer_len, ("eqi a,%02xh"), getb()); break;
	case 0x78: case 0x79: case 0x7a: case 0x7b: case 0x7c: case 0x7d: case 0x7e: case 0x7f:
		snprintf(buffer, buffer_len, ("calf %3x"), 0x800 | ((b & 7) << 8) | getb()); break;
	
	case 0x80: case 0x81: case 0x82: case 0x83: case 0x84: case 0x85: case 0x86: case 0x87:
	case 0x88: case 0x89: case 0x8a: case 0x8b: case 0x8c: case 0x8d: case 0x8e: case 0x8f:
	case 0x90: case 0x91: case 0x92: case 0x93: case 0x94: case 0x95: case 0x96: case 0x97:
	case 0x98: case 0x99: case 0x9a: case 0x9b: case 0x9c: case 0x9d: case 0x9e: case 0x9f:
	case 0xa0: case 0xa1: case 0xa2: case 0xa3: case 0xa4: case 0xa5: case 0xa6: case 0xa7:
	case 0xa8: case 0xa9: case 0xaa: case 0xab: case 0xac: case 0xad: case 0xae: case 0xaf:
	case 0xb0: case 0xb1: case 0xb2: case 0xb3: case 0xb4: case 0xb5: case 0xb6: case 0xb7:
	case 0xb8: case 0xb9: case 0xba: case 0xbb: case 0xbc: case 0xbd: case 0xbe: case 0xbf:
		snprintf(buffer, buffer_len, ("calt %02xh"), 0x80 | ((b & 0x3f) << 1)); break;
		
	case 0xc0: case 0xc1: case 0xc2: case 0xc3: case 0xc4: case 0xc5: case 0xc6: case 0xc7:
	case 0xc8: case 0xc9: case 0xca: case 0xcb: case 0xcc: case 0xcd: case 0xce: case 0xcf:
	case 0xd0: case 0xd1: case 0xd2: case 0xd3: case 0xd4: case 0xd5: case 0xd6: case 0xd7:
	case 0xd8: case 0xd9: case 0xda: case 0xdb: case 0xdc: case 0xdd: case 0xde: case 0xdf:
		snprintf(buffer, buffer_len, ("jr %s"), sym(("%04xh"), pc + upd7801_dasm_ptr + (b & 0x1f))); break;
	
	case 0xe0: case 0xe1: case 0xe2: case 0xe3: case 0xe4: case 0xe5: case 0xe6: case 0xe7:
	case 0xe8: case 0xe9: case 0xea: case 0xeb: case 0xec: case 0xed: case 0xee: case 0xef:
	case 0xf0: case 0xf1: case 0xf2: case 0xf3: case 0xf4: case 0xf5: case 0xf6: case 0xf7:
	case 0xf8: case 0xf9: case 0xfa: case 0xfb: case 0xfc: case 0xfd: case 0xfe: case 0xff:
		snprintf(buffer, buffer_len, ("jr %s"), sym(("%04xh"), pc + upd7801_dasm_ptr + ((b & 0x1f) - 0x20))); break;
	
	default: snprintf(buffer, buffer_len, ("db %02xh"), b); break;
	}
	return upd7801_dasm_ptr;
}
int main(int argc, char** argv) {
    if (argc < 4) { fprintf(stderr, "uso: %s mem64k.bin ini fin\n", argv[0]); return 1; }
    FILE* f = fopen(argv[1], "rb"); if (!f) return 1;
    memset(mem, 0xff, sizeof mem); size_t r = fread(mem, 1, 65536, f); (void)r; fclose(f);
    unsigned pc = strtoul(argv[2], 0, 16), fin = strtoul(argv[3], 0, 16);
    char buf[128];
    while (pc < fin) {
        int n = dasm(pc, buf, sizeof buf);
        printf("%04x  ", pc);
        for (int i = 0; i < 4; i++) printf(i < n ? "%02x " : "   ", mem[pc + i]);
        printf(" %s\n", buf);
        pc += n;
    }
    return 0;
}
