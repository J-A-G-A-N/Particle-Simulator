


const sdl = @import("zsdl2");
const std = @import("std");
const zm = @import("zmath");
const zopengl = @import("zopengl");
const ztracy = @import("ztracy");
const zsdl2_ttf = @import("zsdl2_ttf");
const Font = @import("zsdl2_ttf").Font;
const builtin = @import("builtin");


const Renderer = @import("renderer.zig").Renderer;
const Texture2d = @import("textures.zig").texture2d;
const stdout = std.io.getStdOut().writer();
const Particles = @import("logic/particles.zig").Particles;
const Spawners = @import("logic/spawn_partilces.zig").particle_spawner;
const Flags = @import("logic/global.zig").Flags;
const spawn_partilces = @import("./logic/spawn_partilces.zig");
const Boundary = @import("logic/solver/boundary.zig").Boundary;
const  Gird_collision_handler = @import("logic/collision_handler.zig").Gird_collision_handler;
var reset:bool = false;
var bg_flip:bool = false;
var buffer:[13]u8 = [_]u8{0}**13;
//1366x768
var flags:Flags = .{
    .WINDOW_WIDTH = 720,
    .WINDOW_HEIGHT = 688,
    .TARGET_FPS = 60,
    .PARTICLE_RADIUS = 2,
    .PARTICLE_COUNT = 7300, //Max = 7300
    .DAMPING_FACTOR = 0.01, //Min 0.75,Max 1 for r=2
    .PARTICLE_COLLISION_DAMPING = 0.9999,//Min 0.85 Max 1 for r=2
    .GRID_SIZE = 8,
    .PAUSED = true,
    .IF_GRAVITY = false,
};




const colors = @import("colors.zig");
var quit:bool = false;
var elapsed_time_ms: f64 = undefined;
var window:*sdl.Window = undefined;
var R:Renderer = .{.r = undefined };
var texture_2D:Texture2d = .{.texture = undefined};
var text_texture:Texture2d = .{.texture = undefined};
var particles:Particles = undefined;
var spawner: spawn_partilces.particle_spawner = undefined;
var boundary:Boundary =undefined ;
var grid_collision:Gird_collision_handler = undefined;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator:std.mem.Allocator = undefined;
var t:Text = undefined;


pub const Text = struct {
    
    x:f32,
    y:f32,
    size:i32,
    text_texture:Texture2d,
    font:*Font,
    renderer:*Renderer,
    frect:sdl.FRect,
    
     pub fn init(self:*@This(),renderer:*Renderer)void{
        self.text_texture.texture = undefined;
        self.renderer = renderer;
        self.frect = .{
            .x = 0,
            .y = 0,
            .w = 0,
            .h = 0,
        };
        
    }
    pub fn create(renderer:*Renderer)@This(){
        return Text{
            .text_texture.texture ,
            .renderer,
            @This().init(renderer),
        }; 
    }
    

    pub fn destroy(self:*@This())void{
        self.text_texture.destroy_texture(); 
    }


    pub fn load_font(self:*@This(),font:[:0]const u8,f_size:i32)!void{
        self.font = try Font.open(font,f_size);
        self.size = f_size;
    }
    pub fn draw_text(t_texture:*Text,text:[:0]const u8,pos:struct {x:f32,y:f32},color:sdl.Color)!void{


        const surface = try Font.renderTextSolid(t_texture.font, text,color); 
        defer surface.*.free();
        t_texture.text_texture.texture.? = try sdl.createTextureFromSurface(t_texture.renderer.r,surface);
        defer t_texture.destroy();
        t_texture.frect.x = pos.x;
        t_texture.frect.y = pos.y;
        t_texture.frect.w = @as(f32, @floatFromInt(surface.*.w )) * 0.9 ;
        t_texture.frect.h = @as(f32, @floatFromInt(surface.*.h )) * 0.8;

        // t_texture.frect.h = @as(f32,@floatFromInt(t_texture.size));
        // t_texture.frect.w = @as(f32,@floatFromInt(text.len * 10));
        try t_texture.renderer.render_texture_2d(t_texture.text_texture, .{
            .x = t_texture.frect.x,
            .y = t_texture.frect.y,
            .h = t_texture.frect.h,
            .w = t_texture.frect.w,

        }, color);
    }

};



pub fn load_meida(r:*sdl.Renderer,file:[:0]const u8)!void{
   try texture_2D.load_texture2d(r,file); 
}


