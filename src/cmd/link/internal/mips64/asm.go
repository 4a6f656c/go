// Inferno utils/5l/asm.c
// https://bitbucket.org/inferno-os/inferno-os/src/master/utils/5l/asm.c
//
//	Copyright © 1994-1999 Lucent Technologies Inc.  All rights reserved.
//	Portions Copyright © 1995-1997 C H Forsyth (forsyth@terzarima.net)
//	Portions Copyright © 1997-1999 Vita Nuova Limited
//	Portions Copyright © 2000-2007 Vita Nuova Holdings Limited (www.vitanuova.com)
//	Portions Copyright © 2004,2006 Bruce Ellis
//	Portions Copyright © 2005-2007 C H Forsyth (forsyth@terzarima.net)
//	Revisions Copyright © 2000-2007 Lucent Technologies Inc. and others
//	Portions Copyright © 2009 The Go Authors. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

package mips64

import (
	"cmd/internal/objabi"
	"cmd/internal/sys"
	"cmd/link/internal/ld"
	"cmd/link/internal/loader"
	"cmd/link/internal/sym"
	"debug/elf"
	"fmt"
)

func gentext(ctxt *ld.Link, ldr *loader.Loader) {}

func elfreloc1(ctxt *ld.Link, out *ld.OutBuf, ldr *loader.Loader, s loader.Sym, r loader.ExtReloc, ri int, sectoff int64) bool {

	// mips64 ELF relocation (endian neutral)
	//		offset	uint64
	//		sym		uint32
	//		ssym	uint8
	//		type3	uint8
	//		type2	uint8
	//		type	uint8
	//		addend	int64

	addend := r.Xadd

	out.Write64(uint64(sectoff))

	elfsym := ld.ElfSymForReloc(ctxt, r.Xsym)
	out.Write32(uint32(elfsym))
	out.Write8(0)
	if r.Type != objabi.R_MIPSGPRELHI && r.Type != objabi.R_MIPSGPRELLO {
		out.Write8(0)
		out.Write8(0)
	}
	switch r.Type {
	default:
		return false
	case objabi.R_ADDR, objabi.R_DWARFSECREF:
		switch r.Size {
		case 4:
			out.Write8(uint8(elf.R_MIPS_32))
		case 8:
			out.Write8(uint8(elf.R_MIPS_64))
		default:
			return false
		}
	case objabi.R_ADDRMIPS:
		out.Write8(uint8(elf.R_MIPS_LO16))
	case objabi.R_ADDRMIPSU:
		out.Write8(uint8(elf.R_MIPS_HI16))
	case objabi.R_ADDRMIPSTLS:
		out.Write8(uint8(elf.R_MIPS_TLS_TPREL_LO16))
		if ctxt.Target.IsOpenbsd() {
			// OpenBSD mips64 does not currently offset TLS by 0x7000,
			// as such we need to add this back to get the correct offset
			// via the external linker.
			addend += 0x7000
		}
	case objabi.R_CALLMIPS, objabi.R_JMPMIPS:
		out.Write8(uint8(elf.R_MIPS_26))
	case objabi.R_MIPSGPRELHI:
		out.Write8(uint8(elf.R_MIPS_HI16))
		out.Write8(uint8(elf.R_MIPS_SUB))
		out.Write8(uint8(elf.R_MIPS_GPREL16))
	case objabi.R_MIPSGPRELLO:
		out.Write8(uint8(elf.R_MIPS_LO16))
		out.Write8(uint8(elf.R_MIPS_SUB))
		out.Write8(uint8(elf.R_MIPS_GPREL16))
	case objabi.R_MIPSCALL16:
		out.Write8(uint8(elf.R_MIPS_CALL16))
	case objabi.R_MIPSJALR:
		out.Write8(uint8(elf.R_MIPS_JALR))
	}
	out.Write64(uint64(addend))

	return true
}

func elfsetupplt(ctxt *ld.Link, plt, gotplt *loader.SymbolBuilder, dynamic loader.Sym) {
	return
}

func machoreloc1(*sys.Arch, *ld.OutBuf, *loader.Loader, loader.Sym, loader.ExtReloc, int64) bool {
	return false
}

