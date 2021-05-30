// Copyright 2020 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//
// System calls and other sys.stuff for mips64, OpenBSD
// System calls are implemented in libc/libpthread, this file
// contains trampolines that convert from Go to C calling convention.
// Some direct system call implementations currently remain.
//

#include "go_asm.h"
#include "go_tls.h"
#include "textflag.h"

#define CLOCK_REALTIME	$0
#define	CLOCK_MONOTONIC	$3

// mstart_stub is the first function executed on a new thread started by pthread_create.
// It just does some low-level setup and then calls mstart.
// Note: called with the C calling convention.
TEXT runtime·mstart_stub(SB),NOSPLIT,$160
	// R4 points to the m.
	// We are already on m's g0 stack.

	// initialize REGSB = PC&0xffffffff00000000
	BGEZAL	R0, 1(PC)
	SRLV	$32, R31, RSB
	SLLV	$32, RSB

	// Save callee-save registers (R16..R23, R30, F24..F31).
	MOVV	R16, (1*8)(R29)
	MOVV	R17, (2*8)(R29)
	MOVV	R18, (3*8)(R29)
	MOVV	R19, (4*8)(R29)
	MOVV	R20, (5*8)(R29)
	MOVV	R21, (6*8)(R29)
	MOVV	R22, (7*8)(R29)
	MOVV	R23, (8*8)(R29)
	MOVV	g, (10*8)(R29)
	MOVF	F24, (11*8)(R29)
	MOVF	F25, (12*8)(R29)
	MOVF	F26, (13*8)(R29)
	MOVF	F27, (14*8)(R29)
	MOVF	F28, (15*8)(R29)
	MOVF	F29, (16*8)(R29)
	MOVF	F30, (17*8)(R29)
	MOVF	F31, (18*8)(R29)

	MOVV	m_g0(R4), g
	CALL	runtime·save_g(SB)

	CALL	runtime·mstart(SB)

	// Restore callee-save registers.
	MOVV	(1*8)(R29), R16
	MOVV	(2*8)(R29), R17
	MOVV	(3*8)(R29), R18
	MOVV	(4*8)(R29), R19
	MOVV	(5*8)(R29), R20
	MOVV	(6*8)(R29), R21
	MOVV	(7*8)(R29), R22
	MOVV	(8*8)(R29), R23
	MOVV	(10*8)(R29), g
	MOVF	(11*8)(R29), F24
	MOVF	(12*8)(R29), F25
	MOVF	(13*8)(R29), F26
	MOVF	(14*8)(R29), F27
	MOVF	(15*8)(R29), F28
	MOVF	(16*8)(R29), F29
	MOVF	(17*8)(R29), F30
	MOVF	(18*8)(R29), F31

	// Go is all done with this OS thread.
	// Tell pthread everything is ok (we never join with this thread, so
	// the value here doesn't really matter).
	MOVV	$0, R0

	RET

TEXT runtime·sigfwd(SB),NOSPLIT,$0-32
	MOVW	sig+8(FP), R4
	MOVV	info+16(FP), R5
	MOVV	ctx+24(FP), R6
	MOVV	fn+0(FP), R25		// Must use R25, needed for PIC code.
	CALL	(R25)
	RET

