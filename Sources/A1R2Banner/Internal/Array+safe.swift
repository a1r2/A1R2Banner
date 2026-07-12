// Copyright © 2026 Adriano Rossi Ramos / A1R2
//
// This file was created under the direction and creative control of the
// copyright holder, with assistance from AI tools (Claude/Prometheus/OpenClaw).
// Architectural decisions, requirements, and design are solely the work
// of the human author.
//
// All rights reserved.


extension Array {
    /// Bounds-checked subscript used by the offset math.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