func trampoline(ctxt *ld.Link, ldr *loader.Loader, ri int, rs, s loader.Sym) {
	relocs := ldr.Relocs(s)
	r := relocs.At(ri)
	switch r.Type() {
	case objabi.R_CALLIND:
		if rs != 0 || ldr.SymType(rs) == sym.SDYNIMPORT {
			ctxt.Errorf(s, "unsupported indirect call to SDYNIMPORT symbol")
		}
	case objabi.R_CALLMIPS, objabi.R_JMPMIPS:
		if rs == 0 || ldr.SymType(rs) != sym.SDYNIMPORT {
			break
		}

		// In the case of SDYNIMPORT symbols, add a trampoline that provides
		// the necessary calling convention and relocations.

		// Look up existing trampolines first. if we found one within the range
		// of direct call, we can reuse it. otherwise create a new one.
		var tramp loader.Sym
		for i := 0; ; i++ {
			oName := ldr.SymName(rs)
			name := oName
			if r.Add() == 0 {
				name += fmt.Sprintf("-tramp%d", i)
			} else {
				name += fmt.Sprintf("%+x-tramp%d", r.Add(), i)
			}
			tramp = ldr.LookupOrCreateSym(name, int(ldr.SymVersion(rs)))
			ldr.SetAttrReachable(tramp, true)
			if ldr.SymType(tramp) == sym.SDYNIMPORT {
				// don't reuse trampoline defined in other module
				continue
			}
			if oName == "runtime.deferreturn" {
				ldr.SetIsDeferReturnTramp(tramp, true)
			}
			break
		}
		if ldr.SymType(tramp) == 0 {
			// trampoline does not exist, create one
			trampb := ldr.MakeSymbolUpdater(tramp)
			ctxt.AddTramp(trampb)
			gentramp(ctxt.Arch, ctxt.LinkMode, ldr, trampb, rs, int64(r.Add()))
		}
		// modify reloc to point to tramp, which will be resolved later
		sb := ldr.MakeSymbolUpdater(s)
		relocs := sb.Relocs()
		r := relocs.At(ri)
		r.SetSym(tramp)
		r.SetAdd(0)
	default:
		ctxt.Errorf(s, "trampoline called with non-jump reloc: %d (%s)", r.Type(), sym.RelocName(ctxt.Arch, r.Type()))
	}
}

func gentramp(arch *sys.Arch, linkmode ld.LinkMode, ldr *loader.Loader, tramp *loader.SymbolBuilder, target loader.Sym, offset int64) {
	// Generate a trampoline that loads register 25 (t9) and jumps to that address.
	// The JALR is needed for the relocation and PIC code requires that t9 contain
	// the function address when called. The offset is based off the value that gp
	// was initialised to via the dynamic linker, now stored in runtime.libc_gp.

	ops := []uint32{
		// Determine address of trampoline (our t9), preserving RA.
		// The bal instruction gives us the address three instructions
		// or 12 bytes into the trampoline.
		0x03e0b825, // move   s7,ra
		0x04110001, // bal    1(pc)
		0x00000000, // nop
		0x03e0c825, // move   t9,ra
		0x02e0f825, // move   ra,s7
		0x6339fff4, // daddi  t9,t9,-12

		// Load R23 (aka REGTMP aka s7) with gp address.
		0x3c170000, // lui    s7,0x0	<- R_MIPS_GPREL16/SUB/HI16
		0x02f9b82d, // daddu  s7,s7,t9
		0x66f70000, // daddiu s7,s7,0   <- R_MIPS_GPREL16/SUB/LO16
		0x02e0e025, // move   gp,s7

		// Load R25 (aka t9) with function address and indirect call.
		0xdef90000, // ld     t9,0(s7)  <- R_MIPS_CALL16
		0x03200009, // jalr   zero,t9   <- R_MIPS_JALR
		0x00000000, // nop
	}

	tramp.SetSize(int64(len(ops) * 4))
	ibs := make([]byte, tramp.Size())
	for i, op := range ops {
		arch.ByteOrder.PutUint32(ibs[i*4:], op)
	}
	tramp.SetData(ibs)

	r1, _ := tramp.AddRel(objabi.R_MIPSGPRELHI)
	r1.SetSiz(4)
	r1.SetOff(6 * 4)
	r1.SetSym(tramp.Sym())

	r2, _ := tramp.AddRel(objabi.R_MIPSGPRELLO)
	r2.SetSiz(4)
	r2.SetOff(8 * 4)
	r2.SetSym(tramp.Sym())

	r3, _ := tramp.AddRel(objabi.R_MIPSCALL16)
	r3.SetSiz(4)
	r3.SetOff(10 * 4)
	r3.SetSym(target)
	r3.SetAdd(offset)

	r4, _ := tramp.AddRel(objabi.R_MIPSJALR)
	r4.SetSiz(4)
	r4.SetOff(11 * 4)
	r4.SetSym(target)
	r4.SetAdd(offset)
}

