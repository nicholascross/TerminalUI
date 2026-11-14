#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bin=$(swift build --show-bin-path)
swiftc -typecheck -parse-as-library -swift-version 6 -module-name ExternalComponentConsumer \
    -I "$bin/Modules" -module-cache-path "$bin/ModuleCache" \
    -Xcc "-fmodule-map-file=$bin/CTerminalSupport.build/module.modulemap" \
    -load-plugin-executable "$bin/TerminalUIComponentMacros-tool#TerminalUIComponentMacros" \
    Examples/ComponentConsumer/Consumer.swift
