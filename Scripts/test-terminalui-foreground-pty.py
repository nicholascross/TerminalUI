"""Check macOS kqueue input during a foreground handoff. Build RepositoryDemo first."""
import os
from pathlib import Path
import select
import shlex
import subprocess
import sys
import tempfile

from pty_support import ENV, TerminalSession


def watch_input():
    with select.kqueue() as queue:
        watch = select.kevent(0, filter=select.KQ_FILTER_READ, flags=select.KQ_EV_ADD)
        queue.control([watch], 0, 0)
        if os.fstat(0).st_rdev == os.stat('/dev/tty').st_rdev:
            raise RuntimeError('Expected inherited PTY stdin, got /dev/tty')
        print('\x1b[2J\x1b[1;1HWaiting for foreground input', flush=True)
        events = queue.control(None, 1, 8)
        if not events or events[0].flags & select.KQ_EV_ERROR:
            raise RuntimeError(f'Expected stdin readiness, got {events!r}')
        if os.read(0, 1024) != b'x\n':
            raise RuntimeError('Unexpected input on foreground stdin')


def check_handoff(binary):
    editor = shlex.join([sys.executable, str(Path(__file__).resolve()), '--watch-input'])
    with tempfile.TemporaryDirectory(prefix='terminalui-foreground-') as directory:
        repo = Path(directory)
        subprocess.run(['git', 'init', '-q', '-b', 'main'], cwd=repo, check=True)
        (repo / 'fixture.txt').write_text('Foreground test\n')
        subprocess.run(['git', 'add', 'fixture.txt'], cwd=repo, check=True)

        with TerminalSession(binary, '--repo', str(repo), env=dict(ENV, GIT_EDITOR=editor)) as session:
            try:
                session.wait('Ready · read-only repository')
                session.send(b'e')
                session.wait('Waiting for foreground input')
                session.send(b'x\r')
                session.wait('Repository refreshed')
                session.stop()
            except AssertionError:
                # The restored dashboard can overwrite the child's traceback on screen.
                print(session.history.decode(errors='replace'), file=sys.stderr)
                raise
    print('Foreground command received input through kqueue and returned to the dashboard')


if __name__ == '__main__':
    if sys.argv[1] == '--watch-input':
        watch_input()
    else:
        check_handoff(Path(sys.argv[1]).resolve())
