const std = @import("std");

pub const zon = @import("../build.zig.zon");
pub const rstd = @import("rstd");

const rstdbuild = rstd.buildutils;
const Build = rstdbuild.Build;

pub fn build(b: *std.Build) !void {
    const target = rstdbuild.getTarget(b);
    const optimize = rstdbuild.getOptimize(b);
    const docs = rstdbuild.addDocs(b);

    const mod = b.createModule(.{
        .root_source_file = b.path("src/__root__.zig"),
        .target = target,
        .optimize = optimize,
        // .link_libc = true,
    });

    const build_options = rstdbuild.addBuildOptionsModule(b, @tagName(zon.name), zon.version);
    rstdbuild.addBuildOptsModToModule(build_options, mod);

    const rstd_mod = try rstdbuild.addRstd(b, target, docs, false);
    rstd_mod.addImportToModule(mod);

    const exe = b.addExecutable(.{
        .name = "srapnol-test",
        .root_module = mod,
    });
    docs.addCompileStepDocs(b, exe, "srapnol-test");
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    const run_cmd_step = &run_cmd.step;
    run_cmd_step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();

    const run_step = b.step("run", "Run the program");
    run_step.dependOn(run_cmd_step);

    const tests = b.addTest(.{ .root_module = mod });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run srapnol's unit tests");
    test_step.dependOn(&run_tests.step);
}
