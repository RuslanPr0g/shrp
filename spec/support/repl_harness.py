#!/usr/bin/env python3
"""Drives cs through a real pty, since -t 0 (tty detection) can't be
faked with a plain pipe. Used by the ShellSpec suite in spec/ to test
the interactive REPL and -p's tty-forced behavior.

Usage: repl_harness.py <repo_dir> <cs_invocation> [<input_line> ...]
cs_invocation is the full command, e.g. "cs" or "cs -p".
Each input_line is sent followed by Enter, in order.
"""
import os
import pty
import select
import sys
import time

repo_dir = sys.argv[1]
invocation = sys.argv[2]
input_lines = sys.argv[3:]


def run(cmd, inputs, timeout=15, gap=3.0):
    pid, fd = pty.fork()
    if pid == 0:
        os.execvp("zsh", ["zsh", "-c", cmd])
    output = b""
    start = time.time()
    idx = 0
    last_input_time = time.time()
    closed = False
    while time.time() - start < timeout and not closed:
        r, _, _ = select.select([fd], [], [], 0.3)
        if fd in r:
            try:
                chunk = os.read(fd, 4096)
            except OSError:
                break
            if not chunk:
                break
            output += chunk
        if idx < len(inputs) and (time.time() - last_input_time) > 0.4:
            os.write(fd, inputs[idx].encode())
            idx += 1
            last_input_time = time.time()
        elif idx >= len(inputs) and (time.time() - last_input_time) > gap:
            closed = True
    try:
        os.close(fd)
    except OSError:
        pass
    return output


cmd = f'source "{repo_dir}/cs.zsh"; {invocation}'
inputs = [line + "\n" for line in input_lines]
print(run(cmd, inputs).decode(errors="replace"))
