const std = @import("std");
const print = std.debug.print;
const rl = @import("raylib");

const Particles = @import("particles.zig").Particles;
const Spawners = @import("spawn_partilces.zig").particle_spawner;
const Flags = @import("global.zig").Flags;
const Boundary = @import("solver/boundary.zig").Boundary;
const  Gird_collision_handler = @import("collision_handler.zig").Gird_collision_handler;
const ztracy = @import("ztracy");

var flags:Flags = .{
    .WINDOW_HEIGHT =688,
    .WINDOW_WIDTH = 1120,
    .TARGET_FPS = 60,
    .PARTICLE_COUNT = 4000,
    .PARTICLE_RADIUS = 4,
    .DAMPING_FACTOR = 3,
    .PARTICLE_COLLISION_DAMPING = 1,
    .GRID_SIZE = 16,
    .PAUSED = true,
    .IF_GRAVITY = false,
};


var camera2D:rl.Camera2D = undefined;

fn event_loop() !void{

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    camera2D = rl.Camera2D{
        //hi
    .target = rl.Vector2.init(@as(f32,@floatFromInt(@divTrunc(flags.WINDOW_WIDTH ,2)))
        ,@as(f32,@floatFromInt( @divTrunc(flags.WINDOW_HEIGHT,2)))),
    .offset = rl.Vector2.init(@as(f32,@floatFromInt(@divTrunc(flags.WINDOW_WIDTH,2)))
        , @as(f32,@floatFromInt(@divTrunc(flags.WINDOW_HEIGHT,2)))),
    .rotation = 0,
    .zoom = 1,
    };
 
    rl.initWindow(flags.WINDOW_WIDTH,flags.WINDOW_HEIGHT, "Test");
    defer rl.closeWindow();

    rl.setTargetFPS(flags.TARGET_FPS);

    camera2D.target = rl.Vector2.init(
        @as(f32,@floatFromInt(@divTrunc(flags.WINDOW_WIDTH, 2))),
        @as(f32,@floatFromInt(@divTrunc(flags.WINDOW_HEIGHT, 2)))
        );


    var particles:Particles = try Particles.init(allocator,flags.PARTICLE_COUNT,&flags);
    defer particles.deinit();
    var spawner = Spawners.create_spawner(.Random, &flags);
    spawner.spawn(&particles);
    var boundary = Boundary.create_boundry(.window, &flags);
    var gch = try Gird_collision_handler.init_grid(allocator,&flags,&particles);
    defer gch.deinit_grid();

    while (!rl.windowShouldClose()){
        const while_loop_tracy_zone = ztracy.ZoneNC(@src(), "while_loop", 0xff_ff_00_00);
        defer while_loop_tracy_zone.End();
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.ray_white);
        rl.drawFPS(flags.WINDOW_WIDTH - 80, 10);

        // Particle stuff
        if (rl.isKeyPressed(.space)){
            flags.PAUSED = !flags.PAUSED;
        }
        
        updateCameraZoom();
        handleCameraDrag(&camera2D,0.4);

        if (flags.PAUSED == false){
            try particles.update_positions(&gch,&boundary); 
            boundary.check_boundary(&particles);
            // gch.clear_grid_start();
            // gch.update_gird_array();
            // gch.update_start_array();
            // try gch.update_sorted_array();
            // gch.detect_collisions();
            //particles.generic_collision_detection();
        }
        
        if (rl.isKeyPressed(.g)){
            flags.IF_GRAVITY = !flags.IF_GRAVITY;

        }

        //gch.drawGrid();
        rl.beginMode2D(camera2D);
        defer rl.endMode2D();
        const draw_particles_ztracy_zone = ztracy.ZoneNC(@src(),"draw_particles",0x0f_0f_0f);
        draw_particles_ztracy_zone.End();
        for (0..particles.len) |i| {
            rl.drawCircleV(rl.Vector2{
                .x = particles.positions.x[i],
                .y = particles.positions.y[i],
            }, particles.radius[i], particles.colors[i]);
        }
        
        
    }
}

fn updateCameraZoom() void {
    const scroll = rl.getMouseWheelMove(); // Get scroll movement
    const zoom_ratio = 0.2;
    if (scroll != 0) {
        const mouse_world_before = rl.getScreenToWorld2D(rl.getMousePosition(), camera2D);
        camera2D.zoom += scroll * zoom_ratio; // Adjust zoom speed as needed
        if (camera2D.zoom < zoom_ratio) camera2D.zoom = zoom_ratio; // Prevent negative zoom
        const mouse_world_after = rl.getScreenToWorld2D(rl.getMousePosition(), camera2D);

        // Adjust camera target to maintain focus at the mouse position
        camera2D.target.x -= (mouse_world_after.x - mouse_world_before.x);
        camera2D.target.y -= (mouse_world_after.y - mouse_world_before.y);

    }
    if (rl.isKeyPressed(.m )){
        camera2D.target.x = @divExact(@as(f32,@floatFromInt(flags.WINDOW_WIDTH)), 2);
        camera2D.target.y = @divExact(@as(f32,@floatFromInt(flags.WINDOW_HEIGHT)), 2);
        camera2D.zoom = 1;

    }
}


var prevMousePosition = rl.Vector2{ .x = 0, .y = 0 };

pub fn handleCameraDrag(camera: *rl.Camera2D, speed: f32) void {
    const mousePosition = rl.getMousePosition();
    
    if (rl.isMouseButtonDown(rl.MouseButton.left)) {
        const mouseDelta = rl.Vector2{
            .x = mousePosition.x - prevMousePosition.x,
            .y = mousePosition.y - prevMousePosition.y,
        };

        camera.target.x -= mouseDelta.x * speed;
        camera.target.y -= mouseDelta.y * speed;
    }

    // Update previous mouse position
    prevMousePosition = mousePosition;
}


pub fn main() !void {
   const is_ztracy_enabled:bool = ztracy.enabled;
   check_for_flags_padding();
   if (is_ztracy_enabled==true){
       print("ztacy enabled\n",.{});
   }else{
    print("ztacy disabled\n",.{});
   }
   try event_loop();
}
pub fn usizeToCString(value: usize) [*:0]const u8 {
    var buffer: [20]u8 = undefined; // Enough space for the number + null terminator
    const formatted = std.fmt.bufPrint(&buffer, "{}", .{value}) catch unreachable;
    buffer[formatted.len] = 0; // Null-terminate

    return @ptrCast( &buffer);
}

fn check_for_flags_padding()void{
    const structSize = @sizeOf(Flags);
    const structBitSize = @bitSizeOf(Flags) / 8; // Convert bits to bytes

    if (structSize > structBitSize) {
        std.debug.print("Padding exists! Struct size: {} bytes, actual data size: {} bytes\n", .{ structSize, structBitSize });
    } else {
        std.debug.print("No padding detected. Struct size: {} bytes\n", .{structSize});
    }
}


