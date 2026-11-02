#!/bin/zsh
set -eu
cd "${0:A:h}"
mkdir -p build
xcrun swiftc -swift-version 5 -warnings-as-errors -module-cache-path "$PWD/build/ModuleCache" Sources/Accessibility.swift Sources/Cancellation.swift Sources/Defaults.swift Sources/WindowLayout.swift Sources/WindowFrameSettlement.swift Sources/WindowTargetResolver.swift Sources/WindowCycleOrder.swift Sources/Chord.swift Sources/KeyboardInput.swift Tests/*.swift -o build/chord-tests
build/chord-tests