func archreloc(target *ld.Target, ldr *loader.Loader, syms *ld.ArchSyms, r loader.Reloc, s loader.Sym, val int64) (o int64, nExtReloc int, ok bool) {
	if target.IsExternal() {
		switch r.Type() {
		default:
			return val, 0, false

		case objabi.R_ADDRMIPS,
			objabi.R_ADDRMIPSU,
			objabi.R_ADDRMIPSTLS,
			objabi.R_CALLMIPS,
			objabi.R_JMPMIPS,
			objabi.R_MIPSGPRELHI,
			objabi.R_MIPSGPRELLO,
			objabi.R_MIPSCALL16,
			objabi.R_MIPSJALR:
			return val, 1, true
		}
	}

	const isOk = true
	const noExtReloc = 0
	rs := r.Sym()
	rs = ldr.ResolveABIAlias(rs)
	switch r.Type() {
	case objabi.R_ADDRMIPS,
		objabi.R_ADDRMIPSU:
		t := ldr.SymValue(rs) + r.Add()
		if r.Type() == objabi.R_ADDRMIPS {
			return int64(val&0xffff0000 | t&0xffff), noExtReloc, isOk
		}
		return int64(val&0xffff0000 | ((t+1<<15)>>16)&0xffff), noExtReloc, isOk
	case objabi.R_ADDRMIPSTLS:
		// thread pointer is at 0x7000 offset from the start of TLS data area
		t := ldr.SymValue(rs) + r.Add() - 0x7000
		if target.IsOpenbsd() {
			// OpenBSD mips64 does not currently offset TLS by 0x7000,
			// as such we need to add this back to get the correct offset.
			t += 0x7000
		}
		if t < -32768 || t >= 32678 {
			ldr.Errorf(s, "TLS offset out of range %d", t)
		}
		return int64(val&0xffff0000 | t&0xffff), noExtReloc, isOk
	case objabi.R_CALLMIPS,
		objabi.R_JMPMIPS:
		// Low 26 bits = (S + A) >> 2
		t := ldr.SymValue(rs) + r.Add()
		return int64(val&0xfc000000 | (t>>2)&^0xfc000000), noExtReloc, isOk
	}

	return val, 0, false
}

func archrelocvariant(*ld.Target, *loader.Loader, loader.Reloc, sym.RelocVariant, loader.Sym, int64, []byte) int64 {
	return -1
}

func extreloc(target *ld.Target, ldr *loader.Loader, r loader.Reloc, s loader.Sym) (loader.ExtReloc, bool) {
	switch r.Type() {
	case objabi.R_ADDRMIPS,
		objabi.R_ADDRMIPSU:
		return ld.ExtrelocViaOuterSym(ldr, r, s), true

	case objabi.R_ADDRMIPSTLS,
		objabi.R_CALLMIPS,
		objabi.R_JMPMIPS,
		objabi.R_MIPSGPRELHI,
		objabi.R_MIPSGPRELLO,
		objabi.R_MIPSCALL16,
		objabi.R_MIPSJALR:
		return ld.ExtrelocSimple(ldr, r), true
	}
	return loader.ExtReloc{}, false
}
