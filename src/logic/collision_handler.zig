const std = @import("std");

const Particles = @import("particles.zig").Particles;
const vec2 = @import("vectors.zig").vec2;
const Flags = @import("global.zig").Flags;
const ztracy =  @import("ztracy");
const debug = std.log.debug;
pub const Gird_collision_handler  = struct {
    num_x:u32,
    num_y:u32,
    grid_size:f32,
    flags:*Flags,
    grid_array:[]u32,
    start_array:[]u32,
    sorted_array:[]u32,
    collision_pairs:std.ArrayList([2]usize),
    allocator:std.mem.Allocator,
    particles:*Particles,
    
    pub fn init_grid(allocator:std.mem.Allocator,flags:*Flags,particles:*Particles)!Gird_collision_handler{
        const num_x = @divTrunc(flags.WINDOW_WIDTH , @as(i32,@intFromFloat(flags.*.GRID_SIZE)));
        const num_y = @divTrunc(flags.WINDOW_HEIGHT , @as(i32,@intFromFloat(flags.*.GRID_SIZE)));
        var gird_collision_handler = Gird_collision_handler{
            .num_x  = @as(u32,@intCast(num_x)),
            .num_y = @as(u32,@intCast(num_y)),
            .grid_size = flags.*.GRID_SIZE,
            .collision_pairs = std.ArrayList([2]usize).init(allocator),
            .flags = flags,
            .grid_array = try allocator.alloc(u32,@as(usize,@intCast(num_x * num_y + 1))),
            .start_array = try allocator.alloc(u32,@as(usize,@intCast(num_x * num_y + 1))),
            .sorted_array = try allocator.alloc(u32,@as(usize,@intCast(particles.*.len))),
            .particles = particles,
            .allocator = allocator,
        };
        clear_all_array(&gird_collision_handler);     
        return gird_collision_handler;
    }
     pub fn clear_all_array(collision_handler:*Gird_collision_handler)void{
        @memset(collision_handler.grid_array, 0);
        @memset(collision_handler.start_array, 0);
        @memset(collision_handler.sorted_array, 0);
    }
    pub fn deinit_grid(self:*@This())void{
        self.allocator.free(self.grid_array);
        self.allocator.free(self.start_array);
        self.allocator.free(self.sorted_array);
        defer self.collision_pairs.deinit();
    }
    
    // Computes the co-ordinates of the particle in the grid Eg : (1,4)
    pub fn comp_coordinates(self:*@This(),x:anytype,y:anytype)[2]u32{
        if (@TypeOf(x) != @TypeOf(y)){
            std.log.err("comp_coordinates: Type of x and type of y are not the same", .{});
        }

        var result_array:[2]u32 = undefined;
            result_array[0] = @intFromFloat(@divTrunc(x ,self.grid_size));
            result_array[1] = @intFromFloat(@divTrunc(y ,self.grid_size));

        return result_array;
    }

    // computes the index of the particle in the grid Eg: 1,2,3
    pub fn comp_index(self:*@This(),x:anytype,y:anytype)u32{
        if (@TypeOf(x) != @TypeOf(y)){
            std.log.err("comp_index : Type of x and type of y are not the same", .{});
        }

        const co_ordinates:[2]u32 = self.comp_coordinates(x, y);

        const return_val = co_ordinates[0] * self.num_y  + co_ordinates[1];
        return return_val;

    }


    // Increases the value by one at the index calculated 
    // index should be less than gird_array_len
     pub fn update_gird_array(self:*@This())void{
        for(0..self.particles.*.len)|i|{
            const x:f32 = self.particles.*.positions.x[i];
            const y:f32 = self.particles.*.positions.y[i];
            const index:usize = self.comp_index(x, y);
            if (index >= self.grid_array.len){
                @panic("Error : update_gird_array() : index value is greater than gird_array.len");
            }
            self.grid_array[index] += 1;
        }
       }

    
     // Calculates the partial sum and updates the start_array
     pub fn update_start_array(self: *@This())void{
        self.start_array[0] = 0;
        for(1..self.grid_array.len)|i|{
            self.start_array[i] = self.start_array[i - 1]  + self.grid_array[i - 1];   
        }
       }
        
    //  Sorts the particles index
     pub fn update_sorted_array(self: *@This()) !void {
    // Reset sorted_array
    @memset(self.sorted_array, 0);

    // Temporary array to track current position in each grid cell
    var cell_counters = try self.allocator.alloc(u32, self.grid_array.len);
    defer self.allocator.free(cell_counters);
    @memset(cell_counters, 0);

    // Sort particles into grid cells
    for (0..self.particles.*.len) |particle_index| {
        const x: f32 = self.particles.*.positions.x[particle_index];
        const y: f32 = self.particles.*.positions.y[particle_index];
        const grid_index = self.comp_index(x, y);
        
        const start_pos = self.start_array[grid_index];
        const offset = cell_counters[grid_index];
        
        self.sorted_array[start_pos + offset] = @intCast(particle_index);
        cell_counters[grid_index] += 1;
    }

   
}




    pub fn detect_collisions(self: *@This()) void {
    const detectCollisionsZone = ztracy.ZoneNC(@src(), "detect_collisions", 0xff_00_ff); 
    defer detectCollisionsZone.End();

    self.collision_pairs.clearRetainingCapacity();

    for (1..(self.num_x - 1)) |x| {  
        for (0..self.num_y) |y| {
            const grid_index = x * self.num_y + y;
            const start_index = self.start_array[grid_index];
            const end_index = if (grid_index + 1 < self.num_x * self.num_y) self.start_array[grid_index + 1] else self.particles.*.len;

            if (start_index >= end_index) continue;

            for (start_index..end_index) |i| {
                const particlei = self.sorted_array[i];

                // for (i + 1..end_index) |j| {
                //     const particlej = self.sorted_array[j];
                //     if (self.particles.*.check_collision(particlei, particlej)) {
                //         // Store collision pair
                //         collision_pairs.append([2]usize{ particlei, particlej }) catch unreachable;
                //     }
                // }

                self.check_neighboring_cells(particlei, grid_index, &self.collision_pairs);
            }
        }
    }

    // **Step 2: Resolve all collected collision pairs**
    for (self.collision_pairs.items) |pair| {
        self.particles.*.resolve_collision(pair[0], pair[1]);
    }
}
    
    pub fn check_neighboring_cells(self: *@This(), particle_i: usize, grid_index: usize, collision_pairs: *std.ArrayList([2]usize)) void {
    const Neighbor_offsets = [_][2] i32{
        .{-1,-1}, .{-1,0}, .{-1,1},
        .{0,-1},  .{0,0},       .{0,1},
        .{1,-1}, .{1,0},  .{1,1},
    };

    const grid_x = grid_index / self.num_y;
    const grid_y = grid_index % self.num_y;

    for (Neighbor_offsets) |offset| {
        const dx = offset[0];
        const dy = offset[1];

        const nx = @as(i32,@intCast(grid_x)) + dx;
        const ny = @as(i32,@intCast(grid_y)) + dy;

        if (nx < 0 or nx >= self.num_x or ny < 0 or ny >= self.num_y) continue;

        const neighboring_grid = @as(usize,@intCast(nx)) * self.num_y + @as(usize,@intCast(ny));
        const start_index = self.start_array[neighboring_grid];
        const end_index = if (neighboring_grid + 1 < self.num_x * self.num_y) self.start_array[neighboring_grid + 1] else self.particles.*.len;

        for (start_index..end_index) |j| {
            const particle_j = self.sorted_array[j];
            if (particle_i == particle_j) continue;
            if (self.particles.*.check_collision(particle_i, particle_j)) {
                // Store collision pair instead of resolving immediately
                collision_pairs.append([2]usize{ particle_i, particle_j }) catch unreachable;
            }
        }
    }
}


    //instead of resolving imedeately get all the pairs of collisons and then resolve

//     pub fn detect_collisions(self: *@This()) void {
//
//         const detectCollisionsZone = ztracy.ZoneNC(@src(), "detect_collisions", 0xff_00_ff); 
//         defer detectCollisionsZone.End();
//
//         // Skip leftmost and rightmost columns
//         for (1..(self.num_x - 1)) |x| {  
//             for (0..self.num_y) |y| {
//                 const grid_index = x * self.num_y + y;
//
//                 const start_index = self.start_array[grid_index];
//                 const end_index = if (grid_index + 1 < self.num_x * self.num_y) self.start_array[grid_index + 1] else self.particles.*.len;
//
//                 if (start_index >= end_index) continue;
//
//                 for (start_index..end_index) |i| {
//                     const particlei = self.sorted_array[i];
//
//                     for (i + 1..end_index) |j| {
//                         const particlej = self.sorted_array[j];
//                         if (self.particles.*.check_collision(particlei, particlej)) {
//                             self.particles.*.resolve_collision(particlei, particlej);
//                         }
//                     }
//                     self.check_neighboring_cells(particlei, grid_index);
//                 }
//             }
//         }
// }

    // pub fn detect_collisions(self:*@This()) void {
    //     const detect_collisions_ztracy_zone = ztracy.ZoneNC(@src(),"detect_collisions",0xff_00_ff); 
    //     defer  detect_collisions_ztracy_zone.End();
    //     //debug("detect_collisions",.{});
    //
    //     for (0..(self.num_x * self.num_y)) |grid_index| {
    //         //const start_index = if (grid_index == 0) 0 else self.start_array[grid_index - 1];
    //
    //         //const end_index = self.start_array[grid_index];
    //          const start_index = self.start_array[grid_index];
    //          const end_index = if (grid_index + 1 < self.num_x * self.num_y) self.start_array[grid_index + 1] else self.particles.*.len;
    //
    //         if (start_index >= end_index)continue ;
    //         for (start_index..end_index)|i|{
    //             const Particle_i = self.sorted_array[i];
    //
    //
    //             inline for (i+1..end_index)|j|{
    //                 const Particle_j = self.sorted_array[j];
    //                 // debug("particles_indices : ({d},{d})", .{Particle_i,Particle_j});
    //                 // debug("gird_index : {d}",.{grid_index});
    //                 if (self.particles.*.check_collision(Particle_i,Particle_j)){
    //                     self.particles.*.resolve_collision(Particle_i,Particle_j);
    //                 }
    //             }
    //             self.check_neighboring_cells(Particle_i,grid_index);
    //         }
    //     }
    // }

    // pub fn check_neighboring_cells(self:*@This(),particle_i:usize,grid_index:usize)void{
    //
    //     //debug("check_neighoring_cells",.{});
    //    const Neighbor_offsets = [_][2] i32{
    //         .{-1,-1}, .{-1,0}, .{-1,1},
    //         .{0,-1},          .{0,1},
    //         .{1,-1}, .{1,0},  .{1,1},
    //    };
    //         
    //    const grid_x = grid_index / self.num_y;
    //    const grid_y = grid_index % self.num_y;
    //
    //    for (Neighbor_offsets)|offset|{
    //        const dx = offset[0];
    //        const dy = offset[1];
    //
    //        const nx = @as(i32,@intCast(grid_x)) + dx;
    //        const ny = @as(i32,@intCast(grid_y)) + dy;
    //       
    //        if (nx < 0 or nx >= self.num_x or ny < 0 or ny >= self.num_y)continue;
    //
    //
    //        const neighouring_gird = @as(usize,@intCast(nx)) * self.num_y + @as(usize,@intCast(ny));
    //        const start_index = if (neighouring_gird == 0) 0 else self.start_array[neighouring_gird - 1];
    //        const end_index = self.start_array[neighouring_gird];
    //
    //        for (start_index..end_index)|j|{
    //            const particle_j = self.sorted_array[j];
    //
    //
    //            if (self.particles.*.check_collision(particle_i,particle_j)){
    //                 self.particles.*.resolve_collision(particle_i,particle_j);
    //            }
    //        }
    //    }
    //
    // }
    // pub fn  drawGrid(self:*@This(),) void {
    //     // Draw vertical lines
    //     const num_x:usize = @intCast(self.num_x);
    //     const num_y:usize = @intCast(self.num_y);
    //     const grid_size:f32 =   self.grid_size;
    //     for (0..num_x + 1) |i| {
    //         const x = @as(f32, @floatFromInt(i)) * grid_size;
    //         rl.drawLineV(rl.Vector2{ .x = x, .y = 0 }, rl.Vector2{ .x = x, .y =
    //             @as(f32,@floatFromInt(num_y)) * grid_size }, rl.Color.gray);
    //     }
    //
    //     // Draw horizontal lines
    //     for (0..num_x + 1) |j| {
    //         const y = @as(f32, @floatFromInt(j)) * grid_size;
    //         rl.drawLineV(rl.Vector2{ .x = 0, .y = y }, rl.Vector2{ .x =
    //             @as(f32,@floatFromInt( num_x )) * grid_size, .y = y }, rl.Color.gray);
    //     }
    // } 
    // 
};

