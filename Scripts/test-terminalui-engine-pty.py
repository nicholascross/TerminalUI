"""Check the small engine example and private engine interaction fixture. Run swift build first."""
import os
from pathlib import Path
import subprocess
import tempfile

from pty_support import TerminalSession, module_objects

root = Path(__file__).resolve().parent.parent
os.chdir(root)
binary = root / '.build/debug/EngineDemo'

for arguments in [(), ('--no-mouse',)]:
    with TerminalSession(binary, *arguments, columns=80, rows=24) as session:
        session.wait('TerminalUI Engine')
        session.send(b'\x1b[B')
        session.wait('TerminalHost decodes input')
        session.send(b'\t\t\x1b[200~!\x1b[201~')
        session.wait('Edit this in-memory note.!')
        session.stop(mouse='--no-mouse' not in arguments)
print('EngineDemo selection, text input, mouse opt-out and terminal restoration passed')

# Keep regression controls out of the public examples, just as ComponentHostProbe does.
bin_path = Path(subprocess.check_output(['swift', 'build', '--show-bin-path'], text=True).strip())
modules = ['CTerminalSupport', 'TerminalUICore', 'TerminalUIText', 'TerminalUIInput',
           'TerminalUILayoutEngine', 'TerminalUIInteraction', 'TerminalUIRendering',
           'TerminalUIRuntime', 'TerminalUIEngine']
objects = module_objects(bin_path, modules)
with tempfile.TemporaryDirectory(prefix='terminalui-engine-') as directory:
    probe = Path(directory) / 'EngineInteractionProbe'
    subprocess.run(['swiftc', '-swift-version', '6', '-parse-as-library',
                    '-I', str(bin_path / 'Modules'), '-module-cache-path', str(bin_path / 'ModuleCache'),
                    '-Xcc', f'-fmodule-map-file={bin_path}/CTerminalSupport.build/module.modulemap',
                    'Tests/Fixtures/EngineInteractionProbe/Main.swift', *objects, '-o', str(probe)], check=True)
    with TerminalSession(probe) as s:
        s.wait('Engine interaction probe')
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
        s.send(b'?')
        s.wait('L29?able scratchpad')
        s.wheel('Nested row 0', count=1)
        s.wait('Nested row 3')
        s.wait('Cl!ick to place caret:')
        s.wheel('Nested row 3', count=12)
        s.wait('Cl!ick to place caret:', absent=True)
        s.wait('Outer row')
        previous_frame = len(s.history)
        s.click('Change theme')
        assert b'48;2;248;249;252' in s.history[previous_frame:]
        s.resize(60, 24)
        s.wait('Engine interaction probe')
        s.stop()
    with TerminalSession(probe, '--resize-probe', columns=50, rows=12) as s:
        s.wait('Saved width: pending')
        assert b'\x1b[?1002h' in s.history and b'\x1b[?1006h' in s.history
        assert s.screen()[0][17] == '╮'
        s.mouse((17, 1))
        s.mouse((21, 1), code=32)
        assert s.screen()[0][21] == '╮'
        s.mouse((34, 0), release=True)
        s.wait('Saved width: 27')
        assert s.screen()[0][26] == '╮'
        assert b'\x1b]52;' not in s.history
        s.resize(32, 12)
        s.wait('Saved width: 27')
        assert not any('┼' in line for line in s.screen())
        s.resize(50, 12)
        s.wait('Saved width: 27')
        assert s.screen()[0][26] == '╮'
        s.stop(mouse_mode=1002)
print('Engine caret placement, multiline paste, nested wheel routing, live theme change and resize passed')
print('Panel drag without clipboard copying, final release, narrow-terminal recovery and mouse teardown passed')
