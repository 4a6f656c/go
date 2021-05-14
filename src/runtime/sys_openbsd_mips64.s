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

TEXT runtime·sigtramp(SB),NOSPLIT,$64
	// initialize REGSB = PC&0xffffffff00000000
	BGEZAL	R0, 1(PC)
	SRLV	$32, R31, RSB
	SLLV	$32, RSB

	// TODO(jsing): This should save/restore callee-save registers.

	// this might be called in external code context,
	// where g is not set.
	JAL	runtime·load_g(SB)

	MOVW	R4, 8(R29)
	MOVV	R5, 16(R29)
	MOVV	R6, 24(R29)
	MOVV	$runtime·sigtrampgo(SB), R1
	JAL	(R1)
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

TEXT runtime·sched_yield_trampoline(SB),NOSPLIT,$8
	MOVV	RSB, 8(R29)
	CALL	libc_sched_yield(SB)
	MOVV	8(R29), RSB
	RET

// Exit the entire program (like C exit)
TEXT runtime·exit(SB),NOSPLIT|NOFRAME,$0
	MOVW	code+0(FP), R4		// arg 1 - status
	MOVV	$1, R2			// sys_exit
	SYSCALL
	BEQ	R7, 3(PC)
	MOVV	$0, R2			// crash on syscall failure
	MOVV	R2, (R2)
	RET

// func exitThread(wait *uint32)
TEXT runtime·exitThread(SB),NOSPLIT,$0
	MOVV	wait+0(FP), R4		// arg 1 - notdead
	MOVV	$302, R2		// sys___threxit
	SYSCALL
	MOVV	$0, R2			// crash on syscall failure
	MOVV	R2, (R2)
	JMP	0(PC)

TEXT runtime·open(SB),NOSPLIT|NOFRAME,$0
	MOVV	name+0(FP), R4		// arg 1 - path
	MOVW	mode+8(FP), R5		// arg 2 - mode
	MOVW	perm+12(FP), R6		// arg 3 - perm
	MOVV	$5, R2			// sys_open
	SYSCALL
	BEQ	R7, 2(PC)
	MOVW	$-1, R2
	MOVW	R2, ret+16(FP)
	RET

TEXT runtime·closefd(SB),NOSPLIT|NOFRAME,$0
	MOVW	fd+0(FP), R4		// arg 1 - fd
	MOVV	$6, R2			// sys_close
	SYSCALL
	BEQ	R7, 2(PC)
	MOVW	$-1, R2
	MOVW	R2, ret+8(FP)
	RET

TEXT runtime·read(SB),NOSPLIT|NOFRAME,$0
	MOVW	fd+0(FP), R4		// arg 1 - fd
	MOVV	p+8(FP), R5		// arg 2 - buf
	MOVW	n+16(FP), R6		// arg 3 - nbyte
	MOVV	$3, R2			// sys_read
	SYSCALL
	BEQ	R7, 2(PC)
	SUBVU	R2, R0, R2	// caller expects negative errno
	MOVW	R2, ret+24(FP)
	RET

// func pipe() (r, w int32, errno int32)
TEXT runtime·pipe(SB),NOSPLIT|NOFRAME,$0-12
	MOVV	$r+0(FP), R4
	MOVW	$0, R5
	MOVV	$101, R2		// sys_pipe2
	SYSCALL
	BEQ	R7, 2(PC)
	SUBVU	R2, R0, R2	// caller expects negative errno
	MOVW	R2, errno+8(FP)
	RET

// func pipe2(flags int32) (r, w int32, errno int32)
TEXT runtime·pipe2(SB),NOSPLIT|NOFRAME,$0-20
	MOVV	$r+8(FP), R4
	MOVW	flags+0(FP), R5
	MOVV	$101, R2		// sys_pipe2
	SYSCALL
	BEQ	R7, 2(PC)
	SUBVU	R2, R0, R2	// caller expects negative errno
	MOVW	R2, errno+16(FP)
	RET

TEXT runtime·write1(SB),NOSPLIT|NOFRAME,$0
	MOVV	fd+0(FP), R4		// arg 1 - fd
	MOVV	p+8(FP), R5		// arg 2 - buf
	MOVW	n+16(FP), R6		// arg 3 - nbyte
	MOVV	$4, R2			// sys_write
	SYSCALL
	BEQ	R7, 2(PC)
	SUBVU	R2, R0, R2	// caller expects negative errno
	MOVW	R2, ret+24(FP)
	RET

