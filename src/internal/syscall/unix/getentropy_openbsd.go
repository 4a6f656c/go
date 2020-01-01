// Copyright 2016 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package unix

import (
	_ "unsafe" // for go:linkname
)

// GetEntropy calls the OpenBSD getentropy system call.
func GetEntropy(p []byte) error {
	return getentropy(p)
}

// Implemented in syscall/syscall_openbsd.go.
//go:linkname getentropy syscall.getentropy
func getentropy(p []byte) error
