const std = @import("std");
const stdout = std.io.getStdOut().writer();
const sdl = @import("zsdl2");
const log_print: bool = false;
const Vec2f64 = @Vector(2, f64);

const Color = @import("colors.zig");
fn float_random(rng: *std.Random.DefaultPrng, min: f64, max: f64) f64 {
    @setFloatMode(.strict);
    var random = rng.random();
    return std.math.lerp(min, max, random.float(f64));
}
pub const Particles = struct {
    positions: []Vec2f64,
    velocities: []Vec2f64,
    accelerations: []Vec2f64,
    colors: []sdl.Color,
    radius: f64,
    allocator: std.mem.Allocator,
    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, particles_count: usize, radius: f64) !Self {
        var positions = try allocator.alloc(Vec2f64, particles_count);
        var velocities = try allocator.alloc(Vec2f64, particles_count);
        var accelerations = try allocator.alloc(Vec2f64, particles_count);
        var colors = try allocator.alloc(sdl.Color, particles_count);
        @memset(positions[0..positions.len], @splat(0.0));
        @memset(velocities[0..velocities.len], @splat(0.0));
        @memset(accelerations[0..accelerations.len], @splat(0.0));
        @memset(colors[0..colors.len], undefined);
        return Self{
            .positions = positions,
            .velocities = velocities,
            .accelerations = accelerations,
            .colors = colors,
            .radius = radius,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.positions);
        self.allocator.free(self.velocities);
    }
};

