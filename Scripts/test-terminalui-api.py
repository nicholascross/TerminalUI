"""Validate real external SwiftPM consumers and the curated public API boundary."""
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
os.chdir(root)

def run(args, **kwargs):
    result = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, **kwargs)
    if result.returncode:
        raise RuntimeError(' '.join(map(str, args)) + '\n' + (result.stdout + result.stderr)[-14000:])
    return result.stdout

graph = json.loads(run(['swift', 'package', 'dump-package']))
products = {product['name'] for product in graph['products']}
assert {'TerminalUI', 'TerminalUIEngine', 'TerminalUIBridge', 'TerminalUIChroma'} <= products
assert not {'TerminalUIComponents', 'TerminalUILayout'} & products
by_name = {target['name']: target for target in graph['targets']}
def dependencies(name):
    return {dependency['byName'][0] for dependency in by_name[name]['dependencies'] if 'byName' in dependency}
assert 'TerminalUIEngine' not in dependencies('TerminalUI')
assert not {'TerminalUI', 'TerminalUIComponentMacros'} & dependencies('TerminalUIEngine')
assert dependencies('TerminalUIBridge') == {'TerminalUI', 'TerminalUIEngine', 'TerminalUICore'}
assert 'TerminalUICore' in dependencies('TerminalUIChroma')
assert dependencies('TerminalUIArgumentParser') == {'TerminalUI', 'TerminalUIComponentMacros'}
assert not {'TerminalUIArgumentParser', 'ArgumentParser'} & dependencies('TerminalUI')
assert not {'TerminalUIArgumentParser', 'ArgumentParser'} & dependencies('TerminalUIEngine')
assert any(dependency.get('product', [None])[0] == 'ArgumentParser' for dependency in by_name['TerminalUIArgumentParser']['dependencies'])
for target in ['TerminalUICore', 'TerminalUIText', 'TerminalUIInput', 'TerminalUILayoutEngine',
               'TerminalUIInteraction', 'TerminalUIRendering', 'TerminalUIRuntime', 'TerminalUIComponentRuntime', 'TerminalUIChroma']:
    assert not {'TerminalUI', 'TerminalUIEngine', 'TerminalUIBridge'} & dependencies(target)
    for path in (root / 'Sources' / target).rglob('*.swift'):
        assert not re.search(r'^.*import (?:TerminalUI|TerminalUIEngine|TerminalUIBridge)$', path.read_text(), re.MULTILINE), path
assert not any('@_exported import' in path.read_text() for path in (root / 'Sources').rglob('*.swift'))
print('Package graph and imports: independent facades, explicit bridge, shared Chroma models and no re-exports passed')

