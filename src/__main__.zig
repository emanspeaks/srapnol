const std = @import("std");
const root = @import("root");
const builtin = @import("builtin");

const rstd = @import("rstd");

const app_name = "srapnol-test";
const version = root.version;

pub fn main(init: rstd.zigstd.MainInit) !void {
    // const allocator = init.gpa;

    std.debug.print(app_name ++ " v" ++ version ++ " Starting...\n", .{});

    _ = init;

    std.debug.print(app_name ++ " v" ++ version ++ " exiting gracefully\n", .{});
}
