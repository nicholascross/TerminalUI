"""Compile a public-API consumer and verify idle updates, scoped editors and teardown on a PTY."""
import fcntl
import os
import pathlib
import pty
import re
import select
import signal
import struct
import subprocess
import tempfile
import termios
import time

from pty_support import module_objects

root = pathlib.Path(__file__).resolve().parent.parent
os.chdir(root)
bin_path = subprocess.check_output(['swift', 'build', '--show-bin-path'], text=True).strip()
modules = ['CTerminalSupport', 'TerminalUICore', 'TerminalUIText', 'TerminalUIInput',
           'TerminalUILayoutEngine', 'TerminalUIInteraction', 'TerminalUIRendering',
           'TerminalUIRuntime', 'TerminalUI', 'TerminalUIComponentRuntime']
objects = module_objects(bin_path, modules)
with tempfile.TemporaryDirectory(prefix='terminalui-components-') as directory:
    executable = f'{directory}/ComponentHostProbe'
    subprocess.run(['swiftc', '-swift-version', '6', '-parse-as-library',
                    '-I', f'{bin_path}/Modules', '-module-cache-path', f'{bin_path}/ModuleCache',
                    '-Xcc', f'-fmodule-map-file={bin_path}/CTerminalSupport.build/module.modulemap',
                    '-load-plugin-executable', f'{bin_path}/TerminalUIComponentMacros-tool#TerminalUIComponentMacros',
                    'Tests/Fixtures/ComponentHostProbe/Main.swift', *objects, '-o', executable], check=True)
    master, slave = pty.openpty()
    original = termios.tcgetattr(slave)
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 20, 60, 0, 0))

    def setup():
        os.setsid()
        fcntl.ioctl(slave, termios.TIOCSCTTY, 0)

    process = subprocess.Popen([executable], stdin=slave, stdout=slave, stderr=slave,
                               env=dict(os.environ, TERM='xterm-256color'), preexec_fn=setup)
    history = bytearray()

    def screen():
        cells = [[' '] * 60 for _ in range(20)]
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
                    cells = [[' '] * 60 for _ in range(20)]
                index += len(match[0])
            else:
                char = text[index]
                if char.isprintable() and 0 <= row < 20 and 0 <= column < 60:
                    cells[row][column] = char
                    column += 1
                index += 1
        return '\n'.join(''.join(row) for row in cells)

    def wait_for(value):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if select.select([master], [], [], .02)[0]:
                history.extend(os.read(master, 65536))
            if value in screen():
                return
        raise AssertionError(value + '\n' + screen())

    try:
        wait_for('Component idle probe')
        # No input is sent before the scheduled main-actor state write.
        wait_for('idle change')
        os.write(master, b'\r')
        wait_for('Submitted 11 characters')
        os.write(master, b'ab\x1b[13;2u\x1b[200~c\nx\x1b[201~\r')
        wait_for('Submitted 6 characters')
        os.write(master, b'first-draft\x1b2second-draft\x1b1\r')
        wait_for('Submitted 11 characters')
        os.write(master, b'\x1b2\r')
        wait_for('Submitted 12 characters')
        os.write(master, b'\x03')
        process.wait(timeout=5)
        assert process.returncode == 0
        assert termios.tcgetattr(slave) == original
        print('Component PTY: idle state update, two scoped editors, batched typing/submit, draft survival and terminal restoration passed')
    finally:
        if process.poll() is None:
            process.send_signal(signal.SIGTERM)
            process.wait(timeout=5)
        os.close(master)
        os.close(slave)