TEXT runtime·sigtramp(SB),NOSPLIT,$176
	// Save callee-save registers (R16..R23, R30, F24..F31).
	MOVV	R16, (4*8)(R29)
	MOVV	R17, (5*8)(R29)
	MOVV	R18, (6*8)(R29)
	MOVV	R19, (7*8)(R29)
	MOVV	R20, (8*8)(R29)
	MOVV	R21, (9*8)(R29)
	MOVV	R22, (10*8)(R29)
	MOVV	R23, (11*8)(R29)
	MOVV	g,   (12*8)(R29)
	MOVF	F24, (13*8)(R29)
	MOVF	F25, (14*8)(R29)
	MOVF	F26, (15*8)(R29)
	MOVF	F27, (16*8)(R29)
	MOVF	F28, (17*8)(R29)
	MOVF	F29, (18*8)(R29)
	MOVF	F30, (19*8)(R29)
	MOVF	F31, (20*8)(R29)

	// Preserve RSB (aka gp)
	MOVV	RSB, (21*8)(R29)

	// initialize REGSB = PC&0xffffffff00000000
	BGEZAL	R0, 1(PC)
	SRLV	$32, R31, RSB
	SLLV	$32, RSB

	// this might be called in external code context,
	// where g is not set.
	JAL	runtime·load_g(SB)

	MOVW	R4, 8(R29)
	MOVV	R5, 16(R29)
	MOVV	R6, 24(R29)
	MOVV	$runtime·sigtrampgo(SB), R1
	JAL	(R1)

	// Restore callee-save registers.
	MOVV	(4*8)(R29), R16
	MOVV	(5*8)(R29), R17
	MOVV	(6*8)(R29), R18
	MOVV	(7*8)(R29), R19
	MOVV	(8*8)(R29), R20
	MOVV	(9*8)(R29), R21
	MOVV	(10*8)(R29), R22
	MOVV	(11*8)(R29), R23
	MOVV	(12*8)(R29), g
	MOVF	(13*8)(R29), F24
	MOVF	(14*8)(R29), F25
	MOVF	(15*8)(R29), F26
	MOVF	(16*8)(R29), F27
	MOVF	(17*8)(R29), F28
	MOVF	(18*8)(R29), F29
	MOVF	(19*8)(R29), F30
	MOVF	(20*8)(R29), F31

	// Restore RSB (aka gp)
	MOVV	(21*8)(R29), RSB

	RET

//
// These trampolines help convert from Go calling convention to C calling convention.
// They should be called with asmcgocall.
// A pointer to the arguments is passed in R0.
// A single int32 result is returned in R0.
// (For more results, make an args/results structure.)
TEXT runtime·pthread_attr_init_trampoline(SB),NOSPLIT,$8
	MOVV	RSB, 8(R29)
	MOVV	0(R4), R4		// arg 1 - attr
	CALL	libc_pthread_attr_init(SB)
	MOVV	8(R29), RSB
	RET

TEXT runtime·pthread_attr_destroy_trampoline(SB),NOSPLIT,$8
	MOVV	RSB, 8(R29)
	MOVV	0(R4), R4		// arg 1 - attr
	CALL	libc_pthread_attr_destroy(SB)
	MOVV	8(R29), RSB
	RET

TEXT runtime·pthread_attr_getstacksize_trampoline(SB),NOSPLIT,$8
	MOVV	RSB, 8(R29)
	MOVV	8(R4), R5		// arg 2 - size
	MOVV	0(R4), R4		// arg 1 - attr
	CALL	libc_pthread_attr_getstacksize(SB)
	MOVV	8(R29), RSB
	RET

TEXT runtime·pthread_attr_setdetachstate_trampoline(SB),NOSPLIT,$8
	MOVV	RSB, 8(R29)
	MOVV	8(R4), R5		// arg 2 - state
	MOVV	0(R4), R4		// arg 1 - attr
	CALL	libc_pthread_attr_setdetachstate(SB)
	MOVV	8(R29), RSB
	RET

TEXT runtime·pthread_create_trampoline(SB),NOSPLIT,$8
	MOVV	RSB, 8(R29)
	MOVV	0(R4), R5		// arg 2 - attr
	MOVV	8(R4), R6		// arg 3 - start
	MOVV	16(R4), R7		// arg 4 - arg
	ADDV	$-16, R29
	MOVV	R29, R4			// arg 1 - &threadid (discard)
	CALL	libc_pthread_create(SB)
	ADDV	$16, R29
	MOVV	8(R29), RSB
	RET

