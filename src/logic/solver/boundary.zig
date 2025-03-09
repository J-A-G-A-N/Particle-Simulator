const std = @import("std");
const Particles = @import("../particles.zig").Particles;
const Flags = @import("../global.zig").Flags;

// Handle Boundry Conditions

pub const Boundary_type = enum {
    window,
    //box,
};

pub const Boundary = struct {
    type: Boundary_type,
    flags: *Flags,

    pub fn check_boundary(self: *@This(), particles: *Particles) void {
        switch (self.type) {
            .window => self.check_boundary_window(particles),
        }
    }

    fn check_boundary_window(self: *@This(), particles: *Particles) void {
        for (0..particles.*.len) |i| {
            const width = @as(f32, @floatFromInt(self.flags.*.WINDOW_WIDTH)) - self.flags.*.GRID_SIZE;
            const height = @as(f32, @floatFromInt(self.flags.*.WINDOW_HEIGHT )) - self.flags.*.GRID_SIZE;
            // Right Boundary
            if (particles.*.positions.x[i] > width - particles.*.radius[i]) {
                particles.*.positions.x[i] = width - particles.*.radius[i];
                particles.*.velocities.x[i] *= -self.flags.*.DAMPING_FACTOR;
            }

            if (particles.*.positions.x[i] < self.flags.*.GRID_SIZE + particles.*.radius[i]) { // Left Boundary
                particles.*.positions.x[i] = self.flags.*.GRID_SIZE + particles.*.radius[i];
                particles.*.velocities.x[i] *= -self.flags.*.DAMPING_FACTOR;
            }

            if (particles.*.positions.y[i] > height - particles.*.radius[i]) { // Bottom Boundary
                particles.*.positions.y[i] = height - particles.*.radius[i];
                particles.*.velocities.y[i] *= -self.flags.*.DAMPING_FACTOR;
            }
            if (particles.*.positions.y[i] < self.flags.*.GRID_SIZE + 20 ) { // Top Boundary
                particles.*.positions.y[i] = self.flags.*.GRID_SIZE + 20;
                particles.*.velocities.y[i] *= -self.flags.*.DAMPING_FACTOR;
            }
        }
    }
    pub fn create_boundry(boundary_type: Boundary_type, flags: *Flags) Boundary {
        return Boundary{ .type = boundary_type, .flags = flags };
    }
};
