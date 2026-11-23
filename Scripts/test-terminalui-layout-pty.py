"""Linux PTY checks for negotiated layout. Run `swift build` first."""
import fcntl
import os
import pty
import re
import select
import signal
import struct
import subprocess
import sys
import termios
import time
master, slave = pty.openpty()
original = termios.tcgetattr(slave)
fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 24, 80, 0, 0))
def setup():
    os.setsid()
    fcntl.ioctl(slave, termios.TIOCSCTTY, 0)
mouse_enabled = '--no-mouse' not in sys.argv
process = subprocess.Popen(['.build/debug/LayoutDemo', *sys.argv[1:]], stdin=slave, stdout=slave, stderr=slave,
                           env=dict(os.environ, TERM='xterm-256color', COLORTERM='truecolor', NO_COLOR=''), preexec_fn=setup)
history = bytearray()
def screen():
    cells = [[' '] * 100 for _ in range(40)]
    row = column = 0
    text = history.decode('utf-8', errors='replace')
    index = 0
    while index < len(text):
        match = re.match(r'\x1b\[([0-9;?]*)([ -/]*)([@-~])', text[index:])
        if match:
            if match[3] in ('H', 'f'):
                parts = match[1].split(';')
                row = int(parts[0] or '1') - 1
                column = int(parts[1] or '1') - 1 if len(parts) > 1 else 0
            elif match[3] == 'J' and match[1] == '2':
                cells = [[' '] * 100 for _ in range(40)]
            index += len(match[0])
        else:
            char = text[index]
            if char.isprintable() and 0 <= row < 40 and 0 <= column < 100:
                cells[row][column] = char
                column += 1
            index += 1
    return '\n'.join(''.join(row) for row in cells)
def wait_for(value, row=None, absent=False, column=None):
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        if select.select([master], [], [], .05)[0]:
            history.extend(os.read(master, 65536))
        rendered = screen()
        line = rendered if row is None else rendered.splitlines()[row]
        found = value in line if column is None else line.startswith(value, column)
        if found != absent:
            return
    raise AssertionError(value + '\n' + screen())
try:
    wait_for('TerminalUILayout')
    wait_for('Inspector')
    wait_for('> Negotiated layout')
    wait_for('select a topic')
    assert (b'\x1b[?1002h' in history) == mouse_enabled
    assert (b'\x1b[?1006h' in history) == mouse_enabled
    if mouse_enabled:
        wait_for('┼')
        row = next(index for index, line in enumerate(screen().splitlines()) if '┼' in line)
        wait_for('┼', row=row, column=25)
        os.write(master, f'\x1b[<0;26;{row + 1}M\x1b[<32;32;{row + 1}M'.encode())
        wait_for('┼', row=row, column=31)
        os.write(master, f'\x1b[<0;34;{row + 1}m'.encode())
        wait_for('┼', row=row, column=33)
        wait_for('> Negotiated layout')
    else:
        assert '┼' not in screen()
    os.write(master, b'\x1b3')
    wait_for('Focus: Command')
    wait_for('Shift+Enter newline')
    os.write(master, b'\x1b[200~hello\nworld\x1b[201~')
    wait_for('hello')
    wait_for('world')
    previous_frame = len(history)
    os.write(master, b'\x1bt')
    wait_for('Restore theme')
    assert b'48;2;248;249;252' in history[previous_frame:]
    wait_for('Focus: Command')
    wait_for('world')
    previous_frame = len(history)
    os.write(master, b'\x1bt')
    wait_for('Light theme')
    assert b'48;2;46;52;64' in history[previous_frame:]
    wait_for('Focus: Command')
    wait_for('world')
    os.write(master, b'\x1b1')
    wait_for('Focus: Topics')
    os.write(master, b'\x1b2')
    wait_for('Focus: Inspector')
    wait_for('PgUp/PgDn page')
    # CSI-u reports Control+3 distinctly. Plain and pasted digits remain editor data.
    os.write(master, b'\x1b[51;5u')
    wait_for('Focus: Command')
    os.write(master, b'12\x1b[200~34\x1b[201~')
    wait_for('world1234')
    os.write(master, b'\x10')
    wait_for('Layout commands')
    os.write(master, b'\x1b')
    wait_for('Layout commands', absent=True)
    wait_for('world1234')
    os.write(master, b'\x10\x1b[200~Inspector\x1b[201~')
    wait_for('Focus Inspector')
    os.write(master, b'\r')
    wait_for('Layout commands', absent=True)
    wait_for('Focus: Inspector')
    os.write(master, b'\x1b3')
    wait_for('Focus: Command')
    wait_for('world1234')
    if mouse_enabled:
        column = screen().splitlines()[2].index('[Notifications]') + 2
        os.write(master, f'\x1b[<0;{column};3M\x1b[<0;{column};3m'.encode())
    else:
        os.write(master, b'\x1bn')
    wait_for('>[Acknowledgement]')
    wait_for('TerminalUILayout', row=0)
    os.write(master, b'\r')
    wait_for('>[OK]')
    os.write(master, b'\r')
    if mouse_enabled:
        wait_for('>[Notifications]', row=2)
        os.write(master, b'\x1b3')
    wait_for('Focus: Command')
    wait_for('world1234')
    os.write(master, b'\x1bn\t\t')
    wait_for('>[Success banner]')
    os.write(master, b'\r')
    wait_for('Success · This sample clears')
    wait_for('Success · This sample clears', absent=True)
    wait_for('world1234')
    # CSI-u Shift+Enter inserts a newline; ordinary Enter submits the complete draft.
    os.write(master, b'\x1b[13;2unext')
    wait_for('world1234')
    wait_for('next')
    os.write(master, b'\r')
    wait_for('Submitted 20 characters')
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 18, 60, 0, 0))
    os.kill(process.pid, signal.SIGWINCH)
    wait_for('Submitted 20 characters', row=14)
    wait_for('Ctrl-C quit', row=17)
    wait_for('╮', row=4, column=33 if mouse_enabled else 25)
    # Click the persistent toolbar after resize, using its current cell coordinates.
    if mouse_enabled:
        column = screen().splitlines()[2].index('2 Inspector') + 2
        os.write(master, f'\x1b[<0;{column + 1};3M\x1b[<0;{column + 1};3m'.encode())
        wait_for('Focus: Inspector')
    os.write(master, b'\x03')
    process.wait(timeout=5)
    while select.select([master], [], [], .05)[0]:
        history.extend(os.read(master, 65536))
    assert process.returncode == 0
    assert termios.tcgetattr(slave) == original
    for sequence in [b'\x1b[?1049l', b'\x1b[?2004l', b'\x1b[?25h']:
        assert sequence in history
    if mouse_enabled:
        assert b'\x1b[?1002l' in history and b'\x1b[?1006l' in history
    print(f'LayoutDemo PTY (mouse={mouse_enabled}): focus, command menu, draft, theme swapping, resize and restoration passed')
    print('Compact notification dialogs, acknowledgement and transient banner passed')
    if mouse_enabled:
        print('Topics pane drag, release and size retention passed')
finally:
    if process.poll() is None:
        process.terminate()
        process.wait(timeout=5)
    os.close(master)
    os.close(slave)
