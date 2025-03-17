const std = @import("std");
const Particles = @import("particles.zig").Particles;
const vec2 = @import("vectors.zig").vec2;
const Flags = @import("global.zig").Flags;
const Renderer = @import("../renderer.zig").Renderer;
const ztracy = @import("ztracy");
const debug = std.log.debug;
const sdl = @import("zsdl2");
const Solver = @import("solver/solver.zig").Solver;
pub const Grid_collision_handler = struct {
    num_x: u32,
    num_y: u32,
    grid_size: f32,
    flags: *Flags,
    grid_array: []u8,
    start_array: []u32,
    sorted_array: []u32,
    collision_pairs: std.ArrayList([2]usize),
    allocator: std.mem.Allocator,
    particles: *Particles,

    pub fn init_grid(allocator: std.mem.Allocator, flags: *Flags, particles: *Particles) !Grid_collision_handler {
        const num_x = @divTrunc(flags.WINDOW_WIDTH, @as(i32, @intFromFloat(flags.*.GRID_SIZE)));
        const num_y = @divTrunc(flags.WINDOW_HEIGHT, @as(i32, @intFromFloat(flags.*.GRID_SIZE)));
        var grid_collision_handler = Grid_collision_handler{
            .num_x = @as(u32, @intCast(num_x)),
            .num_y = @as(u32, @intCast(num_y)),
            .grid_size = flags.*.GRID_SIZE,
            .collision_pairs = std.ArrayList([2]usize).init(allocator),
            .flags = flags,
            .grid_array = try allocator.alloc(u8, @as(usize, @intCast(num_x * num_y))),
            .start_array = try allocator.alloc(u32, @as(usize, @intCast(num_x * num_y))),
            .sorted_array = try allocator.alloc(u32, @as(usize, @intCast(particles.*.capacity))),
            .particles = particles,
            .allocator = allocator,
        };
        clear_all_array(&grid_collision_handler);
        return grid_collision_handler;
    }
    pub fn clear_all_array(collision_handler: *Grid_collision_handler) void {
        @memset(collision_handler.grid_array, 0);
        @memset(collision_handler.start_array, 0);
        @memset(collision_handler.sorted_array, 0);
    }
    pub fn deinit_grid(self: *@This()) void {
        self.allocator.free(self.grid_array);
        self.allocator.free(self.start_array);
        self.allocator.free(self.sorted_array);
        defer self.collision_pairs.deinit();
    }

    // Computes the co-ordinates of the particle in the grid Eg : (1,4)
    pub fn comp_coordinates(self: *@This(), x: anytype, y: anytype) [2]u32 {
        if (@TypeOf(x) != @TypeOf(y)) {
            std.log.err("comp_coordinates: Type of x and type of y are not the same", .{});
        }

        var result_array: [2]u32 = undefined;
        result_array[0] = @intFromFloat(@divTrunc(x, self.grid_size));
        result_array[1] = @intFromFloat(@divTrunc(y, self.grid_size));

        return result_array;
    }

    // computes the index of the particle in the grid Eg: 1,2,3
    pub fn comp_index(self: *@This(), x: anytype, y: anytype) u32 {
        if (@TypeOf(x) != @TypeOf(y)) {
            std.log.err("comp_index : Type of x and type of y are not the same", .{});
        }

        const co_ordinates: [2]u32 = self.comp_coordinates(x, y);

        const return_val = co_ordinates[0] * self.num_y + co_ordinates[1];
        return return_val;
    }

    // Increases the value by one at the index calculated
    // index should be less than gird_array_len
    pub fn update_gird_array(self: *@This()) void {
        for (0..self.particles.*.len) |i| {
            const x: f32 = self.particles.*.positions.x[i];
            const y: f32 = self.particles.*.positions.y[i];
            const index: usize = self.comp_index(x, y);
            if (index >= self.grid_array.len) {
                @panic("Error : update_gird_array() : index value is greater than gird_array.len");
            }
            self.grid_array[index] += 1;
        }
        //std.debug.print("grid_array :{any}\n", .{self.grid_array});

    }

    // Calculates the partial sum and updates the start_array
    pub fn update_start_array(self: *@This()) void {
        self.start_array[0] = 0;
        for (1..self.grid_array.len) |i| {
            self.start_array[i] = self.start_array[i - 1] + @as(u32, self.grid_array[i - 1]);
        }
        //std.debug.print("start_array : :{any}\n", .{self.start_array});
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
            // std.debug.print("start_pos: {}, offset: {}, sorted_array.len: {}\n", .{
            //     start_pos, offset, self.sorted_array.len
            // });

        }
    }

    pub fn detect_collisions(self: *@This()) void {
        const detectCollisionsZone = ztracy.ZoneNC(@src(), "detect_collisions", 0xff_00_ff);
        defer detectCollisionsZone.End();

        self.collision_pairs.clearRetainingCapacity();
        var particle_i: usize = 0;
        for (1..(self.num_x - 1)) |x| {
            for (0..self.num_y) |y| {
                const grid_index = x * self.num_y + y;
                const start_index = self.start_array[grid_index];
                const end_index = if (grid_index + 1 < self.num_x * self.num_y) self.start_array[grid_index + 1] else self.particles.*.len;
                //std.debug.print("({},{})\n", .{start_index,end_index});
                //if (start_index == end_index) continue;
                if (start_index >= end_index) continue;

                for (start_index..end_index) |i| {
                    particle_i = self.sorted_array[i];

                    const Neighbor_offsets = [_][2]i32{ .{ 0, 0 }, .{ 1, 0 }, .{ 1, 1 }, .{ 0, 1 }, .{ -1, 1 } };

                    const grid_x = grid_index / self.num_y;
                    const grid_y = grid_index % self.num_y;

                    for (Neighbor_offsets) |offset| {
                        const dx = offset[0];
                        const dy = offset[1];

                        const nx = @as(i32, @intCast(grid_x)) + dx;
                        const ny = @as(i32, @intCast(grid_y)) + dy;

                        if (nx < 0 or nx >= self.num_x or ny < 0 or ny >= self.num_y) continue;

                        const neighboring_grid = @as(usize, @intCast(nx)) * self.num_y + @as(usize, @intCast(ny));
                        const start_idx = self.start_array[neighboring_grid];
                        const end_idx = if (neighboring_grid + 1 < self.num_x * self.num_y) self.start_array[neighboring_grid + 1] else self.particles.*.len;

                        for (start_idx..end_idx) |j| {
                            const particle_j = self.sorted_array[j];

                            if (particle_i == particle_j) continue;
                            //std.debug.print("({},{})\n", .{particle_i,particle_j});

                            if (Solver.check_collision(self.particles,particle_i, particle_j)) {
                                // Store collision pair instead of resolving immediately
                                self.collision_pairs.append([2]usize{ particle_i, particle_j }) catch unreachable;
                            }
                        }
                    }
                }
            }
        }

        // **Step 2: Resolve all collected collision pairs**
        for (self.collision_pairs.items) |pair| {
            Solver.resolve_collision(self.particles,pair[0], pair[1]);
        }
    }

    pub fn draw_line(
        self: *@This(),
        R: *Renderer,
    ) !void {
        // vertical lines
        var x_cord_top: f32 = 0;
        var x_cord_bottom: f32 = 0;
        var y_cord_left: f32 = 0;
        var y_cord_right: f32 = 0;

        for (0..self.num_x) |_| {
            try R.r.drawLineF(x_cord_top, 0, x_cord_bottom, @as(f32, @floatFromInt(self.flags.*.WINDOW_HEIGHT)));
            x_cord_top += self.flags.*.GRID_SIZE;
            x_cord_bottom += self.flags.*.GRID_SIZE;
        }

        for (0..self.num_y) |_| {
            try R.r.drawLineF(0, y_cord_left, @as(f32, @floatFromInt(self.flags.*.WINDOW_WIDTH)), y_cord_right);
            y_cord_left += self.flags.*.GRID_SIZE;
            y_cord_right += self.flags.*.GRID_SIZE;
        }
    }
};
