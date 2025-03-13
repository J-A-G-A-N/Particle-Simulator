const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        //exe-name-T-C-WD-PD-R
        .name = "PS-L",
        .root_module = exe_mod,
    });
    exe.linkLibC();

        const options = .{
        .enable_ztracy = b.option(
            bool,
            "enable_ztracy",
            "Enable Tracy profile markers",
        ) orelse false,
        .enable_fibers = b.option(
            bool,
            "enable_fibers",
            "Enable Tracy fiber support",
        ) orelse false,
        .on_demand = b.option(
            bool,
            "on_demand",
            "Build tracy with TRACY_ON_DEMAND",
        ) orelse false,
    };
     
        const ztracy = b.dependency("ztracy", .{
        .enable_ztracy = options.enable_ztracy,
        .enable_fibers = options.enable_fibers,
        .on_demand = options.on_demand,
    });
    exe.root_module.addImport("ztracy", ztracy.module("root"));
    exe.linkLibrary(ztracy.artifact("tracy"));
   
    const zsdl = b.dependency("zsdl", .{});
    exe.root_module.addImport("zsdl2", zsdl.module("zsdl2"));
    exe.root_module.addImport("zsdl2_image", zsdl.module("zsdl2_image"));
    exe.root_module.addImport("zsdl2_ttf", zsdl.module("zsdl2_ttf"));


    //@import("zsdl").prebuilt_sdl2.addLibraryPathsTo(exe);
    @import("zsdl").link_SDL2(exe);
    @import("zsdl").link_SDL2_ttf(exe);
    @import("zsdl").link_SDL2_image(exe);


    
    @import("zsdl").prebuilt_sdl2.addLibraryPathsTo(exe);
    if (@import("zsdl").prebuilt_sdl2.install(b, target.result, .bin,.{
        .ttf = true,
        .image = true,
    })) |install_sdl2_step| {
        b.getInstallStep().dependOn(install_sdl2_step);
    }


    const exe_options = b.addOptions();
    exe.root_module.addOptions("build_options", exe_options);

   


    b.installArtifact(exe);
    
    const zmath = b.dependency("zmath", .{});
    exe.root_module.addImport("zmath", zmath.module("root"));

     const zopengl = b.dependency("zopengl", .{});
    exe.root_module.addImport("zopengl", zopengl.module("root"));    
    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

}
