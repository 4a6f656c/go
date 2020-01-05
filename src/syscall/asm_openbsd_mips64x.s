// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build openbsd
// +build mips64 mips64le

#include "textflag.h"

//
// System calls for mips64, Linux
//

// func Syscall(trap int64, a1, a2, a3 int64) (r1, r2, err int64);
TEXT ·Syscall(SB),NOSPLIT,$0-56
	JAL	runtime·entersyscall(SB)
	MOVV	a1+8(FP), R4
	MOVV	a2+16(FP), R5
	MOVV	a3+24(FP), R6
	MOVV	R0, R7
	MOVV	R0, R8
	MOVV	R0, R9
	MOVV	trap+0(FP), R2	// syscall entry
	SYSCALL
	BEQ	R7, ok
	MOVV	$-1, R1
	MOVV	R1, r1+32(FP)	// r1
	MOVV	R0, r2+40(FP)	// r2
	MOVV	R2, err+48(FP)	// errno
	JAL	runtime·exitsyscall(SB)
	RET
ok:
	MOVV	R2, r1+32(FP)	// r1
	MOVV	R3, r2+40(FP)	// r2
	MOVV	R0, err+48(FP)	// errno
	JAL	runtime·exitsyscall(SB)
	RET

TEXT ·Syscall6(SB),NOSPLIT,$0-80
	JAL	runtime·entersyscall(SB)
	MOVV	a1+8(FP), R4
	MOVV	a2+16(FP), R5
	MOVV	a3+24(FP), R6
	MOVV	a4+32(FP), R7
	MOVV	a5+40(FP), R8
	MOVV	a6+48(FP), R9
	MOVV	trap+0(FP), R2	// syscall entry
	SYSCALL
	BEQ	R7, ok6
	MOVV	$-1, R1
	MOVV	R1, r1+56(FP)	// r1
	MOVV	R0, r2+64(FP)	// r2
	MOVV	R2, err+72(FP)	// errno
	JAL	runtime·exitsyscall(SB)
	RET
ok6:
	MOVV	R2, r1+56(FP)	// r1
	MOVV	R3, r2+64(FP)	// r2
	MOVV	R0, err+72(FP)	// errno
	JAL	runtime·exitsyscall(SB)
	RET

// func Syscall9(trap int64, a1, a2, a3, a4, a5, a6, a7, a8, a9 int64) (r1, r2, err int64);
TEXT	·Syscall9(SB),NOSPLIT,$0-104
	JAL	runtime·entersyscall(SB)
	MOVV	trap+0(FP), R2	// syscall entry
	MOVV	a1+8(FP), R4
	MOVV	a2+16(FP), R5
	MOVV	a3+24(FP), R6
	MOVV	a4+32(FP), R7
	MOVV	a5+40(FP), R8
	MOVV	a6+48(FP), R9
	MOVV	a7+56(FP), R11
	MOVV	a8+64(FP), R12
	MOVV	a9+72(FP), R13
	SUBVU	$32, R29
	MOVV	R11, 8(R29)	// arg 7
	MOVV	R12, 16(R29)	// arg 8
	MOVV	R13, 24(R29)	// arg 9
	SYSCALL
	BEQ	R7, ok9
	ADDV    $32, R29
	MOVV	$-1, R1
	MOVV	R1, r1+80(FP)	// r1
	MOVV	R0, r2+88(FP)	// r2
	MOVV	R2, err+96(FP)	// errno
	JAL	runtime·exitsyscall(SB)
	RET
ok9:
	ADDV    $32, R29
	MOVV	R2, r1+80(FP)	// r1
	MOVV	R3, r2+88(FP)	// r2
	MOVV	R0, err+96(FP)	// errno
	CALL	runtime·exitsyscall(SB)
	RET

TEXT ·RawSyscall(SB),NOSPLIT,$0-56
	MOVV	a1+8(FP), R4
	MOVV	a2+16(FP), R5
	MOVV	a3+24(FP), R6
	MOVV	R0, R7
	MOVV	R0, R8
	MOVV	R0, R9
	MOVV	trap+0(FP), R2	// syscall entry
	SYSCALL
	BEQ	R7, ok1
	MOVV	$-1, R1
	MOVV	R1, r1+32(FP)	// r1
	MOVV	R0, r2+40(FP)	// r2
	MOVV	R2, err+48(FP)	// errno
	RET
ok1:
	MOVV	R2, r1+32(FP)	// r1
	MOVV	R3, r2+40(FP)	// r2
	MOVV	R0, err+48(FP)	// errno
	RET

TEXT ·RawSyscall6(SB),NOSPLIT,$0-80
	MOVV	a1+8(FP), R4
	MOVV	a2+16(FP), R5
	MOVV	a3+24(FP), R6
	MOVV	a4+32(FP), R7
	MOVV	a5+40(FP), R8
	MOVV	a6+48(FP), R9
	MOVV	trap+0(FP), R2	// syscall entry
	SYSCALL
	BEQ	R7, ok2
	MOVV	$-1, R1
	MOVV	R1, r1+56(FP)	// r1
	MOVV	R0, r2+64(FP)	// r2
	MOVV	R2, err+72(FP)	// errno
	RET
ok2:
	MOVV	R2, r1+56(FP)	// r1
	MOVV	R3, r2+64(FP)	// r2
	MOVV	R0, err+72(FP)	// errno
	RET

TEXT ·rawSyscallNoError(SB),NOSPLIT,$0-48
	MOVV	a1+8(FP), R4
	MOVV	a2+16(FP), R5
	MOVV	a3+24(FP), R6
	MOVV	R0, R7
	MOVV	R0, R8
	MOVV	R0, R9
	MOVV	trap+0(FP), R2	// syscall entry
	SYSCALL
	MOVV	R2, r1+32(FP)
	MOVV	R3, r2+40(FP)
	RET
