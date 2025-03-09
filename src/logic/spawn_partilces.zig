const std = @import("std");
const Particles = @import("particles.zig").Particles;
const Flags = @import("global.zig").Flags;


pub const spawn_method = enum {
    Random,
    Grid,
    Flow,
};

pub const particle_spawner = struct {
    method: spawn_method,
    flags: *Flags,

    pub fn spawn(self: *@This(), particles: *Particles) void {
        switch (self.method) {
            .Random => self.random_spawn(particles),
            .Grid => self.grid_spawn(particles),
            .Flow => self.flow_spawn(particles),
        }
    }

    fn random_float_clamped_gen(rng: *std.Random, min: f32, max: f32) f32 {
        return std.math.lerp(min, max, rng.float(f32));
    }

    fn random_spawn(self: *@This(), particles: *Particles) void {
        var prng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));

        var rng = prng.random();

        for (0..particles.*.len) |i| {
            particles.*.positions.x[i] = random_float_clamped_gen(&rng, self.flags.*.GRID_SIZE, @as(f32, @floatFromInt(self.flags.*.WINDOW_WIDTH)) -
                particles.*.radius[i] - self.flags.*.GRID_SIZE);

            particles.*.positions.y[i] = random_float_clamped_gen(&rng, self.flags.*.GRID_SIZE + 20, @as(f32, @floatFromInt(self.flags.*.WINDOW_HEIGHT)) -
                particles.*.radius[i] - self.flags.*.GRID_SIZE);
        }
    }

    fn grid_spawn(self: *@This(), particles: *Particles) void {
        _ = self;
        _ = particles.*;
    }
    fn flow_spawn(self: *@This(), particles: *Particles) void {
        _ = self;
        _ = particles.*;
    }

    pub fn create_spawner(method: spawn_method, flags: *Flags) particle_spawner {
        return particle_spawner{ .method = method, .flags = flags };
    }
};

