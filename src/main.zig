const std = @import("std");
const builtin = @import("builtin");

const sdl = @import("zsdl2");
const zsdl2_ttf = @import("zsdl2_ttf");
//const zopengl = @import("zopengl");
const Font = @import("zsdl2_ttf").Font;

const ztracy = @import("ztracy");
//const zm = @import("zmath");

const Renderer = @import("renderer.zig").Renderer;
const Texture2d = @import("textures.zig").texture2d;
const Text = @import("render_text.zig").Text;

const stdout = std.io.getStdOut().writer();
const Particles = @import("logic/particles.zig").Particles;
const Spawners = @import("logic/particles.zig").particle_spawner;

const Flags = @import("logic/global.zig").Flags;
const Boundary = @import("logic/solver/boundary.zig").Boundary;
const Grid_collision_handler = @import("logic/collision_handler.zig").Grid_collision_handler;

var reset: bool = false;
var bg_flip: bool = false;
var buffer: [13]u8 = [_]u8{0} ** 13;
//1366x768
var flags: Flags = .{
    .WINDOW_WIDTH = 720,
    .WINDOW_HEIGHT = 696,
    .TARGET_FPS = 60,
    .PARTICLE_RADIUS = 2,
    .MAX_PARTICLE_COUNT = 7000, //Max = 7300
    .DAMPING_FACTOR = 0.1, //Min 0.75,Max 1 for r=2
    .PARTICLE_COLLISION_DAMPING = 0.9999, //Min 0.85 Max 1 for r=2
    .GRID_SIZE = 8,
    .PAUSED = true,
    .IF_GRAVITY = false,
};

const colors = @import("colors.zig");
var quit: bool = false;
var elapsed_time_ms: f64 = undefined;

var window: *sdl.Window = undefined;
var R: Renderer = .{ .r = undefined };
var texture_2D: Texture2d = .{ .texture = undefined };
var text_texture: Texture2d = .{ .texture = undefined };

var particles: Particles = undefined;
var spawner: Spawners = undefined;
var boundary: Boundary = undefined;

var grid_collision: Grid_collision_handler = undefined;
var t: Text = undefined;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator: std.mem.Allocator = undefined;





pub fn load_meida(r:*sdl.Renderer,file:[:0]const u8)!void{
   try texture_2D.load_texture2d(r,file); 
}

pub fn init() !void {
    try sdl.init(.{ .audio = false, .video = true });
    window = try sdl.createWindow(
        "zig-gamedev: sdl2_demo",
        sdl.Window.pos_undefined,
        sdl.Window.pos_undefined,
        flags.WINDOW_WIDTH,
        flags.WINDOW_HEIGHT,
        .{ .allow_highdpi = true, .resizable = true },
    );

    try R.init(window, -1, .{ .accelerated = false });
    //try load_meida(R.r,"resources/high_res_circle.png");
    try load_meida(R.r, "resources/circle.png");
    //try load_meida(R.r,"resources/hrc.png");
    try zsdl2_ttf.init();
    std.log.debug("sdl-version : {}", .{sdl.getVersion()});

    allocator = gpa.allocator();

    spawner = Spawners.create_spawner(.Random, &flags);
    particles = try Particles.init(allocator, flags.MAX_PARTICLE_COUNT, &flags);
    try spawner.spawn(&particles);
    t.init(&R);
    try t.load_font("resources/fcnf.ttf", 21);

    // var count:u8 = 0;
    // if(count == 0){
    //     for(0..particles.len)|i|{
    //         std.debug.print("velocities pos : ({},{})\n", .{particles.velocities.x[i],particles.velocities.y[i]});
    //     }
    //     count += 1;
    // }
    boundary = Boundary.create_boundry(.window, &flags);
    grid_collision = try Grid_collision_handler.init_grid(allocator, &flags, &particles);
}

pub fn deinit() void {
    particles.deinit();
    grid_collision.deinit_grid();
    R.destroy();
    window.destroy();
    sdl.destroyTexture(texture_2D.texture.?);
    defer _ = gpa.deinit();
    sdl.quit();
}

pub fn make_time(text: [:0]const u8) [:0]const u8 {
    return text;
}

