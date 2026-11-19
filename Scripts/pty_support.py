"""Shared Linux PTY driver for the example and engine interaction checks."""
import fcntl
import json
import os
from pathlib import Path
import pty
import re
import select
import signal
import struct
import subprocess
import termios
import time
import unicodedata

ENV = dict(os.environ, TERM='xterm-256color', SWIFT_BACKTRACE='disable')


def module_objects(bin_path, modules):
    """Link current SwiftPM outputs; globbing Swift objects also picks up deleted source files."""
    objects = []
    for module in modules:
        directory = Path(bin_path) / (module + '.build')
        output_map = directory / 'output-file-map.json'
        if output_map.exists():
            objects.extend(output['object'] for output in json.loads(output_map.read_text()).values() if 'object' in output)
            module_object = directory / (module + '.swiftmodule.o')
            if module_object.exists():
                objects.append(str(module_object))
        else:
            objects.extend(str(path) for path in directory.glob('*.o'))
    return objects

class TerminalSession:
    def __init__(self, binary, *arguments, columns=120, rows=40):
        self.master, self.slave = pty.openpty()
        self.resize(columns, rows, notify=False)
        self.before = termios.tcgetattr(self.slave)
        self.history = bytearray()

        def setup():
            os.setsid()
            fcntl.ioctl(self.slave, termios.TIOCSCTTY, 0)

        self.process = subprocess.Popen([str(binary), *arguments], stdin=self.slave,
                                        stdout=self.slave, stderr=self.slave,
                                        env=ENV, preexec_fn=setup)

    def __enter__(self):
        return self

    def __exit__(self, *_):
        if self.process.poll() is None:
            self.process.terminate()
            self.process.wait(timeout=8)
        self.read()
        os.close(self.master)
        os.close(self.slave)

    def resize(self, columns, rows, notify=True):
        self.columns, self.rows = columns, rows
        if notify:
            self.read()
            # A real terminal clips its screen on resize; the next host frame is complete.
            self.history.extend(b'\x1b[2J')
        fcntl.ioctl(self.slave, termios.TIOCSWINSZ, struct.pack('HHHH', rows, columns, 0, 0))
        if notify:
            os.kill(self.process.pid, signal.SIGWINCH)

    def read(self):
        while select.select([self.master], [], [], .03)[0]:
            try:
                chunk = os.read(self.master, 65536)
                if not chunk:
                    break
                self.history.extend(chunk)
            except OSError:
                break

    def screen(self):
        # Replay cursor-addressed diffs, including runs that omit unchanged cells.
        screen = [[' '] * 200 for _ in range(100)]
        row = column = 0
        text = self.history.decode('utf-8', errors='replace')
        index = 0
        while index < len(text):
            if text[index] == '\x1b':
                match = re.match(r'\x1b\[([0-9;?]*)([ -/]*)([@-~])', text[index:])
                if match:
                    if match[3] in ('H', 'f'):
                        parts = match[1].split(';')
                        row = int(parts[0] or '1') - 1
                        column = int(parts[1] or '1') - 1 if len(parts) > 1 else 0
                    elif match[3] == 'J' and match[1] == '2':
                        screen = [[' '] * 200 for _ in range(100)]
                    index += len(match[0])
                    continue
            char = text[index]
            if char.isprintable() and 0 <= row < 100 and 0 <= column < 200:
                screen[row][column] = char
                column += 0 if unicodedata.combining(char) else 2 if unicodedata.east_asian_width(char) in ('W', 'F') else 1
            index += 1
        return [''.join(line[:self.columns]) for line in screen[:self.rows]]

    def wait(self, text, absent=False):
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            self.read()
            found = any(text in line for line in self.screen())
            if found != absent:
                return
        raise AssertionError(f'Expected {text!r}, absent={absent}\n' + '\n'.join(self.screen()[:45]))

    def position(self, text, offset=0):
        self.wait(text)
        for row, line in enumerate(self.screen()):
            if text in line:
                return line.index(text) + offset, row
        raise AssertionError(text)

    def send(self, data):
        os.write(self.master, data)
        self.read()

    def mouse(self, position, code=0, release=False):
        column, row = position
        self.send(f'\x1b[<{code};{column + 1};{row + 1}{"m" if release else "M"}'.encode())

    def click(self, text, offset=0):
        position = self.position(text, offset)
        self.mouse(position)
        self.mouse(position, release=True)

    def wheel(self, text, down=True, count=1):
        position = self.position(text)
        self.send((f'\x1b[<{65 if down else 64};{position[0] + 1};{position[1] + 1}M' * count).encode())

    def stop(self, by_signal=False, mouse=True, mouse_mode=1000):
        if by_signal:
            os.kill(self.process.pid, signal.SIGTERM)
        else:
            self.send(b'\x03')
        self.process.wait(timeout=8)
        self.read()
        assert self.process.returncode == 0
        for sequence in (b'\x1b[?1049l', b'\x1b[?2004l', b'\x1b[?25h'):
            assert sequence in self.history
        if mouse:
            assert f'\x1b[?{mouse_mode}l'.encode() in self.history and b'\x1b[?1006l' in self.history
        assert termios.tcgetattr(self.slave) == self.before