pub fn init()!void{
    try sdl.init(.{ .audio = false, .video = true });
    window = try sdl.createWindow(
        "zig-gamedev: sdl2_demo",
        sdl.Window.pos_undefined,
        sdl.Window.pos_undefined,
        flags.WINDOW_WIDTH,
        flags.WINDOW_HEIGHT,
        .{ .allow_highdpi = true ,.resizable = true },
    );
    
    try R.init(window, -1,.{.accelerated = false});
    //try load_meida(R.r,"resources/high_res_circle.png");
    try load_meida(R.r,"resources/circle.png");
    //try load_meida(R.r,"resources/hrc.png");
    try zsdl2_ttf.init();
    std.log.debug("sdl-version : {}", .{sdl.getVersion()}); 

     allocator = gpa.allocator();

    particles = try Particles.init(allocator,flags.PARTICLE_COUNT,&flags);
    spawner = Spawners.create_spawner(.Random, &flags);
    spawner.spawn(&particles);
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
    grid_collision = try Gird_collision_handler.init_grid(allocator,&flags,&particles);



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


pub fn make_time(text:[:0]const u8)[:0]const u8{
    return text;
}

pub fn updateAndRender() !void {

    const updateAndRender_ztracy_zone  = ztracy.ZoneNC(@src(),"updateAndRender",0x0f_00_00);
    defer updateAndRender_ztracy_zone.End();

    var event: sdl.Event = undefined;

    while (sdl.pollEvent(&event)) {
        try handle_key_events(&event);
    }
    
        // Set Background
    if(bg_flip == true){
        try R.clearBackground(colors.Raywhite);
    }else{
        try R.clearBackground(colors.Black);
    }


    if (reset == true){
        reset =!reset;
        particles.initialize_particles();
        spawner.spawn(&particles);
        Gird_collision_handler.clear_all_array(&grid_collision);
        flags.PAUSED = true;

    }
    if (flags.PAUSED != true){
            //boundary.check_boundary(&particles);
            //particles._update_positions();
            //particles.generic_collision_detection();
            try particles.update_positions(&grid_collision,&boundary);
    }
    
    try R.render_circles_texture_2d(texture_2D, .{.X = particles.positions.x,
        .Y = particles.positions.y,
        .color = particles.colors},
        flags.PARTICLE_RADIUS);
    
    try draw_fps();
    try draw_partticle_count();
    R.r.present();
}

fn draw_fps()!void{
   
    const tpf_raw = try std.fmt.bufPrint(&buffer, "{d} ms", .{elapsed_time_ms});
    buffer[tpf_raw.len] = 0;
    //const tpf = try std.mem.concatWithSentinel(allocator, u8, &[_][]const u8{ tpf_raw }, 0);

    const tpf: [:0]const u8 = @ptrCast(&buffer);
    //defer allocator.free(tpf);

    try t.draw_text(((tpf)), .{
        .x = 10,
        .y = 5,

    },   if (bg_flip == false )colors.Raywhite else colors.Black );

}

fn draw_partticle_count()!void{
    const tpf_raw = try std.fmt.bufPrint(&buffer, "{}", .{flags.PARTICLE_COUNT});
    buffer[tpf_raw.len] = 0;
    //const tpf = try std.mem.concatWithSentinel(allocator, u8, &[_][]const u8{ tpf_raw }, 0);

    const tpf: [:0]const u8 = @ptrCast(&buffer);
    //defer allocator.free(tpf);

    try t.draw_text(((tpf)), .{
        .x = 170,
        .y = 5,

    },  if (bg_flip == false )colors.Raywhite else colors.Black );

}


pub fn shouldQuit() bool {
    return quit;
}


pub fn main() !void {
    try init();
    defer deinit();
    const frame_time_ns: u64 = 1_000_000_000 / @as(u64,flags.TARGET_FPS); // Convert FPS to nanoseconds
    var last_time = std.time.nanoTimestamp();

    std.log.debug("SDL Error: {any}\n", .{sdl.getError()});

    while (!shouldQuit()) {
    const while_loop_ztracy_zone  = ztracy.ZoneNC(@src(),"while_loop",0xff_00_00);
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
            std.time.sleep(remaining_time_ns );
        }

        last_time = std.time.nanoTimestamp(); // Update last_time Before sleeping
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