pub const SpatialHashGrid = struct {
    rows: usize,
    cols: usize,
    grid_size: f64,
    grid_array: []u8,
    start_array: []usize,
    cell_counters: []usize,
    sorted_array: []usize,
    collision_pairs: std.ArrayList([2]usize),
    allocator: std.mem.Allocator,
    const Self = @This();
    const neighbor_offsets = [_][2]i32{ .{ 0, 0 }, .{ 0, 1 }, .{ 1, 0 }, .{ 1, 1 }, .{ -1, 1 } };

    pub fn init(allocator: std.mem.Allocator, width: f64, height: f64, grid_size: f64, particles_count: usize) !Self {
        const width_i32: i32 = @intFromFloat(width);
        const height_i32: i32 = @intFromFloat(height);
        const grid_size_i32: i32 = @intFromFloat(grid_size);

        // Standard coordinate system: width -> cols, height -> rows
        const cols: usize = @intCast(@divFloor(width_i32, grid_size_i32)); // +1 for boundary
        const rows: usize = @intCast(@divFloor(height_i32, grid_size_i32)); // +1 for boundary
        if (log_print) {
            std.log.debug("rows:{}, cols:{}\n", .{ rows, cols });
            std.log.debug("grid size:{}\n", .{grid_size_i32});
        }
        var grid = Self{
            .rows = rows,
            .cols = cols,
            .grid_size = grid_size,
            .grid_array = try allocator.alloc(u8, rows * cols),
            .cell_counters = try allocator.alloc(usize, rows * cols),
            .start_array = try allocator.alloc(usize, rows * cols),
            .sorted_array = try allocator.alloc(usize, particles_count),
            .collision_pairs = .init(allocator),
            .allocator = allocator,
        };
        grid.clear();
        return grid;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.grid_array);
        self.allocator.free(self.cell_counters);
        self.allocator.free(self.start_array);
        self.allocator.free(self.sorted_array);
        self.collision_pairs.deinit();
    }

    fn clear(self: *Self) void {
        @memset(self.grid_array, 0);
        @memset(self.cell_counters, 0);
        @memset(self.start_array, 0);
        @memset(self.sorted_array, 0);
    }

    // Computes the grid coordinate of the point
    pub fn computeCoordinate(self: *Self, x: f64, y: f64) [2]usize {
        const i: usize = @intFromFloat(@divFloor(x, self.grid_size));
        const j: usize = @intFromFloat(@divFloor(y, self.grid_size));

        // Add bounds checking to prevent out-of-bounds access
        const bounded_i = @min(i, self.cols - 1);
        const bounded_j = @min(j, self.rows - 1);

        if (log_print) {
            std.log.debug("i:{} , j:{}\n", .{ bounded_i, bounded_j });
        }
        return .{ bounded_i, bounded_j };
    }

    // Computes the Grid Index in Column-major order
    // Column-major: column * rows + row
    pub inline fn computeGridIndex(self: *Self, gx: usize, gy: usize) usize {
        return (gx * self.rows + gy);
    }

    // Compute the number of particles in each cell across the entire grid
    pub fn computeGridArray(self: *Self, positions: *[]Vec2f64) void {
        for (positions.*) |*pos| {
            const grid_coordinate = self.computeCoordinate(pos[0], pos[1]);
            const grid_index = self.computeGridIndex(grid_coordinate[0], grid_coordinate[1]);
            if (grid_index >= self.grid_array.len) {
                std.log.debug("grid index :{} , grid array length:{}\n", .{ grid_index, self.grid_array.len });
                @panic("Error: computeGridArray() : index value is greater that grid_array.len");
            }
            self.grid_array[grid_index] += 1;
        }
    }

    // Computes the partial sum of each cell
    pub fn computeStartArray(self: *Self) void {
        self.start_array[0] = 0;
        for (1..self.grid_array.len) |i| {
            self.start_array[i] = self.start_array[i - 1] + self.grid_array[i - 1];
        }
    }

    // This sorts the particles positions for collision detection
    pub fn computeSortedArray(self: *Self, positions: *[]Vec2f64) void {
        for (positions.*, 0..) |pos, i| {
            const x = pos[0];
            const y = pos[1];

            const grid_coordinate = self.computeCoordinate(x, y);
            const grid_idx = self.computeGridIndex(grid_coordinate[0], grid_coordinate[1]);

            const start_position = self.start_array[grid_idx];
            const offset = self.cell_counters[grid_idx];

            self.sorted_array[start_position + offset] = i;
            self.cell_counters[grid_idx] += 1;
        }
    }

    pub fn detect_collisions(self: *Self, particles: *Particles, dt: f64, t_acc: bool, particle_damping: f64) void {
        // Column-major iteration: iterate through columns first, then rows
        self.collision_pairs.clearRetainingCapacity();
        for (0..self.cols) |x| {
            for (0..self.rows) |y| {
                const grid_idx = self.computeGridIndex(x, y);
                const start_idx = self.start_array[grid_idx];
                const end_idx = if (grid_idx + 1 < self.cols * self.rows) self.start_array[grid_idx + 1] else particles.positions.len;

                // if no nearby particles
                if (start_idx >= end_idx) continue;

                const gx: i32 = @intCast(x);
                const gy: i32 = @intCast(y);

                for (start_idx..end_idx) |j| {
                    // index of particle
                    const particle_j = self.sorted_array[j];

                    for (neighbor_offsets) |offset| {
                        const dx = offset[0];
                        const dy = offset[1];

                        const nx = gx + dx;
                        const ny = gy + dy;

                        // Bounds checking with correct limits
                        if (nx < 0 or nx >= @as(i32, @intCast(self.cols)) or
                            ny < 0 or ny >= @as(i32, @intCast(self.rows))) continue;

                        const neighboring_grid = self.computeGridIndex(@intCast(nx), @intCast(ny));
                        const start_index = self.start_array[neighboring_grid];
                        const end_index = if (neighboring_grid + 1 < self.cols * self.rows)
                            self.start_array[neighboring_grid + 1]
                        else
                            particles.positions.len;

                        for (start_index..end_index) |i| {
                            const particle_i = self.sorted_array[i];

                            if (particle_i == particle_j) continue;
                            if (Solver.checkCollision(particles.positions[particle_i], particles.positions[particle_j], particles.radius)) {
                                self.collision_pairs.append([2]usize{ particle_i, particle_j }) catch unreachable;
                            }
                        }
                    }
                }
            }
        }

        for (self.collision_pairs.items) |pair| {
            Solver.resolve_collision(particles, pair[0], pair[1], dt, t_acc, particle_damping);
        }
    }
};