pub fn updateAndRender() !void {
    const updateAndRender_ztracy_zone = ztracy.ZoneNC(@src(), "updateAndRender", 0x0f_00_00);
    defer updateAndRender_ztracy_zone.End();

    var event: sdl.Event = undefined;

    while (sdl.pollEvent(&event)) {
        try handle_key_events(&event);
    }

    // Set Background
    if (bg_flip == true) {
        try R.clearBackground(colors.Raywhite);
    } else {
        try R.clearBackground(colors.Black);
    }

    // Dosen't work
    if (reset == true) {
        reset = !reset;
        try spawner.spawn(&particles);
        Grid_collision_handler.clear_all_array(&grid_collision);
        flags.PAUSED = true;
    }
    if (flags.PAUSED != true) {
        //boundary.check_boundary(&particles);
        //particles._update_positions(&boundary);
        //particles.generic_collision_detection();
        try particles.update_positions(&grid_collision, &boundary);
    }

    try R.render_circles_texture_2d(texture_2D, .{ .X = particles.positions.x, .Y = particles.positions.y, .color = particles.colors }, flags.PARTICLE_RADIUS);

    try draw_fps();
    //try grid_collision.draw_line(&R);
    try draw_partticle_count();
    R.r.present();
}

fn draw_fps() !void {
    const tpf_raw = try std.fmt.bufPrint(&buffer, "{d} ms", .{elapsed_time_ms});
    buffer[tpf_raw.len] = 0;
    //const tpf = try std.mem.concatWithSentinel(allocator, u8, &[_][]const u8{ tpf_raw }, 0);

    const tpf: [:0]const u8 = @ptrCast(&buffer);
    //defer allocator.free(tpf);

    try t.draw_text(((tpf)), .{
        .x = 10,
        .y = 5,
    }, if (bg_flip == false) colors.Raywhite else colors.Black);
}

fn draw_partticle_count() !void {
    const tpf_raw = try std.fmt.bufPrint(&buffer, "{}", .{flags.MAX_PARTICLE_COUNT});
    buffer[tpf_raw.len] = 0;
    //const tpf = try std.mem.concatWithSentinel(allocator, u8, &[_][]const u8{ tpf_raw }, 0);

    const tpf: [:0]const u8 = @ptrCast(&buffer);
    //defer allocator.free(tpf);

    try t.draw_text(((tpf)), .{
        .x = 170,
        .y = 5,
    }, if (bg_flip == false) colors.Raywhite else colors.Black);
}

pub fn shouldQuit() bool {
    return quit;
}

pub fn main() !void {
    try init();
    defer deinit();
    const frame_time_ns: u64 = 1_000_000_000 / @as(u64, flags.TARGET_FPS); // Convert FPS to nanoseconds
    var last_time = std.time.nanoTimestamp();

    std.log.debug("SDL Error: {any}\n", .{sdl.getError()});

    while (!shouldQuit()) {
        const while_loop_ztracy_zone = ztracy.ZoneNC(@src(), "while_loop", 0xff_00_00);
        defer while_loop_ztracy_zone.End();

        try updateAndRender(); // Update and render the frame

        const current_time = std.time.nanoTimestamp();

        const elapsed_time_ns: u64 = @intCast(current_time - last_time);
        elapsed_time_ms = @as(f64, @floatFromInt(elapsed_time_ns)) / 1_000_000.0; // Convert ns to ms

        //try stdout.print("Frame time: {d:.3} ms\n", .{elapsed_time_ms}); // Print frame time

        if (elapsed_time_ns < frame_time_ns) {
            const remaining_time_ns = frame_time_ns - elapsed_time_ns;
            //const remaining_time_ms: f64 = @as(f64, @floatFromInt(remaining_time_ns)) / 1_000_000.0; // Convert ns to ms
            //try stdout.print("sleep Time :{}\n ",.{remaining_time_ms});
            //std.time.sleep(remaining_time_ns - 500_000);
            std.time.sleep(remaining_time_ns);
        }

        last_time = std.time.nanoTimestamp(); // Update last_time Before sleeping
    }
}

pub fn handle_key_events(event: *sdl.Event) !void {
    switch (event.type) {
        .quit => quit = true,
        .keydown => |_| {
            if (event.key.keysym.sym == .escape) quit = true;
            if (event.key.keysym.sym == .g) flags.IF_GRAVITY = !flags.IF_GRAVITY;
            if (event.key.keysym.sym == .space) {
                flags.PAUSED = !flags.PAUSED;
            }
            if (event.key.keysym.sym == .r) reset = !reset;
            if (event.key.keysym.sym == .b) bg_flip = !bg_flip;
        },
        else => {},
    }
}
