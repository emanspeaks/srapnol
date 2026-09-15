const std = @import("std");
const builtin = @import("builtin");
const build_options = @import("build_options");

const rstd = @import("rstd");

const app_name = "srapnol-test";
const version = build_options.version;

pub fn main(init: rstd.zigstd.MainInit) !void {
    // const allocator = init.gpa;

    std.debug.print(app_name ++ " v" ++ version ++ " Starting...\n", .{});

    _ = init;

    std.debug.print(app_name ++ " v" ++ version ++ " exiting gracefully\n", .{});
}
