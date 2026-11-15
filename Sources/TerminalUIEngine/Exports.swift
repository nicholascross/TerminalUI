// This facade preserves existing imports and qualified source names.
// Nominal types are owned by their implementation modules; see Documentation/Architecture.md.
public import TerminalUICore
public import TerminalUIInput
public import TerminalUIRendering
public import TerminalUIRuntime

// TerminalUICore
public typealias Alignment = TerminalUICore.Alignment
public typealias BorderCharacters = TerminalUICore.BorderCharacters
public typealias Canvas = TerminalUICore.Canvas
public typealias Cell = TerminalUICore.Cell
public typealias CellGrid = TerminalUICore.CellGrid
public typealias CellWidth = TerminalUICore.CellWidth
public typealias ColorCapability = TerminalUICore.ColorCapability
public typealias CustomWidget = TerminalUICore.CustomWidget
public typealias Element = TerminalUICore.Element
public typealias Insets = TerminalUICore.Insets
public typealias KeyEvent = TerminalUICore.KeyEvent
public typealias LayoutSize = TerminalUICore.LayoutSize
public typealias LayoutProposal = TerminalUICore.LayoutProposal
public typealias LayoutPreference = TerminalUICore.LayoutPreference
public typealias LayoutSubview = TerminalUICore.LayoutSubview
public typealias LayoutPlacement = TerminalUICore.LayoutPlacement
public typealias ElementLayout = TerminalUICore.ElementLayout
public typealias ListRow = TerminalUICore.ListRow
public typealias MenuItem = TerminalUICore.MenuItem
public typealias MouseEvent = TerminalUICore.MouseEvent
public typealias StyleOverride = TerminalUICore.StyleOverride
public typealias Tab = TerminalUICore.Tab
public typealias TableColumn = TerminalUICore.TableColumn
public typealias TableRow = TerminalUICore.TableRow
public typealias TerminalEvent = TerminalUICore.TerminalEvent
public typealias TerminalSize = TerminalUICore.TerminalSize
public typealias TextRole = TerminalUICore.TextRole
public typealias TextSpan = TerminalUICore.TextSpan
public typealias TextStyle = TerminalUICore.TextStyle
public typealias Theme = TerminalUICore.Theme
public typealias UIAction = TerminalUICore.UIAction
public typealias UIEventResult = TerminalUICore.UIEventResult
public typealias WidgetDrawContext = TerminalUICore.WidgetDrawContext
public typealias WidgetEventContext = TerminalUICore.WidgetEventContext
public typealias WidgetMeasureContext = TerminalUICore.WidgetMeasureContext
public typealias WidgetMouseContext = TerminalUICore.WidgetMouseContext
public typealias WidgetResponse = TerminalUICore.WidgetResponse
public typealias WidgetSize = TerminalUICore.WidgetSize

/// TerminalUIInput
public typealias InputDecoder = TerminalUIInput.InputDecoder

// TerminalUIRendering
public typealias FrameEncoder = TerminalUIRendering.FrameEncoder
public typealias UIEngine = TerminalUIRendering.UIEngine

// TerminalUIRuntime
public typealias TerminalApplication = TerminalUIRuntime.TerminalApplication
public typealias TerminalConfiguration = TerminalUIRuntime.TerminalConfiguration
public typealias TerminalError = TerminalUIRuntime.TerminalError
public typealias TerminalHost = TerminalUIRuntime.TerminalHost

// Presentation contracts also support optional component sources without importing that product.
public typealias TerminalPresentationSource = TerminalUICore.TerminalPresentationSource
public typealias PresentationServices = TerminalUICore.PresentationServices
public typealias ScopedFocusTarget = TerminalUICore.ScopedFocusTarget
public typealias LegacyApplicationPresentation = TerminalUIRuntime.LegacyApplicationPresentation

public typealias RenderingMetrics = TerminalUICore.RenderingMetrics

public typealias StackLayout = TerminalUICore.StackLayout
