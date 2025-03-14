const std = @import("std");
const sdl = @import("zsdl2");
const vec2 = @import("vectors.zig").vec2;
const Flags = @import("global.zig").Flags;
const ztracy = @import("ztracy");
const colors = @import("../colors.zig");
const Boundary = @import("solver/boundary.zig").Boundary;
const Grid_collision_handler = @import("collision_handler.zig").Grid_collision_handler;

////////////////////////////
/// TODO: move the partice's update_positions to a solver inerface
////////////////////////////

const vel: f32 = 200;

pub const Particles = struct {
    positions: vec2,
    velocities: vec2,
    len: usize,
    radius: []f32,
    colors: []sdl.Color,
    flags: *Flags,
    allocator: std.mem.Allocator,
    capacity: usize,

    /// Return a pointer to a circles instance
    pub fn init(allocator: std.mem.Allocator, allocation_size: usize, flags_ptr: *Flags) !Particles {
        const particles: Particles = .{
            .positions = try vec2.init(allocator, allocation_size),
            .velocities = try vec2.init(allocator, allocation_size),
            .len = 0,
            .capacity = allocation_size,
            .radius = try allocator.alloc(f32, allocation_size),
            .colors = try allocator.alloc(sdl.Color, allocation_size),
            .flags = flags_ptr,
            .allocator = allocator,
        };
        return particles;
    }

    pub fn update_len(self: *@This()) void {
        self.len = self.positions.len;
    }
    /// Deletes the Circles object
    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.radius);
        self.allocator.free(self.colors);
        self.positions.deinit();
        self.velocities.deinit();
    }
    pub fn append_radius(self: *@This(), radius: f32) !void {
        if (self.len >= self.capacity) try self.resize_radius(self.capacity * 2);
        self.radius[self.len] = radius;
    }

    pub fn resize_radius(self: *@This(), new_capacity: usize) !void {
        const new_arr = try self.allocator.realloc(self.radius, new_capacity);
        self.radius = new_arr;
    }
    pub fn append_color(self: *@This(), color: sdl.Color) !void {
        if (self.len >= self.capacity) try self.resize_color(self.capacity * 2);
        self.colors[self.len] = color;
    }

    pub fn resize_color(self: *@This(), new_capacity: usize) !void {
        const new_arr = try self.allocator.realloc(self.colors, new_capacity);
        self.colors = new_arr;
    }

    pub fn append_positions(self: *@This(), pos: struct { x: f32, y: f32 }) !void {
        try self.positions.append(pos.x, pos.y);
        self.update_len();
    }

    pub fn append_velocities(self: *@This(), velocity: struct { x: f32, y: f32 }) !void {
        try self.velocities.append(velocity.x, velocity.y);
    }

    pub fn update_particles_colors(self: *@This()) void {
        for (0..self.len) |i| {
            const velocity_magnitude = @sqrt(self.velocities.x[i] * self.velocities.x[i] +
                self.velocities.y[i] * self.velocities.y[i]);
            const normalized_value = velocity_magnitude / vel; // Normalize between 0 and 1
            self.colors[i] = colors.jetColor(normalized_value);
        }
    }

    // make it in way that the program  don't check for gravity for every single calculations

    pub fn update_positions(self: *@This(), gch: *Grid_collision_handler, boundary: *Boundary) !void {
        const ztracy_zone = ztracy.ZoneNC(@src(), "update_positions", 0xff_ff_f0);
        ztracy_zone.End();
        const acc_x: f32 = 0;
        var acc_y: f32 = 0;
        if (self.flags.*.IF_GRAVITY == true) {
            acc_y = 200;
        }
        const delta_T: f32 = 0.008;
        //const delta_T: f32 = 0.016;
        const substeps: u8 = 8;
        const dt = delta_T / @as(f32, @floatFromInt(substeps));
        for (0..substeps) |_| {
            boundary.check_boundary(self);
            gch.clear_all_array();
            gch.update_gird_array();
            gch.update_start_array();
            try gch.update_sorted_array();
            gch.detect_collisions();
            //self.update_particles_colors();
            for (0..self.len) |i| {
                self.velocities.x[i] += acc_x * dt;
                self.velocities.y[i] += acc_y * dt;

                self.positions.x[i] += self.velocities.x[i] * dt;
                self.positions.y[i] += self.velocities.y[i] * dt;
            }
        }
    }

    pub fn get_distance_squared(self: *@This(), i: usize, j: usize) f32 {
        const dx_2 = (self.positions.x[i] - self.positions.x[j]) * (self.positions.x[i] - self.positions.x[j]);
        const dy_2 = (self.positions.y[i] - self.positions.y[j]) * (self.positions.y[i] - self.positions.y[j]);

        return dx_2 + dy_2;
    }

    pub fn check_collision(self: *@This(), i: usize, j: usize) bool {
        const distance_sqared = self.get_distance_squared(i, j);
        const sum_of_radii_squared = (self.radius[i] + self.radius[j]) * (self.radius[i] + self.radius[j]);
        if (distance_sqared <= sum_of_radii_squared) {
            return true;
        }
        return false;
    }

    pub fn get_magnitude(self: *@This(), i: usize) f32 {
        const dx = self.positions.x[i];
        const dy = self.positions.y[i];
        return std.math.sqrt((dx * dx) + (dy * dy));
    }

    pub fn dot_produtct(self: *@This(), index: usize, x_comp: f32, y_comp: f32) f32 {
        return self.velocities.x[index] * x_comp + self.velocities.y[index] * y_comp;
    }

    pub fn resolve_collision(self: *@This(), i: usize, j: usize) void {
        const distance = std.math.sqrt(self.get_distance_squared(i, j));
        if (distance < 0.001) return;
        var normal_vector_x: f32 = 0;
        var normal_vector_y: f32 = 0;
        const mass_i = 2;
        const mass_j = 2;
        normal_vector_x = (self.positions.x[j] - self.positions.x[i]) / distance;
        normal_vector_y = (self.positions.y[j] - self.positions.y[i]) / distance;

        const rel_vel_x = self.velocities.x[j] - self.velocities.x[i];
        const rel_vel_y = self.velocities.y[j] - self.velocities.y[i];
        const vel_along_normal = rel_vel_x * normal_vector_x + rel_vel_y * normal_vector_y;
        if (vel_along_normal > 0) return;
        const inv_mass_i: f32 = if (mass_i > 0) 1.0 / @as(f32, mass_i) else 0.0;
        const inv_mass_j: f32 = if (mass_j > 0) 1.0 / @as(f32, mass_j) else 0.0;

        const k = -(1 + self.flags.*.PARTICLE_COLLISION_DAMPING) * vel_along_normal / (inv_mass_i + inv_mass_j);

        const min_distance = self.radius[i] + self.radius[j];
        const overlap = min_distance - distance;
        if (overlap > 0) {
            // Weighted separation based on inverse mass
            const total_inv_mass = inv_mass_i + inv_mass_j;
            const correction_factor_i = overlap * (inv_mass_i / total_inv_mass);
            const correction_factor_j = overlap * (inv_mass_j / total_inv_mass);

            self.positions.x[i] -= normal_vector_x * correction_factor_i;
            self.positions.y[i] -= normal_vector_y * correction_factor_i;
            self.positions.x[j] += normal_vector_x * correction_factor_j;
            self.positions.y[j] += normal_vector_y * correction_factor_j;
        }

        self.velocities.x[i] -= normal_vector_x * k * inv_mass_i;
        self.velocities.y[i] -= normal_vector_y * k * inv_mass_i;

        self.velocities.x[j] += normal_vector_x * k * inv_mass_j;
        self.velocities.y[j] += normal_vector_y * k * inv_mass_j;
    }

    pub fn generic_collision_detection(self: *@This()) void {
        const generic_collision_detection_ztracy_zone = ztracy.ZoneNC(@src(), "gcd", 0xff_00_f0);
        defer generic_collision_detection_ztracy_zone.End();
        for (0..self.len) |x| {
            for (0..self.len) |y| {
                if (self.check_collision(x, y)) {
                    self.resolve_collision(x, y);
                }
            }
        }
    }
};