with tempfile.TemporaryDirectory(prefix='terminalui-api-') as directory:
    package = Path(directory)
    manifest = '''// swift-tools-version: 6.3
import PackageDescription
let package = Package(name: "ExternalConsumers", dependencies: [
    .package(name: "TerminalUI", path: ROOT),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.8.2")
], targets: [
    .executableTarget(name: "HighConsumer", dependencies: [.product(name: "TerminalUI", package: "TerminalUI")]),
    .executableTarget(name: "EngineConsumer", dependencies: [.product(name: "TerminalUIEngine", package: "TerminalUI")]),
    .executableTarget(name: "ArgumentConsumer", dependencies: [
        .product(name: "TerminalUI", package: "TerminalUI"),
        .product(name: "TerminalUIArgumentParser", package: "TerminalUI"),
        .product(name: "ArgumentParser", package: "swift-argument-parser")
    ]),
    .executableTarget(name: "BridgeConsumer", dependencies: [
        .product(name: "TerminalUI", package: "TerminalUI"),
        .product(name: "TerminalUIEngine", package: "TerminalUI"),
        .product(name: "TerminalUIBridge", package: "TerminalUI"),
        .product(name: "TerminalUIChroma", package: "TerminalUI")
    ])
])
'''.replace('ROOT', json.dumps(str(root)))
    (package / 'Package.swift').write_text(manifest)
    for target in ['HighConsumer', 'EngineConsumer', 'BridgeConsumer', 'ArgumentConsumer']:
        (package / 'Sources' / target).mkdir(parents=True)
    (package / 'Sources/HighConsumer/Main.swift').write_text((root / 'Tests/Fixtures/PublicAPIConsumer/Consumer.swift').read_text())
    (package / 'Sources/ArgumentConsumer/Main.swift').write_text((root / 'Tests/Fixtures/ArgumentApplicationConsumer/Main.swift').read_text())
    (package / 'Sources/EngineConsumer/Main.swift').write_text('''import TerminalUIEngine
struct Widget: TerminalUIEngine.CustomWidget {
    var id: String? { "widget" }
    var isFocusable: Bool { false }
    func measure(context: WidgetMeasureContext) -> WidgetSize { .init(width: 6, height: 1) }
    func draw(in canvas: inout Canvas, context: WidgetDrawContext) { canvas.write("engine", x: 0, y: 0, style: context.style) }
}
@MainActor final class Legacy: TerminalUIEngine.TerminalApplication {
    func view() -> TerminalUIEngine.Element { .custom(Widget()) }
    func handle(_ action: UIAction) {}
}
@main struct Main {
    @MainActor static func main() {
        let source = LegacyApplicationPresentation(Legacy())
        precondition(TerminalHost().preview(source)[0].contains("engine"))
        var decoder = TerminalUIEngine.InputDecoder()
        precondition(decoder.feed([13]) == [.enter])
    }
}
''')
    (package / 'Sources/BridgeConsumer/Main.swift').write_text('''import TerminalUI
import TerminalUIEngine
import TerminalUIBridge
import TerminalUIChroma
@main struct Main {
    @MainActor static func main() throws {
        let spans = try SyntaxHighlighter().spans("let answer = 42", language: "swift")
        let view = EngineContent(TerminalUIEngine.Element.text("embedded"))
        let source = ViewPresentation(root: TerminalUI.Column {
            view
            TerminalUI.Paragraph(spans)
        })
        let frame = TerminalUIEngine.TerminalHost().preview(source)
        precondition(frame.joined().contains("embedded"))
        precondition(frame.joined().contains("let answer = 42"))
        let raw = TerminalUIEngine.Element.paragraph(spans)
        precondition(UIEngine().render(raw, width: 30, height: 1)[0].contains("let answer = 42"))
    }
}
''')
    # Reuse the workspace build cache; the consumers themselves have no package access.
    build = ['swift', 'build', '--package-path', str(package), '--scratch-path', str(root / '.build'), '-j', '4']
    for product in ['HighConsumer', 'EngineConsumer', 'BridgeConsumer', 'ArgumentConsumer']:
        run(build + ['--product', product])
    bin_path = Path(run(build + ['--show-bin-path']).strip())
    preview = run([str(bin_path / 'HighConsumer'), '--preview'])
    assert 'Workspace' in preview
    run([str(bin_path / 'EngineConsumer')])
    run([str(bin_path / 'BridgeConsumer')])
    assert 'typed-external-preview' in run([str(bin_path / 'ArgumentConsumer'), '--message', 'typed-external-preview', '--preview'])
    for args, exit_code in [(['--message', 'do-not-build', '--help'], 0),
                            (['--message', 'do-not-build', '--unknown'], 64), (['--message'], 64)]:
        result = subprocess.run([str(bin_path / 'ArgumentConsumer'), *args], text=True, capture_output=True)
        assert result.returncode == exit_code, (args, result.stdout, result.stderr)
        assert 'Usage:' in result.stdout + result.stderr or 'USAGE:' in result.stdout + result.stderr
    print('Argument-aware external application: generated initializer, typed preview and help/errors before root construction passed')
    print('External SwiftPM consumers: opaque and typed bodies, generics, private macros, engine/custom widget, both bridges and Chroma passed')

    compiler = ['swiftc', '-typecheck', '-swift-version', '6', '-parse-as-library', '-module-name', 'BoundaryConsumer',
                '-I', str(bin_path / 'Modules'), '-module-cache-path', str(bin_path / 'ModuleCache'),
                '-Xcc', '-fmodule-map-file=' + str(bin_path / 'CTerminalSupport.build/module.modulemap')]
    excluded = ['Element', 'UIEngine', 'TerminalHost', 'InputDecoder', 'FrameEncoder', 'Canvas', 'CellGrid',
                'CustomWidget', 'WidgetMeasureContext', 'WidgetDrawContext', 'TerminalPresentationSource', 'PresentationServices']
    checks = [(name, f'let value: {name}? = nil', f"cannot find type '{name}'") for name in excluded]
    checks += [
        ('removed-component', '@MainActor func check() { _ = Component(Text("x"), key: "x") }', "cannot find 'Component' in scope"),
        ('removed-menu-action', 'let value: MenuAction? = nil', "cannot find type 'MenuAction'"),
        ('removed-menu-action-builder', 'let value: MenuActionBuilder? = nil', "cannot find type 'MenuActionBuilder'"),
        ('inferred-host', '@MainActor func check() { _ = TerminalApp(root: Text("x")).host }', "'host' is inaccessible"),
        ('inferred-presentation', '@MainActor func check() { _ = TerminalApp(root: Text("x")).presentation }', "'presentation' is inaccessible"),
        ('harness-elements', '@MainActor func check() { _ = ApplicationHarness(root: Text("x")).resolve() }', "has no member 'resolve'"),
    ]
    for name, source, expected in checks:
        path = package / (name + '.swift')
        path.write_text('import TerminalUI\n' + source + '\n')
        result = subprocess.run(compiler + [str(path)], text=True, capture_output=True)
        assert result.returncode != 0 and expected in result.stderr, (name, result.stdout, result.stderr)
    print(f'Public boundary: {len(checks)} external compile-failure fixtures passed')

    symbols = package / 'symbols'
    symbols.mkdir()
    triple = json.loads(run(['swiftc', '-print-target-info']))['target']['triple']
    run(['swift', 'symbolgraph-extract', '-module-name', 'TerminalUI', '-I', str(bin_path / 'Modules'), '-target', triple,
         '-minimum-access-level', 'public', '-output-dir', str(symbols), '-module-cache-path', str(bin_path / 'ModuleCache'),
         '-Xcc', '-fmodule-map-file=' + str(bin_path / 'CTerminalSupport.build/module.modulemap')])
    graph = json.loads((symbols / 'TerminalUI.symbols.json').read_text())
    forbidden = re.compile(r'\b(?:' + '|'.join(excluded) + r')\b')
    for symbol in graph['symbols']:
        for fragment in symbol.get('declarationFragments', []):
            # Collection.Element is a generic associated type, not the raw engine Element.
            if forbidden.fullmatch(fragment['spelling']) and fragment.get('preciseIdentifier', '').startswith(('s:14TerminalUICore', 's:17TerminalUIRuntime', 's:19TerminalUIRendering', 's:15TerminalUIInput')):
                raise AssertionError(symbol['pathComponents'])
    print(f'Public symbol graph: {len(graph["symbols"])} declarations inspected without excluded engine types')
