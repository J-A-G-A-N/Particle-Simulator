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

     fn resize_radius(self: *@This(), new_capacity: usize) !void {
        const new_arr = try self.allocator.realloc(self.radius, new_capacity);
        self.radius = new_arr;
    }
     fn append_color(self: *@This(), color: sdl.Color) !void {
        if (self.len >= self.capacity) try self.resize_color(self.capacity * 2);
        self.colors[self.len] = color;
    }

     fn resize_color(self: *@This(), new_capacity: usize) !void {
        const new_arr = try self.allocator.realloc(self.colors, new_capacity);
        self.colors = new_arr;
    }

     fn append_positions(self: *@This(), pos: struct { x: f32, y: f32 }) !void {
        try self.positions.append(pos.x, pos.y);
        self.update_len();
    }

     fn append_velocities(self: *@This(), velocity: struct { x: f32, y: f32 }) !void {
        try self.velocities.append(velocity.x, velocity.y);
    }

     fn update_particles_colors(self: *@This()) void {
        for (0..self.len) |i| {
            const velocity_magnitude = @sqrt(self.velocities.x[i] * self.velocities.x[i] +
                self.velocities.y[i] * self.velocities.y[i]);
            const normalized_value = velocity_magnitude / vel; // Normalize between 0 and 1
            self.colors[i] = colors.jetColor(normalized_value);
        }
    }

    // make it in way that the program  don't check for gravity for every single calculations

    

    

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
            try particles.append_color(colors.getColor(@as(f32,@floatFromInt(i))));
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
        const flow_spawn_ztracy_zone = ztracy.ZoneNC(@src(), "flow_spawn", 0xff_f0_ff);
        flow_spawn_ztracy_zone.End();

        if (particles.len >= particles.capacity) return; // Stop if full
        _ = self;
        const index = particles.len;

        // Fixed Emission Point
        const emission_x: f32 = 25;
        const emission_y: f32 = 200; // Fixed starting height

        // Sine Wave Motion for Velocity
        // const amplitude: f32 = 150.0;  // How wide the sine wave is
        // const frequency: f32 = 3;   // Controls wave speed
        // const phase_shift: f32 = @divExact((d_t * frequency),180);


        particles.positions.x[index] = emission_x;
        particles.positions.y[index] = emission_y;

        //particles.velocities.y[index] = amplitude * @sin(phase_shift) + amplitude * @cos(phase_shift * 0.5); // Oscillating sideways motion
        particles.velocities.x[index] = 380; // Oscillating sideways motion
        particles.velocities.y[index] = 80; // Moves downward normally
        particles.radius[index] = particles.flags.*.PARTICLE_RADIUS;

        // Rainbow Color
        const particles_per_color_group: usize = 50;
        const num_color_variations: usize = 40;
        const color_group = @divTrunc(index, particles_per_color_group);
        const color_index = @mod(color_group, num_color_variations);
        particles.colors[index] = colors.getColor(@as(f32, @floatFromInt(color_index * particles_per_color_group)));

        
        //JetColor
        // const particles_per_color_group: usize = 50;
        // const num_color_variations: usize = 40;
        // const color_group = @divTrunc(index, particles_per_color_group);
        // const color_index = @mod(color_group, num_color_variations);
        //
        // // Normalize the color index to a value between 0.0 and 1.0 for jetColor
        // const normalized_color_value = @as(f32, @floatFromInt(color_index)) / @as(f32, @floatFromInt(num_color_variations));
        // particles.colors[index] = colors.jetColor(normalized_color_value);
        //

        particles.len += 1;
        d_t += 1;
        std.log.debug("len: {}, capacity: {}, x.len: {}\n", .{ particles.len, particles.capacity, particles.positions.x.len });
    }

    var spawn_timer: f32 = 0;

    pub fn update(spawner: *@This(), dT: f32, particles: *Particles) void {
        spawn_timer += dT;
        if (spawn_timer > 0.1) { // Adjust spawn rate here (0.1s per particle)
            spawner.flow_spawn(particles);
            spawn_timer = 0;
        }
    }

    pub fn create_spawner(method: spawn_method, flags: *Flags) particle_spawner {
        return particle_spawner{ .method = method, .flags = flags };
    }
};
