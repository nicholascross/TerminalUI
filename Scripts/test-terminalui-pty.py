"""Linux PTY integration checks. Run `swift build` first, then this script."""
import fcntl
import os
import pty
import re
import select
import signal
import struct
import subprocess
import termios
import time
import tempfile
from pathlib import Path
import unicodedata

BINARY = os.path.abspath('.build/debug/RepositoryDemo')
ENV = dict(os.environ, TERM='xterm-256color')


class Session:
    def __init__(self, *arguments, columns=120, rows=40):
        self.fixture = tempfile.TemporaryDirectory(prefix='terminalui-git-')
        self.repo = Path(self.fixture.name)
        self.git('init', '-b', 'main')
        self.git('config', 'user.name', 'Demo Test')
        self.git('config', 'user.email', 'demo@example.test')
        (self.repo / 'Sources').mkdir()
        (self.repo / 'Tests').mkdir()
        for path in ['Sources/App.swift', 'Sources/Mouse.swift', 'README.md'] + [f'Tests/Case{i}.swift' for i in range(3, 24)]:
            (self.repo / path).write_text(''.join(f'old line {i}\n' for i in range(80)))
        self.git('add', '.')
        self.git('commit', '-m', 'Initial repository', '-m', 'Full commit message body.')
        for i in range(5):
            self.git('commit', '--allow-empty', '-m', f'Change {i}: improve terminal UI')
        self.git('branch', 'feature/mouse')
        self.git('branch', 'release')
        for path in self.repo.rglob('*'):
            if path.is_file() and '.git' not in path.parts:
                path.write_text(''.join(f'new line {i}\n' for i in range(80)))
        self.git('add', 'Sources/Mouse.swift')
        (self.repo / 'Sources/Mouse.swift').write_text(''.join(f'working line {i}\n' for i in range(80)))
        self.original_status = self.git('status', '--porcelain=v1', '-z')
        self.original_index = (self.repo / '.git/index').read_bytes()
        self.original_files = {str(path): path.read_bytes() for path in self.repo.rglob('*') if path.is_file() and '.git' not in path.parts}
        self.master, self.slave = pty.openpty()
        self.resize(columns, rows, notify=False)
        self.before = termios.tcgetattr(self.slave)
        self.history = bytearray()

        def setup():
            os.setsid()
            fcntl.ioctl(self.slave, termios.TIOCSCTTY, 0)

        self.process = subprocess.Popen([BINARY, "--repo", str(self.repo), *arguments], stdin=self.slave,
                                        stdout=self.slave, stderr=self.slave,
                                        env=ENV, preexec_fn=setup)

    def __enter__(self):
        try:
            self.wait('Ready · read-only repository')
        except BaseException:
            self.__exit__()
            raise
        return self

    def __exit__(self, *_):
        if self.process.poll() is None:
            self.process.terminate()
            self.process.wait(timeout=8)
        self.read()
        os.close(self.master)
        os.close(self.slave)
        assert self.git('status', '--porcelain=v1', '-z') == self.original_status
        assert (self.repo / '.git/index').read_bytes() == self.original_index
        assert self.git('branch', '--show-current').strip() == 'main'
        assert all(Path(path).read_bytes() == data for path, data in self.original_files.items())
        self.fixture.cleanup()

    def git(self, *arguments):
        return subprocess.check_output(['git', '-C', str(self.repo), *arguments], stderr=subprocess.DEVNULL).decode()

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

    def stop(self, by_signal=False, mouse=True):
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
            assert b'\x1b[?1000l' in self.history and b'\x1b[?1006l' in self.history
        assert termios.tcgetattr(self.slave) == self.before


with Session() as s:
    assert b'\x1b[?1000h' in s.history and b'\x1b[?1006h' in s.history
    s.click('MM Sources/Mouse.swift')
    s.wait('Selected Sources/Mouse.swift')
    s.wait('READ ONLY')
    s.click('[Staged diff]', 2)
    s.wheel('old line 0', count=60)
    s.wait('+new line 79')
    s.click('[Working diff]', 2)
    s.wheel('new line 0', count=60)
    s.wait('+working line 79')
    s.click('feature/mouse')
    s.wait('Inspecting branch feature/mouse')
    second_hash = s.git('rev-parse', '--short', 'HEAD~1').strip()
    s.click('  ' + second_hash)
    s.wait('Selected commit')
    s.wait('Change 3: improve terminal UI')
    s.wait('Author:')
    s.wait('AuthorDate:')
    s.click('[Older]', 2)
    s.wait('Change 2: improve terminal UI')
    s.click('[Newer]', 2)
    s.wait('Change 3: improve terminal UI')
    initial_hash = s.git('rev-list', '--max-parents=0', 'HEAD').strip()[:7]
    s.click('  ' + initial_hash)
    s.wait('Full commit message body.')
    s.wheel('Full commit message body.', count=20)
    s.wait('+old line 18')
    s.send(b'\x10')
    s.send(b'\x1b[200~View selected commit\x1b[201~\r')
    s.wait('Full commit message body.')
    s.click(' Syntax ', 2)
    s.wait('struct Reading')
    s.click('Python')
    s.wait('from dataclasses import dataclass')
    s.click('JSON')
    s.wait('"station": "Melbourne"')
    s.click('Components')
    s.wait('Editable scratchpad')
    s.click('Click to place caret:', 2)
    s.send(b'!')
    s.wait('Cl!ick to place caret:')
    s.click('Editable scratchpad', 4)
    s.send(b'\x1b[200~!\nPasted\x1b[201~')
    s.wait('Edit!')
    s.wait('Pastedable scratchpad')
    long_paste = '\n' + '\n'.join(f'L{index}' for index in range(30))
    s.send(b'\x1b[200~' + long_paste.encode() + b'\x1b[201~')
    s.wait('L29able scratchpad')
    s.wheel('L29able scratchpad', down=False, count=15)
    s.wait('Edit!')
    # Wheel leaves the caret in place; typing reveals it again.
    s.send(b'?')
    s.wait('L29?able scratchpad')
    # Nested viewport scrolls first; the enclosing component view remains at its top.
    s.wheel('Nested row 0', count=1)
    s.wait('Nested row 3')
    s.wait('Cl!ick to place caret:')
    s.wheel('Nested row 3', count=12)
    s.wait('Click a panel border')
    # Open the searchable menu via its menu bar.
    s.click('Commands')
    s.wait('Repository commands')
    s.click('Switch theme')
    s.wait('Theme: Dark')
    s.wait('Repository commands', absent=True)
    s.click('Samples')
    s.wait('Theme and component samples')
    s.click('Help')
    s.wait('Read-only Git browser')
    s.send(b'\x1b')
    s.wait('Read-only Git browser', absent=True)
    # Geometry must be rebuilt after changing between stacked and side-by-side layouts.
    s.resize(60, 32)
    s.wait('1 Files')
    s.wheel('M Sources/App.swift', down=False, count=3)
    s.click('M README.md')
    s.wait('Selected README.md')
    s.resize(120, 40)
    s.wait('4 Inspect')
    (s.repo / 'new.txt').write_text('external change\n')
    s.click('[Refresh]', 2)
    s.wait('Repository refreshed · read only')
    s.click('Filter files')
    s.send(b'new.txt')
    s.wait('?? new.txt')
    s.click('?? new.txt')
    s.wait('Untracked file')
    (s.repo / 'new.txt').unlink()
    s.click('[Refresh]', 2)
    s.wait('diff --git')
    s.stop()
