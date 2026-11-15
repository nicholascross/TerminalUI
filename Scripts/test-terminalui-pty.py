"""Read-only repository application PTY checks. Run swift build first."""
import os
from pathlib import Path
import subprocess
import tempfile

from pty_support import ENV, TerminalSession

BINARY = os.path.abspath('.build/debug/RepositoryDemo')


class RepositorySession(TerminalSession):
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
        super().__init__(BINARY, '--repo', str(self.repo), *arguments, columns=columns, rows=rows)

    def __enter__(self):
        try:
            self.wait('Ready · read-only repository')
        except BaseException:
            self.__exit__()
            raise
        return self

    def __exit__(self, *_):
        try:
            super().__exit__()
            assert self.git('status', '--porcelain=v1', '-z') == self.original_status
            assert (self.repo / '.git/index').read_bytes() == self.original_index
            assert self.git('branch', '--show-current').strip() == 'main'
            assert all(Path(path).read_bytes() == data for path, data in self.original_files.items())
        finally:
            self.fixture.cleanup()

    def git(self, *arguments):
        return subprocess.check_output(['git', '-C', str(self.repo), *arguments], stderr=subprocess.DEVNULL).decode()


with RepositorySession() as s:
    assert b'\x1b[?1000h' in s.history and b'\x1b[?1006h' in s.history
    s.click('MM Sources/Mouse.swift')
    s.wait('Working diff · Sources/Mouse.swift')
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
    s.send(b'\x10')
    s.send(b'\x1b[200~Repository help\x1b[201~\r')
    s.wait('Read-only Git browser')
    s.send(b'\x1b')
    s.wait('Read-only Git browser', absent=True)
    s.resize(60, 32)
    s.wait('Files ·')
    s.wheel('Sources/', down=False, count=30)
    s.click('M README.md')
    s.wait('Working diff · README.md')
    s.resize(120, 40)
    s.wait('Inspect · Working diff · README.md')
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
print('Read-only Git browsing, diff scrolling, branch/commit inspection, refresh, dialogs and resize passed')

for columns, rows in [(120, 40), (60, 32)]:
    with RepositorySession(columns=columns, rows=rows) as s:
        s.send(b'\x1b1\x1b[B')
        s.wait('Working diff · Sources/App.swift')
        s.send(b'\x1b[50;3u\x1b[A')
        s.wait('Inspecting branch feature/mouse')
        s.send(b'\x1b[27;5;51~\x1b[B')
        s.wait('Selected commit')
        # Empty commits fit entirely in a large viewport; select a patch before checking scrolling.
        s.send(b'\x1b[F')
        initial_hash = s.git('rev-list', '--max-parents=0', 'HEAD').strip()[:7]
        s.wait('Selected commit ' + initial_hash)
        s.send(b'\x1b4\x1b[6~')
        s.wait('↑/↓ scroll')
        s.wait('Author:', absent=True)
        s.send(b'\x10')
        s.wait('Repository commands')
        s.send(b'\x1b1')
        s.send(b'\x1b[200~Refresh repository\x1b[201~\r')
        s.wait('Repository refreshed · read only')
        s.click('Filter files')
        s.send(b'12\x1b[200~34\x1b[201~')
        s.wait('1234')
        s.send(b'\x1b3\x1b1')
        s.wait('1234')
        s.stop()
print('Alt/Control-number pane navigation, modal trapping and filter preservation passed')

for arguments, by_signal in [((), True), (('--no-mouse',), False)]:
    with RepositorySession(*arguments) as s:
        mouse = '--no-mouse' not in arguments
        if not mouse:
            assert b'\x1b[?1000h' not in s.history and b'\x1b[?1006h' not in s.history
            s.send(b'\x1b1\x1b[B')
            s.wait('Working diff · Sources/App.swift')
            s.send(b'\x10')
            s.send(b'\x1b[200~Refresh repository\x1b[201~\r')
            s.wait('Repository refreshed · read only')
        s.stop(by_signal=by_signal, mouse=mouse)
print('Mouse opt-out, keyboard navigation, Ctrl-C/SIGTERM cleanup and termios restoration passed')

result = subprocess.run([BINARY], stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE, env=ENV, start_new_session=True, timeout=8)
assert result.returncode != 0
assert b'\x1b' not in result.stdout + result.stderr
print('No-controlling-TTY refusal passed')

with tempfile.TemporaryDirectory(prefix='terminalui-startup-') as directory:
    for arguments, exit_code in [(['--help'], 0), (['--repo'], 64), (['--unknown'], 64)]:
        result = subprocess.run([BINARY, *arguments], cwd=directory, env=ENV,
                                stdin=subprocess.DEVNULL, capture_output=True, timeout=8)
        assert result.returncode == exit_code, (arguments, result.stdout, result.stderr)
        assert b'\x1b' not in result.stdout + result.stderr
        assert b'Repository unavailable' not in result.stdout + result.stderr
    result = subprocess.run([BINARY, '--preview'], cwd=directory, env=ENV,
                            stdin=subprocess.DEVNULL, capture_output=True, timeout=8)
    assert result.returncode == 0
    assert b'Repository unavailable' in result.stdout
    assert b'\x1b' not in result.stdout + result.stderr
    # A screen failure remains a usable application, with both Quit and Retry paths.
    with TerminalSession(BINARY, '--repo', directory) as s:
        s.wait('Repository unavailable')
        s.stop()
    with TerminalSession(BINARY, '--repo', directory) as s:
        s.wait('Repository unavailable')
        subprocess.run(['git', '-C', directory, 'init', '-b', 'main'], check=True, capture_output=True)
        s.send(b'\r')
        s.wait('Ready · read-only repository')
        s.wait('Repository unavailable', absent=True)
        s.stop()
print('Generated help/argument errors, repository failure previews, screen retry and error-screen quit passed')