TEXT runtime·thrkill_trampoline(SB),NOSPLIT,$8
	MOVV	RSB, 8(R29)
	MOVV	8(R4), R5		// arg 2 - signal
	MOVV	$0, R6			// arg 3 - tcb
	MOVW	0(R4), R4		// arg 1 - tid
	CALL	libc_thrkill(SB)
	MOVV	8(R29), RSB
	RET

TEXT runtime·thrsleep_trampoline(SB),NOSPLIT,$8
	MOVV	RSB, 8(R29)
	MOVW	8(R4), R5		// arg 2 - clock_id
	MOVV	16(R4), R6		// arg 3 - abstime
	MOVV	24(R4), R7		// arg 4 - lock
	MOVV	32(R4), R8		// arg 5 - abort
	MOVV	0(R4), R4		// arg 1 - id
	CALL	libc_thrsleep(SB)
	MOVV	8(R29), RSB
	RET

TEXT runtime·thrwakeup_trampoline(SB),NOSPLIT,$8
	MOVV	RSB, 8(R29)
	MOVW	8(R4), R5		// arg 2 - count
	MOVV	0(R4), R4		// arg 1 - id
	CALL	libc_thrwakeup(SB)
	MOVV	8(R29), RSB
	RET

TEXT runtime·exit_trampoline(SB),NOSPLIT,$8
	MOVV	RSB, 8(R29)
	MOVW	0(R4), R4		// arg 1 - status
	CALL	libc_exit(SB)
	MOVV	$0, R2			// crash on failure
	MOVV	R2, (R2)
	MOVV	8(R29), RSB
	RET

TEXT runtime·getthrid_trampoline(SB),NOSPLIT,$8
	MOVV	RSB, 8(R29)
	MOVV	R4, R16			// pointer to args
	CALL	libc_getthrid(SB)
	MOVW	R2, 0(R16)		// return value
	MOVV	8(R29), RSB
	RET

TEXT runtime·raiseproc_trampoline(SB),NOSPLIT,$8
	MOVV	RSB, 8(R29)
	MOVV	R4, R16			// pointer to args
	CALL	libc_getpid(SB)		// arg 1 - pid
	MOVW	R2, R4
	MOVW	0(R16), R5		// arg 2 - signal
	CALL	libc_kill(SB)
	MOVV	8(R29), RSB
	RET

TEXT runtime·sched_yield_trampoline(SB),NOSPLIT,$8
	MOVV	RSB, 8(R29)
	CALL	libc_sched_yield(SB)
	MOVV	8(R29), RSB
	RET

TEXT runtime·mmap_trampoline(SB),NOSPLIT,$8
	MOVV	RSB, 8(R29)
	MOVV    R4, R16			// pointer to args
	MOVV	0(R16), R4		// arg 1 - addr
	MOVV	8(R16), R5		// arg 2 - len
	MOVW	16(R16), R6		// arg 3 - prot
	MOVW	20(R16), R7		// arg 4 - flags
	MOVW	24(R16), R8		// arg 5 - fid
	MOVW	28(R16), R9		// arg 6 - offset
	CALL	libc_mmap(SB)
	MOVV	$0, R3
	MOVV	$-1, R4
	BNE	R2, R4, noerr
	CALL	libc_errno(SB)
	MOVW	(R2), R3		// errno
	MOVV	$0, R2
noerr:
	MOVV	R2, 32(R16)
	MOVV	R3, 40(R16)
	MOVV	8(R29), RSB
	RET

TEXT runtime·munmap_trampoline(SB),NOSPLIT,$8
	MOVV	RSB, 8(R29)
	MOVV	8(R4), R5		// arg 2 - len
	MOVV	0(R4), R4		// arg 1 - addr
	CALL	libc_munmap(SB)
	MOVV	$-1, R4
	BNE	R2, R4, 3(PC)
	MOVV	$0, R2			// crash on failure
	MOVV	R2, (R2)
	MOVV	8(R29), RSB
	RET

