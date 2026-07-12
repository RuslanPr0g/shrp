#!/usr/bin/env python3
"""Drives cs's interactive REPL through a real pty, since -t 0 (tty
detection) can't be faked with a plain pipe. Used by test/smoke.sh.
"""
import os
import pty
import select
import sys
import time

repo_dir = sys.argv[1]


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


cmd = f'source "{repo_dir}/cs.zsh"; cs'
inputs = [
    'Console.WriteLine("after blank");\n',
    '\n',
    'quit\n',
]
print(run(cmd, inputs).decode(errors="replace"))