pub const spawn_method = enum {
    Random,
    Grid,
    Flow,
};

pub const particle_spawner = struct {
    method: spawn_method,
    flags: *Flags,

    pub fn spawn(self: *@This(), particles: *Particles) !void {
        switch (self.method) {
            .Random => try self.random_spawn(particles),
            .Grid => self.grid_spawn(particles),
            .Flow => self.flow_spawn(particles),
        }
    }

    fn random_float_clamped_gen(rng: *std.Random, min: f32, max: f32) f32 {
        return std.math.lerp(min, max, rng.float(f32));
    }

    fn random_spawn(self: *@This(), particles: *Particles) !void {
        try initialize_particles(particles);
        var prng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
        var rng = prng.random();
        var i: usize = 0;

        while (i < particles.*.flags.*.MAX_PARTICLE_COUNT) {

            // Positions
            try particles.append_positions(.{ .x = random_float_clamped_gen(&rng, self.flags.*.GRID_SIZE, @as(f32, @floatFromInt(self.flags.*.WINDOW_WIDTH)) -
                particles.*.radius[i] - self.flags.*.GRID_SIZE), .y = random_float_clamped_gen(&rng, self.flags.*.GRID_SIZE + 20, @as(f32, @floatFromInt(self.flags.*.WINDOW_HEIGHT)) -
                particles.*.radius[i] - self.flags.*.GRID_SIZE) });
            try particles.append_radius(particles.*.flags.*.PARTICLE_RADIUS);

            // velocities
            if (particles.flags.*.IF_GRAVITY) {
                try particles.*.append_velocities(.{ .x = random_float_clamped_gen(&rng, -vel * 0.5, vel * 0.5), .y = 0 });
            }
            try particles.*.append_velocities(.{ .x = random_float_clamped_gen(&rng, -vel, vel), .y = random_float_clamped_gen(&rng, -vel, vel) });
            i += 1;
        }
        std.log.debug("particles len :{}\n", .{particles.len});
        std.log.debug("particles capacity :{}\n", .{particles.capacity});

        std.log.debug("positions len :{}\n", .{particles.positions.len});
        std.log.debug("positions capacity :{}\n", .{particles.positions.capacity});

        std.log.debug("velocities len :{}\n", .{particles.velocities.len});
        std.log.debug("velocities capacity :{}\n", .{particles.velocities.capacity});
    }

    var hue: f32 = 0;
    pub fn initialize_particles(particles: *Particles) !void {
        @memset(particles.*.positions.x, 0);
        @memset(particles.*.positions.y, 0);
        @memset(particles.*.velocities.x, 0);
        @memset(particles.*.velocities.y, 0);
    }

    fn grid_spawn(self: *@This(), particles: *Particles) void {
        _ = self;
        _ = particles.*;
    }

    var d_t: f32 = 0.0; // Time variable
    fn flow_spawn(self: *@This(), particles: *Particles) void {
        if (particles.len >= particles.capacity) return; // Stop if full
        _ = self;
        const index = particles.len;

        // Fixed Emission Point
        const emission_x: f32 = 50;
        const emission_y: f32 = 50.0; // Fixed starting height

        // Sine Wave Motion for Velocity
        // const amplitude: f32 = 470.0;  // How wide the sine wave is
        // const frequency: f32 = 0.05;   // Controls wave speed
        // const phase_shift: f32 = d_t * frequency;

        particles.positions.x[index] = emission_x;
        particles.positions.y[index] = emission_y;

        //particles.velocities.x[index] = amplitude * @sin(phase_shift); // Oscillating sideways motion
        particles.velocities.x[index] = 470; // Oscillating sideways motion
        particles.velocities.y[index] = 100; // Moves downward normally
        particles.radius[index] = particles.flags.*.PARTICLE_RADIUS;

        const particles_per_color_group: usize = 50;
        const num_color_variations: usize = 40;
        const color_group = @divTrunc(index, particles_per_color_group);
        const color_index = @mod(color_group, num_color_variations);
        particles.colors[index] = colors.getColor(@as(f32, @floatFromInt(color_index * particles_per_color_group)));


        particles.len += 1;
        d_t += 1;
        std.log.debug("len: {}, capacity: {}, x.len: {}\n", .{ particles.len, particles.capacity, particles.positions.x.len });
    }

    var spawn_timer: f32 = 0;

    pub fn update(spawner: *@This(), dt: f32, particles: *Particles) void {
        spawn_timer += dt;
        if (spawn_timer > 0.1) { // Adjust spawn rate here (0.1s per particle)
            spawner.flow_spawn(particles);
            spawn_timer = 0;
        }
    }

    pub fn create_spawner(method: spawn_method, flags: *Flags) particle_spawner {
        return particle_spawner{ .method = method, .flags = flags };
    }
};