TEXT runtime·usleep(SB),NOSPLIT,$24-4
	MOVWU	usec+0(FP), R3
	MOVV	R3, R5
	MOVW	$1000000, R4
	DIVVU	R4, R3
	MOVV	LO, R3
	MOVV	R3, 8(R29)		// tv_sec
	MOVW	$1000, R4
	MULVU	R3, R4
	MOVV	LO, R4
	SUBVU	R4, R5
	MOVV	R5, 16(R29)		// tv_nsec

	ADDV	$8, R29, R4		// arg 1 - rqtp
	MOVV	$0, R5			// arg 2 - rmtp
	MOVV	$91, R2			// sys_nanosleep
	SYSCALL
	RET

TEXT runtime·getthrid(SB),NOSPLIT,$0-4
	MOVV	$299, R2		// sys_getthrid
	SYSCALL
	MOVW	R2, ret+0(FP)
	RET

TEXT runtime·thrkill(SB),NOSPLIT,$0-16
	MOVW	tid+0(FP), R4		// arg 1 - tid
	MOVV	sig+8(FP), R5		// arg 2 - signum
	MOVW	$0, R6			// arg 3 - tcb
	MOVV	$119, R2		// sys_thrkill
	SYSCALL
	RET

TEXT runtime·raiseproc(SB),NOSPLIT,$0
	MOVV	$20, R4			// sys_getpid
	SYSCALL
	MOVV	R2, R4			// arg 1 - pid
	MOVW	sig+0(FP), R5		// arg 2 - signum
	MOVV	$122, R2		// sys_kill
	SYSCALL
	RET

TEXT runtime·mmap(SB),NOSPLIT,$0
	MOVV	addr+0(FP), R4		// arg 1 - addr
	MOVV	n+8(FP), R5		// arg 2 - len
	MOVW	prot+16(FP), R6		// arg 3 - prot
	MOVW	flags+20(FP), R7	// arg 4 - flags
	MOVW	fd+24(FP), R8		// arg 5 - fd
	MOVW	$0, R9			// arg 6 - pad
	MOVW	off+28(FP), R10		// arg 7 - offset
	MOVV	$197, R2		// sys_mmap
	SYSCALL
	MOVV	$0, R4
	BEQ	R7, 3(PC)
	MOVV	R2, R4			// if error, move to R4
	MOVV	$0, R2
	MOVV	R2, p+32(FP)
	MOVV	R4, err+40(FP)
	RET

TEXT runtime·munmap(SB),NOSPLIT,$0
	MOVV	addr+0(FP), R4		// arg 1 - addr
	MOVV	n+8(FP), R5		// arg 2 - len
	MOVV	$73, R2			// sys_munmap
	SYSCALL
	BEQ	R7, 3(PC)
	MOVV	$0, R2			// crash on syscall failure
	MOVV	R2, (R2)
	RET

TEXT runtime·madvise(SB),NOSPLIT,$0
	MOVV	addr+0(FP), R4		// arg 1 - addr
	MOVV	n+8(FP), R5		// arg 2 - len
	MOVW	flags+16(FP), R6	// arg 2 - flags
	MOVV	$75, R2			// sys_madvise
	SYSCALL
	BEQ	R7, 2(PC)
	MOVW	$-1, R2
	MOVW	R2, ret+24(FP)
	RET

TEXT runtime·setitimer(SB),NOSPLIT,$0
	MOVW	mode+0(FP), R4		// arg 1 - mode
	MOVV	new+8(FP), R5		// arg 2 - new value
	MOVV	old+16(FP), R6		// arg 3 - old value
	MOVV	$69, R2			// sys_setitimer
	SYSCALL
	RET

// func walltime() (sec int64, nsec int32)
TEXT runtime·walltime(SB), NOSPLIT, $32
	MOVW	CLOCK_REALTIME, R4	// arg 1 - clock_id
	MOVV	$8(R29), R5		// arg 2 - tp
	MOVV	$87, R2			// sys_clock_gettime
	SYSCALL

	MOVV	8(R29), R4		// sec
	MOVV	16(R29), R5		// nsec
	MOVV	R4, sec+0(FP)
	MOVW	R5, nsec+8(FP)

	RET

// int64 nanotime1(void) so really
// void nanotime1(int64 *nsec)
TEXT runtime·nanotime1(SB),NOSPLIT,$32
	MOVW	CLOCK_MONOTONIC, R4	// arg 1 - clock_id
	MOVV	$8(R29), R5		// arg 2 - tp
	MOVV	$87, R2			// sys_clock_gettime
	SYSCALL

	MOVV	8(R29), R3		// sec
	MOVV	16(R29), R5		// nsec

	MOVV	$1000000000, R4
	MULVU	R4, R3
	MOVV	LO, R3
	ADDVU	R5, R3
	MOVV	R3, ret+0(FP)
	RET

