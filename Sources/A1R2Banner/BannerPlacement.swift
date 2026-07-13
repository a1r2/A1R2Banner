// Copyright © 2026 Adriano Rossi Ramos / A1R2
//
// This file was created under the direction and creative control of the
// copyright holder, with assistance from AI tools (Claude/Prometheus/OpenClaw).
// Architectural decisions, requirements, and design are solely the work
// of the human author.
//
// All rights reserved.


/// Legacy placement mode. **No longer affects layout** — banner positioning is
/// now unified and safe-area aware on every platform (a banner attached as an
/// `.overlay` on a bounded container hugs that container's corner regardless).
/// Retained only so existing call sites keep compiling; prefer the
/// `BannerView(banner:duration:stackOffset:)` initializer.
public enum BannerPlacement: Sendable, Hashable {
    case adaptive
    case fixed
}