TEXT runtime·madvise_trampoline(SB),NOSPLIT,$8
	MOVV	RSB, 8(R29)
	MOVV	8(R4), R5		// arg 2 - len
	MOVW	16(R4), R6		// arg 3 - advice
	MOVV	0(R4), R4		// arg 1 - addr
	CALL	libc_madvise(SB)
	// ignore failure - maybe pages are locked
	MOVV	8(R29), RSB
	RET

TEXT runtime·open_trampoline(SB),NOSPLIT,$8
	MOVV	RSB, 8(R29)
	MOVW	8(R4), R5		// arg 2 - flags
	MOVW	12(R4), R6		// arg 3 - mode
	MOVV	0(R4), R4		// arg 1 - path
	MOVV	$0, R7			// varargs
	CALL	libc_open(SB)
	MOVV	8(R29), RSB
	RET

TEXT runtime·close_trampoline(SB),NOSPLIT,$8
	MOVV	RSB, 8(R29)
	MOVW	0(R4), R4		// arg 1 - fd
	CALL	libc_close(SB)
	MOVV	8(R29), RSB
	RET

TEXT runtime·read_trampoline(SB),NOSPLIT,$8
	MOVV	RSB, 8(R29)
	MOVV	8(R4), R5		// arg 2 - buf
	MOVW	16(R4), R6		// arg 3 - count
	MOVW	0(R4), R4		// arg 1 - fd (int32 from read)
	CALL	libc_read(SB)
	MOVV	$-1, R4
	BNE	R2, R4, noerr
	CALL	libc_errno(SB)
	MOVW	(R2), R2		// errno
	SUBVU	R2, R0, R2		// caller expects negative errno
noerr:
	MOVV	8(R29), RSB
	RET

TEXT runtime·write_trampoline(SB),NOSPLIT,$8
	MOVV	RSB, 8(R29)
	MOVV	8(R4), R5		// arg 2 - buf
	MOVW	16(R4), R6		// arg 3 - count
	MOVV	0(R4), R4		// arg 1 - fd (uintptr from write1)
	CALL	libc_write(SB)
	MOVV	$-1, R4
	BNE	R2, R4, noerr
	CALL	libc_errno(SB)
	MOVW	(R2), R2		// errno
	SUBVU	R2, R0, R2		// caller expects negative errno
noerr:
	MOVV	8(R29), RSB
	RET

TEXT runtime·pipe2_trampoline(SB),NOSPLIT,$8
	MOVV	RSB, 8(R29)
	MOVW	8(R4), R5		// arg 2 - flags
	MOVV	0(R4), R4		// arg 1 - filedes
	CALL	libc_pipe2(SB)
	MOVV	$-1, R4
	BNE	R2, R4, noerr
	CALL	libc_errno(SB)
	MOVW	(R2), R2		// errno
	SUBVU	R2, R0, R2		// caller expects negative errno
noerr:
	MOVV	8(R29), RSB
	RET

TEXT runtime·setitimer_trampoline(SB),NOSPLIT,$8
	MOVV	RSB, 8(R29)
	MOVV	8(R4), R5		// arg 2 - new
	MOVV	16(R4), R6		// arg 3 - old
	MOVW	0(R4), R4		// arg 1 - which
	CALL	libc_setitimer(SB)
	MOVV	8(R29), RSB
	RET

TEXT runtime·usleep_trampoline(SB),NOSPLIT,$8
	MOVV	RSB, 8(R29)
	MOVW	0(R4), R4		// arg 1 - usec
	CALL	libc_usleep(SB)
	MOVV	8(R29), RSB
	RET