TEXT runtime·sigaction(SB),NOSPLIT,$0
	MOVW	sig+0(FP), R4		// arg 1 - signum
	MOVV	new+8(FP), R5		// arg 2 - new sigaction
	MOVV	old+16(FP), R6		// arg 3 - old sigaction
	MOVV	$46, R2			// sys_sigaction
	SYSCALL
	BEQ	R7, 3(PC)
	MOVV	$3, R2			// crash on syscall failure
	MOVV	R2, (R2)
	RET

TEXT runtime·obsdsigprocmask(SB),NOSPLIT,$0
	MOVW	how+0(FP), R4		// arg 1 - mode
	MOVW	new+4(FP), R5		// arg 2 - new
	MOVV	$48, R2			// sys_sigprocmask
	SYSCALL
	BEQ	R7, 3(PC)
	MOVV	$3, R2			// crash on syscall failure
	MOVV	R2, (R2)
	MOVW	R2, ret+8(FP)
	RET

TEXT runtime·sigaltstack(SB),NOSPLIT,$0
	MOVV	new+0(FP), R4		// arg 1 - new sigaltstack
	MOVV	old+8(FP), R5		// arg 2 - old sigaltstack
	MOVV	$288, R2		// sys_sigaltstack
	SYSCALL
	BEQ	R7, 3(PC)
	MOVV	$0, R8			// crash on syscall failure
	MOVV	R8, (R8)
	RET

TEXT runtime·sysctl(SB),NOSPLIT,$0
	MOVV	mib+0(FP), R4		// arg 1 - mib
	MOVW	miblen+8(FP), R5	// arg 2 - miblen
	MOVV	out+16(FP), R6		// arg 3 - out
	MOVV	size+24(FP), R7		// arg 4 - size
	MOVV	dst+32(FP), R8		// arg 5 - dest
	MOVV	ndst+40(FP), R9		// arg 6 - newlen
	MOVV	$202, R2		// sys___sysctl
	SYSCALL
	BEQ	R7, 2(PC)
	SUBVU	R2, R0, R2	// caller expects negative errno
	MOVW	R2, ret+48(FP)
	RET

// int32 runtime·kqueue(void);
TEXT runtime·kqueue(SB),NOSPLIT,$0
	MOVV	$269, R2		// sys_kqueue
	SYSCALL
	BEQ	R7, 2(PC)
	SUBVU	R2, R0, R2	// caller expects negative errno
	MOVW	R2, ret+0(FP)
	RET

// int32 runtime·kevent(int kq, Kevent *changelist, int nchanges, Kevent *eventlist, int nevents, Timespec *timeout);
TEXT runtime·kevent(SB),NOSPLIT,$0
	MOVW	kq+0(FP), R4		// arg 1 - kq
	MOVV	ch+8(FP), R5		// arg 2 - changelist
	MOVW	nch+16(FP), R6		// arg 3 - nchanges
	MOVV	ev+24(FP), R7		// arg 4 - eventlist
	MOVW	nev+32(FP), R8		// arg 5 - nevents
	MOVV	ts+40(FP), R9		// arg 6 - timeout
	MOVV	$72, R2			// sys_kevent
	SYSCALL
	BEQ	R7, 2(PC)
	SUBVU	R2, R0, R2	// caller expects negative errno
	MOVW	R2, ret+48(FP)
	RET

// func closeonexec(fd int32)
TEXT runtime·closeonexec(SB),NOSPLIT,$0
	MOVW	fd+0(FP), R4		// arg 1 - fd
	MOVV	$2, R5			// arg 2 - cmd (F_SETFD)
	MOVV	$1, R6			// arg 3 - arg (FD_CLOEXEC)
	MOVV	$92, R2			// sys_fcntl
	SYSCALL
	RET

// func runtime·setNonblock(int32 fd)
TEXT runtime·setNonblock(SB),NOSPLIT|NOFRAME,$0-4
	MOVW	fd+0(FP), R4		// arg 1 - fd
	MOVV	$3, R5			// arg 2 - cmd (F_GETFL)
	MOVV	$0, R6			// arg 3
	MOVV	$92, R2			// sys_fcntl
	SYSCALL
	MOVV	$4, R6			// O_NONBLOCK
	OR	R2, R6			// arg 3 - flags
	MOVW	fd+0(FP), R4		// arg 1 - fd
	MOVV	$4, R5			// arg 2 - cmd (F_SETFL)
	MOVV	$92, R2			// sys_fcntl
	SYSCALL
	RET