print('Read-only Git browsing, theme samples, scrolling, caret/paste, modal trapping and resize passed')

# Numbered pane navigation uses application mappings over TerminalUI's modified keys.
for columns, rows in [(120, 40), (60, 32)]:
    with Session(columns=columns, rows=rows) as s:
        s.send(b'\x1b1')
        s.wait('Focus: Files')
        s.send(b'\x1b[B')
        s.wait('Selected Sources/App.swift')
        # CSI-u Alt and modifyOtherKeys Control match the harness's two modifiers.
        s.send(b'\x1b[50;3u')
        s.wait('Focus: Branches')
        s.send(b'\x1b[A')
        s.wait('Inspecting branch feature/mouse')
        s.send(b'\x1b[27;5;51~')
        s.wait('Focus: Commits')
        s.send(b'\x1b[B')
        s.wait('Selected commit')
        s.send(b'\x1b4')
        s.wait('Focus: Inspect')
        s.wait('>*Commit')
        s.send(b'\x1b[D\x1b[D\x1b[D')
        s.wait('>*Git output')
        s.send(b'\x1b[C')
        s.wait('>*Syntax')
        s.send(b'\x1b[C')
        s.wait('>*Components')
        # Tab enters the selected view; Shift+Tab returns to the same strip.
        s.send(b'\t\x1b[Z')
        s.wait('>*Components')
        s.send(b'\x1b[D\t')
        s.wait('>*Swift')
        s.send(b'\x1b[C')
        s.wait('>*Python')
        # Re-entering Inspect must focus its strip even when a nested tab strip was focused.
        s.send(b'\x1b[52;5u')
        s.wait('>*Syntax')
        s.send(b'\x1b3\t')
        s.wait('>*Syntax')
        s.send(b'\x1b[D')
        s.wait('>*Git output')
        s.click('[Working diff]', 2)
        s.send(b'\x1b4\t\x1b[6~')
        s.wait('diff --git', absent=True)
        s.send(b'\x10')
        s.wait('Repository commands')
        s.send(b'\x1b1')
        s.send(b'\x1b[200~Switch theme\x1b[201~')
        s.send(b'\r')
        s.wait('Theme: Dark')
        # Typed and pasted digits remain editor data; pane changes preserve the draft.
        s.click('Filter files')
        s.send(b'12\x1b[200~34\x1b[201~')
        s.wait('1234')
        s.send(b'\x1b3')
        s.wait('Focus: Commits')
        s.send(b'\x1b1')
        s.wait('Focus: Files')
        s.wait('1234')
        s.stop()
print('Alt/Control-number pane focus, immediate navigation, modal trapping and draft preservation passed')

for arguments, by_signal in [((), True), (('--no-mouse',), False)]:
    with Session(*arguments) as s:
        mouse = '--no-mouse' not in arguments
        if not mouse:
            assert b'\x1b[?1000h' not in s.history and b'\x1b[?1006h' not in s.history
            # Keyboard-only navigation remains usable.
            s.send(b'\t\t\x1b[B')
            s.wait('Selected Sources/App.swift')
            s.send(b'\x10')
            s.wait('Repository commands')
            s.send(b'\x1b[200~Switch theme\x1b[201~')
            s.wait('Switch theme')
            s.send(b'\r')
            s.wait('Theme: Dark')
        s.stop(by_signal=by_signal, mouse=mouse)
print('Mouse opt-out, keyboard navigation, Ctrl-C/SIGTERM cleanup and termios restoration passed')

result = subprocess.run([BINARY], stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE, env=ENV, start_new_session=True, timeout=8)
assert result.returncode != 0
assert b'\x1b' not in result.stdout + result.stderr
print('No-controlling-TTY refusal passed')