pub const Solver = struct {
    delta_time: f64,
    sub_steps: usize,
    t_acc: bool = false,
    boundary_damping: f64,
    particle_damping: f64,
    g: f64,
    dt: f64,
    const Self = @This();
    pub fn init(target_fps: f64, sub_steps: usize, g: f64, boundary_damping: f64, particle_damping: f64) Self {
        const delta_time = 1 / target_fps;
        const dt = delta_time / @as(f64, @floatFromInt(sub_steps));

        return Self{
            .delta_time = delta_time,
            .sub_steps = sub_steps,
            .dt = dt,
            .g = g,
            .boundary_damping = boundary_damping,
            .particle_damping = particle_damping,
        };
    }
    pub fn toggle_acc(self: *Self) void {
        self.t_acc = !self.t_acc;
    }
    inline fn zeroNearZero(x: f64) f64 {
        return if (@abs(x) < 1e-6) 0 else x;
    }
    pub fn updatePhysics(self: *Self, particles: *Particles, width: f64, height: f64, shg: *SpatialHashGrid) !void {
        const delta_time_vec2f64: Vec2f64 = @splat(self.dt);
        for (0..self.sub_steps) |_| {
            for (particles.positions, particles.velocities, particles.accelerations) |*pos, *vel, *acc| {
                if (self.t_acc) {
                    acc.*[1] = self.g;
                } else {
                    acc.* = @splat(0.0);
                }
                acc.* = .{
                    zeroNearZero(acc.*[0]),
                    zeroNearZero(acc.*[1]),
                };
                vel.* += acc.* * delta_time_vec2f64;
                pos.* += vel.* * delta_time_vec2f64;
            }
            self._applyBoundary(&particles.positions, &particles.velocities, particles.radius, width, height);
            shg.clear();
            shg.computeGridArray(&particles.positions);
            shg.computeStartArray();
            shg.computeSortedArray(&particles.positions);
            shg.detect_collisions(particles, self.dt, self.t_acc, self.particle_damping);
        }
    }
    pub fn applyBoundary(self: *Self, positions: *[]Vec2f64, velocities: *[]Vec2f64, radius: f64, width: f64, height: f64) void {
        for (positions.*, 0..) |*pos, i| {
            if (pos.*[0] < radius) {
                pos.*[0] = radius;
                velocities.*[i][0] *= -self.boundary_damping;
            }
            if (pos.*[0] > width - radius) {
                pos.*[0] = width - radius;
                velocities.*[i][0] *= -self.boundary_damping;
            }
            if (pos.*[1] < radius) {
                pos.*[1] = radius;
                velocities.*[i][1] *= -self.boundary_damping;
            }
            if (pos.*[1] > height - radius) {
                pos.*[1] = height - radius;
                velocities.*[i][1] *= -self.boundary_damping;
            }
        }
    }

    pub fn _applyBoundary(
        self: *Self,
        positions: *[]Vec2f64,
        velocities: *[]Vec2f64,
        radius: f64,
        width: f64,
        height: f64,
    ) void {
        const Vec2bool = @Vector(2, bool);
        const Vec2u1 = @Vector(2, u1);

        const min_bound: Vec2f64 = @splat(radius);
        const max_bound: Vec2f64 = .{ width - radius, height - radius };
        const neg_one: Vec2f64 = @splat(-self.boundary_damping);

        for (positions.*, velocities.*) |*pos, *vel| {
            const below_min: Vec2bool = pos.* < min_bound;
            const above_max: Vec2bool = pos.* > max_bound;

            // Perform bitwise OR on the u1-casted boolean vectors
            const reflect_mask: Vec2bool = @bitCast(@as(Vec2u1, @bitCast(below_min)) | @as(Vec2u1, @bitCast(above_max)));

            // Reflect velocity using the mask
            vel.* = @select(f64, reflect_mask, vel.* * neg_one, vel.*);

            // Clamp positions within the bounds
            pos.* = @min(@max(pos.*, min_bound), max_bound);
        }
    }
    pub fn genericCollisionDetection(particles: *Particles) void {
        for (0..particles.positions.len) |i| {
            for (0..i) |j| {
                const res = checkCollision(
                    particles.positions[i],
                    particles.positions[j],
                    particles.radius,
                );
                if (res) {
                    resolve_collision(particles, i, j);
                }
            }
        }
    }
    pub inline fn distanceSquared(xi: f64, yi: f64, xj: f64, yj: f64) f64 {
        const dx_sq = (xj - xi) * (xj - xi);
        const dy_sq = (yj - yi) * (yj - yi);

        return dx_sq + dy_sq;
    }
    pub fn checkCollision(pos_i: Vec2f64, pos_j: Vec2f64, radius: f64) bool {
        const dist_sq = distanceSquared(pos_i[0], pos_i[1], pos_j[0], pos_j[1]);
        const r_2 = 2.0 * radius;
        if (dist_sq < r_2 * r_2) {
            return true;
        }
        return false;
    }

    pub fn resolve_collision(particles: *Particles, i: usize, j: usize, dt: f64, t_acc: bool, particle_damping: f64) void {
        const pi = particles.positions[i];
        const pj = particles.positions[j];
        const vi = particles.velocities[i];
        const vj = particles.velocities[j];

        const dist = std.math.sqrt(distanceSquared(pi[0], pi[1], pj[0], pj[1]));
        if (dist < 0.0000000001) return;

        // 0 ,1 is x,y respectively in @Vector notation
        const dist_Vec2f64: Vec2f64 = @splat(dist);

        // we have a math-vector
        const normal_vec = (pj - pi) / dist_Vec2f64;

        const rel_vel: Vec2f64 = vj - vi;
        // is a math-scalar and the diection is taken care later
        const velocity_along_normal: f64 = @reduce(.Add, rel_vel * normal_vec);

        const damp = particle_damping;
        const k = -(1.0 + damp) * velocity_along_normal / 2;

        const k_Vec2f64: Vec2f64 = @splat(k);

        const min_dis = 2.0 * particles.radius;

        const overlap = min_dis - dist;
        const correction: Vec2f64 = @splat(overlap * 0.5);
        const dt_Vec2f64: Vec2f64 = @splat(dt);
        if (overlap > 0) {
            if (!t_acc) {
                particles.positions[i] -= correction * normal_vec;
                particles.positions[j] += correction * normal_vec;
            } else {
                const penalty_strength: f64 = 10000.0;
                const penalty_strength_Vec2F64: Vec2f64 = @splat(penalty_strength);
                const overlap_Vec2F64: Vec2f64 = @splat(overlap);
                const penalty_acc_Vec2f64: Vec2f64 = penalty_strength_Vec2F64 * normal_vec * overlap_Vec2F64;
                particles.velocities[i] -= penalty_acc_Vec2f64 * dt_Vec2f64;
                particles.velocities[j] += penalty_acc_Vec2f64 * dt_Vec2f64;
            }
        }
        particles.velocities[i] -= normal_vec * k_Vec2f64;
        particles.velocities[j] += normal_vec * k_Vec2f64;
    }
};
pub const Spawner = struct {
    pub fn spawnRandom(
        par: *Particles,
        rng: *std.Random.DefaultPrng,
        width: f64,
        height: f64,
        min: f64,
        max: f64,
    ) !void {
        for (par.*.positions, par.*.velocities) |*pos, *vel| {
            pos.*[0] = float_random(rng, par.radius, width);
            pos.*[1] = float_random(rng, par.radius, height);
            vel.*[0] = float_random(rng, min, max);
            vel.*[1] = float_random(rng, min, max);
        }
        assignRainbowColors(par);
    }
    pub fn assignRainbowColors(par: *Particles) void {
        const count = par.positions.len;
        for (par.colors, 0..) |*color, i| {
            const hue: f32 = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(count)) * 360.0;
            color.* = Color.hsvToSdlColor(hue, 1.0, 1.0, 255);
        }
    }
};
