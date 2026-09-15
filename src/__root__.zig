//! `srapnol`: a sparse nonlinear optimizer with an snOptA-style problem
//! interface (`F(x) = f(x) + A x`, bounds on `x` and `F`), written in Zig.
//! The public surface (SRS-057): `Problem`, `Options`, `Solver`, `State`,
//! `Result`, `Exit`, `Start`, `VarState`, `infinity`, and `solve`. The
//! documentation set lives in `docs/` (start at `docs/README.md`). Run the
//! test rig with `zig build test`; the end-to-end solve tests skip until
//! `Solver.solve` is implemented.

const std = @import("std");

pub const main = @import("__main__.zig").main;
// pub const std_options = impl.std_options;
// pub const std_options_debug_io = impl.std_options_debug_io;

const build_options = @import("build_options");
pub const version = build_options.version;
pub const app_name = "srapnol";

pub const Problem = @import("Problem.zig");
pub const Options = @import("Options.zig");
pub const Solver = @import("Solver.zig");

pub const State = Solver.State;
pub const Result = Solver.Result;
pub const Exit = Solver.Exit;
pub const Start = Solver.Start;
pub const VarState = Solver.VarState;

/// Bounds at or beyond this magnitude are treated as infinite.
pub const infinity: f64 = Problem.infinity;

/// One-shot convenience (SRS-074): validate, allocate a workspace, cold-start solve, free.
pub fn solve(allocator: std.mem.Allocator, problem: *const Problem, options: Options, state: *State) Solver.Error!Result {
    var solver = try Solver.init(allocator, problem, options);
    defer solver.deinit();
    return solver.solve(state, .cold);
}

test {
    std.testing.refAllDecls(@This());
    _ = @import("test/support.zig");
    _ = @import("test/truss.zig");
    _ = @import("test/toy.zig");
    _ = @import("test/hs47.zig");
    _ = @import("test/hs15.zig");
    _ = @import("test/hs76.zig");
}