TEXT runtime·sysctl_trampoline(SB),NOSPLIT,$8
	MOVV	RSB, 8(R29)
	MOVW	8(R4), R5		// arg 2 - miblen
	MOVV	16(R4), R6		// arg 3 - out
	MOVV	24(R4), R7		// arg 4 - size
	MOVV	32(R4), R8		// arg 5 - dst
	MOVV	40(R4), R9		// arg 6 - ndst
	MOVV	0(R4), R4		// arg 1 - mib
	CALL	libc_sysctl(SB)
	MOVV	8(R29), RSB
	RET

TEXT runtime·kqueue_trampoline(SB),NOSPLIT,$8
	MOVV	RSB, 8(R29)
	CALL	libc_kqueue(SB)
	MOVV	8(R29), RSB
	RET

TEXT runtime·kevent_trampoline(SB),NOSPLIT,$8
	MOVV	RSB, 8(R29)
	MOVV	8(R4), R5		// arg 2 - keventt
	MOVW	16(R4), R6		// arg 3 - nch
	MOVV	24(R4), R7		// arg 4 - ev
	MOVW	32(R4), R8		// arg 5 - nev
	MOVV	40(R4), R9		// arg 6 - ts
	MOVW	0(R4), R4		// arg 1 - kq
	CALL	libc_kevent(SB)
	MOVV	$-1, R4
	BNE	R2, R4, noerr
	CALL	libc_errno(SB)
	MOVW	(R2), R2		// errno
	SUBVU	R2, R0, R2		// caller expects negative errno
noerr:
	MOVV	8(R29), RSB
	RET

TEXT runtime·clock_gettime_trampoline(SB),NOSPLIT,$8
	MOVV	RSB, 8(R29)
	MOVV	8(R4), R5		// arg 2 - tp
	MOVW	0(R4), R4		// arg 1 - clock_id
	CALL	libc_clock_gettime(SB)
	MOVV	$-1, R4
	BNE	R2, R4, 3(PC)
	MOVV	$0, R2			// crash on failure
	MOVV	R2, (R2)
	MOVV	8(R29), RSB
	RET

TEXT runtime·fcntl_trampoline(SB),NOSPLIT,$8
	MOVV	RSB, 8(R29)
	MOVW	4(R4), R5		// arg 2 - cmd
	MOVW	8(R4), R6		// arg 3 - arg
	MOVW	0(R4), R4		// arg 1 - fd
	MOVV	$0, R7			// vararg
	CALL	libc_fcntl(SB)
	MOVV	8(R29), RSB
	RET

TEXT runtime·sigaction_trampoline(SB),NOSPLIT,$8
	MOVV	RSB, 8(R29)
	MOVV	8(R4), R5		// arg 2 - new
	MOVV	16(R4), R6		// arg 3 - old
	MOVW	0(R4), R4		// arg 1 - sig
	CALL	libc_sigaction(SB)
	MOVV	$-1, R4
	BNE	R2, R4, 3(PC)
	MOVV	$0, R2			// crash on failure
	MOVV	R2, (R2)
	MOVV	8(R29), RSB
	RET

TEXT runtime·sigprocmask_trampoline(SB),NOSPLIT,$8
	MOVV	RSB, 8(R29)
	MOVV	8(R4), R5		// arg 2 - new
	MOVV	16(R4), R6		// arg 3 - old
	MOVW	0(R4), R4		// arg 1 - how
	CALL	libc_pthread_sigmask(SB)
	MOVV	$-1, R4
	BNE	R2, R4, 3(PC)
	MOVV	$0, R2			// crash on failure
	MOVV	R2, (R2)
	MOVV	8(R29), RSB
	RET

TEXT runtime·sigaltstack_trampoline(SB),NOSPLIT,$8
	MOVV	RSB, 8(R29)
	MOVV	8(R4), R5		// arg 2 - old
	MOVV	0(R4), R4		// arg 1 - new
	CALL	libc_sigaltstack(SB)
	MOVV	$-1, R4
	BNE	R2, R4, 3(PC)
	MOVV	$0, R2			// crash on failure
	MOVV	R2, (R2)
	MOVV	8(R29), RSB
	RET
