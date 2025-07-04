const std = @import("std");
const stdout = std.io.getStdOut().writer();
const sdl = @import("zsdl2");

const gui_file = @import("gui.zig");
const Gui = gui_file.Gui;

// Core
const core = @import("core.zig");
const Particles = core.Particles;
const Spawner = core.Spawner;
const Solver = core.Solver;
const SpatialHashGrid = core.SpatialHashGrid;

// Global varibales
var gui: Gui = undefined;
var texture = gui_file.Texture_2D{ .texture = null };

// With More variables like this this should be in the state struct
var quit: bool = false;
var frame_rate: u64 = 60;
var pause: bool = false;
var next_frame: bool = false;

const window_width: i32 = 720;
const window_height: i32 = 640;
const boundary_damping: f64 = 0.1;
const particle_damping: f64 = 0.9;
const g: f64 = 50;

var particles: Particles = undefined;
var slover: Solver = undefined;
var shg: SpatialHashGrid = undefined;

fn init(title: ?[*:0]const u8, width: i32, height: i32) !void {
    try sdl.init(.{
        .audio = false,
        .video = true,
    });
    try stdout.print("SDL Error:{any}\n", .{sdl.getError()});

    gui = try Gui.init(title, width, height);
    try texture.loadTexture(gui.renderer, "assets/circle.png");

    var rng = std.Random.DefaultPrng.init(@intCast(std.time.microTimestamp()));

    const allocator = std.heap.c_allocator;

    // Single Physics loop per frame with const velocity
    // {
    // generic ReleaseFast-> 5500
    // single-threaded debug -> 20k
    // single-threaded ReleaseFast- -> 35k
    // }

    // 8 Sub- Physics loop per frame with  acceleration
    // // {
    // SpatialHashGrid
    // single-threaded debug -> 3k
    // single-threaded ReleaseFast- -> 13k
    // }

    const particles_count: usize = 13_000;
    const particles_radius = 2.0;
    particles = try .init(allocator, particles_count, particles_radius);

    const max: f64 = @floatFromInt(@min(height, width));
    //const max: f64 = 100;
    const min: f64 = -max;
    try Spawner.spawnRandom(&particles, &rng, window_width, window_height, min, max);

    slover = Solver.init(@floatFromInt(frame_rate), 8, g, boundary_damping, particle_damping);

    const grid_size: f64 = 2.0 * particles_radius;
    shg = try SpatialHashGrid.init(allocator, window_width, window_height, grid_size, particles_count);
}
fn deinit() void {
    particles.deinit();
    shg.deinit();
    gui.deinit();
}

pub fn main() !void {
    const title = "Particle-Simulation";
    try init(title, window_width, window_height);
    defer deinit();

    while (!shouldQuit()) {
        const last_time_stamp_ns = std.time.nanoTimestamp();
        try updateAndRender();
        gui.maintainFPS(last_time_stamp_ns, frame_rate);
    }
}

fn updateAndRender() !void {
    var event: sdl.Event = undefined;
    while (sdl.pollEvent(&event)) {
        handle_event(&event);
    }
    try gui.renderer.clearScreen(black);
    try gui.renderer.sdl_renderer.clear();
    const radius: f32 = @floatCast(particles.radius);
    for (particles.positions, particles.colors) |pos, col| {
        const x: f32 = @floatCast(pos[0]);
        const y: f32 = @floatCast(pos[1]);
        try gui.renderer.drawCircle(texture, radius, x, y, col);
    }
    if (!pause or next_frame) {
        try slover.updatePhysics(&particles, @floatFromInt(window_width), @floatFromInt(window_height), &shg);
        //slover._applyBoundary(&particles.positions, &particles.velocities, particles.radius, window_width, window_height);
        next_frame = false;
    }
    gui.renderer.sdl_renderer.present();
}

fn handle_event(event: *sdl.Event) void {
    switch (event.type) {
        .quit => quit = true,
        .keydown => |_| {
            switch (event.key.keysym.sym) {
                .escape => quit = !quit,
                .space => pause = !pause,
                .right => next_frame = true,
                .g => slover.toggle_acc(),
                else => {},
            }
        },
        else => {},
    }
}
fn shouldQuit() bool {
    return quit;
}
// Colors
const white = sdl.Color{
    .r = 255,
    .g = 255,
    .b = 255,
    .a = 255,
};
const black = sdl.Color{
    .r = 0,
    .g = 0,
    .b = 0,
    .a = 0,
};
