const sdl = @import("zsdl2");
const std = @import("std");
const zm = @import("zmath");
const zopengl = @import("zopengl");
const ztracy = @import("ztracy");

const Renderer = @import("renderer.zig").Renderer;
const Texture2d = @import("textures.zig").texture2d;


const Particles = @import("logic/particles.zig").Particles;
const Spawners = @import("logic/spawn_partilces.zig").particle_spawner;
const Flags = @import("logic/global.zig").Flags;
const spawn_partilces = @import("./logic/spawn_partilces.zig");
const Boundary = @import("logic/solver/boundary.zig").Boundary;
const  Gird_collision_handler = @import("logic/collision_handler.zig").Gird_collision_handler;
var reset:bool = false;
var bg_flip:bool = false;
//1366x768
var flags:Flags = .{
    .WINDOW_HEIGHT = 720,
    .WINDOW_WIDTH = 1200,
    .TARGET_FPS = 60,
    .PARTICLE_RADIUS = 4,
    .PARTICLE_COUNT = 8000,
    .DAMPING_FACTOR = 0.1,
    .PARTICLE_COLLISION_DAMPING = 1,
    .GRID_SIZE = 16,
    .PAUSED = true,
    .IF_GRAVITY = false,
};



const colors = @import("colors.zig");
var quit:bool = false;
var window:*sdl.Window = undefined;
var R:Renderer = .{.r = undefined };
var texture_2D:Texture2d = .{.texture = undefined};
var particles:Particles = undefined;
var spawner: spawn_partilces.particle_spawner = undefined;
var boundary:Boundary =undefined ;
var grid_collision:Gird_collision_handler = undefined;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub fn load_meida(r:*sdl.Renderer,file:[:0]const u8)!void{
   try texture_2D.load_texture2d(r,file); 
}


pub fn init()!void{
    try sdl.init(.{ .audio = true, .video = true });
    window = try sdl.createWindow(
        "zig-gamedev: sdl2_demo",
        sdl.Window.pos_undefined,
        sdl.Window.pos_undefined,
        flags.WINDOW_WIDTH,
        flags.WINDOW_HEIGHT,
        .{ .allow_highdpi = true ,.resizable = true },
    );
    
    std.log.debug("sdl-version : {}", .{sdl.getVersion()}); 
    try R.init(window, -1,.{});
    try load_meida(R.r,"resources/high_res_circle.png");
    //try load_meida(R.r,"resources/circle.png");
    //try load_meida(R.r,"resources/hrc.png");

    const allocator = gpa.allocator();

    particles = try Particles.init(allocator,flags.PARTICLE_COUNT,&flags);
    spawner = Spawners.create_spawner(.Random, &flags);
    spawner.spawn(&particles);
    // var count:u8 = 0;
    // if(count == 0){
    //     for(0..particles.len)|i|{
    //         std.debug.print("velocities pos : ({},{})\n", .{particles.velocities.x[i],particles.velocities.y[i]});
    //     }
    //     count += 1;
    // }
    boundary = Boundary.create_boundry(.window, &flags);
    grid_collision = try Gird_collision_handler.init_grid(allocator,&flags,&particles);
    //circles.init();



}

fn part_deinit()void{
    grid_collision.deinit_grid();

}
pub fn deinit() void {
    particles.deinit();
    R.destrory();
    window.destroy();
    sdl.destroyTexture(texture_2D.texture.?);
    defer _ = gpa.deinit();
    sdl.quit();
}




pub fn updateAndRender() !void {

    const updateAndRender_ztracy_zone  = ztracy.ZoneNC(@src(),"updateAndRender",0x0f_00_00);
    defer updateAndRender_ztracy_zone.End();

    var event: sdl.Event = undefined;
    while (sdl.pollEvent(&event)) {
        // if (event.type == .quit) {
        //     quit = true;
        // } else if (event.type == .keydown) {
        //     if (event.key.keysym.sym == .escape) {
        //         quit = true;
        //     }
        // }
        try handle_key_events(&event);
    }
    
        // Set Background
    if(bg_flip == true){
        try R.clearBackground(colors.Black);
    }else{
        try R.clearBackground(colors.Raywhite);
    }

    try R.render_circles_texture_2d(texture_2D, .{.X = particles.positions.x, .Y = particles.positions.y, .color = particles.colors},flags.PARTICLE_RADIUS);

    if (reset == true){
        reset =!reset;
        particles.initialize_particles();
        spawner.spawn(&particles);
        Gird_collision_handler.clear_all_array(&grid_collision);
        flags.PAUSED = !flags.PAUSED;

    }
    if (flags.PAUSED != true){
            try particles.update_positions(&grid_collision,&boundary);
    }
    
      R.r.present();
}


pub fn shouldQuit() bool {
    return quit;
}


pub fn main() !void {
    try init();
    defer deinit();

    const target_fps = 60;
    const frame_time_ns: u64 = 1_000_000_000 / target_fps; // Convert FPS to nanoseconds
    var last_time = std.time.nanoTimestamp();

    //var stdout = std.io.getStdOut().writer(); // Get stdout for printing
        const error_message = sdl.getError();
        std.debug.print("SDL Error: {any}\n", .{error_message});

    while (!shouldQuit()) {
    const while_loop_ztracy_zone  = ztracy.ZoneNC(@src(),"while_loop",0xff_00_00);
    defer while_loop_ztracy_zone.End();
 
        try updateAndRender(); // Update and render the frame

        const current_time = std.time.nanoTimestamp();

        const elapsed_time_ns: u64 = @intCast(current_time - last_time);
        //const elapsed_time_ms: f64 = @as(f64, @floatFromInt(elapsed_time_ns)) / 1_000_000.0; // Convert ns to ms

        //try stdout.print("Frame time: {d:.3} ms\n", .{elapsed_time_ms}); // Print frame time

        if (elapsed_time_ns < frame_time_ns) {
            const remaining_time_ns = frame_time_ns - elapsed_time_ns;
            //const remaining_time_ms: f64 = @as(f64, @floatFromInt(remaining_time_ns)) / 1_000_000.0; // Convert ns to ms
            //try stdout.print("sleep Time :{} ",.{remaining_time_ms});
            //std.time.sleep(remaining_time_ns - 500_000);
            std.time.sleep(remaining_time_ns );
        }

        last_time = std.time.nanoTimestamp(); // Update last_time AFTER sleeping
    }
}

pub fn handle_key_events(event:*sdl.Event)!void{
    switch (event.type){
        .quit => quit = true,
        .keydown => |_|{
            if (event.key.keysym.sym == .escape)quit =  true;
            if (event.key.keysym.sym == .g ) flags.IF_GRAVITY =!flags.IF_GRAVITY;
            if (event.key.keysym.sym == .space) {
                flags.PAUSED = !flags.PAUSED;

            }
            if (event.key.keysym.sym == .r) reset =!reset;
            if (event.key.keysym.sym == .b) bg_flip =!bg_flip;
        },
        else => {},
    }
}



