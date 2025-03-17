const std = @import("std");
const ztracy = @import("ztracy");
const Particles = @import("../particles.zig").Particles;
const Grid_collision_handler = @import("../collision_handler.zig").Grid_collision_handler;
const Boundary = @import("boundary.zig").Boundary;


var dt:f32 = 0;

pub const Solver = struct{
    pub fn update_positions(particles_ptr: *Particles, gch: *Grid_collision_handler, boundary: *Boundary) !void {
        const ztracy_zone = ztracy.ZoneNC(@src(), "update_positions", 0xff_ff_f0);
        ztracy_zone.End();
        const acc_x: f32 = 0;
        var acc_y: f32 = 0;
        if (particles_ptr.flags.*.IF_GRAVITY == true) {
            acc_y = 100;
        }
        const delta_T: f32 = 0.008;
        //const delta_T: f32 = 0.016;
        const substeps: u8 = 8;
         dt = delta_T / @as(f32, @floatFromInt(substeps));
        for (0..substeps) |_| {
            boundary.check_boundary(particles_ptr);
            gch.clear_all_array();
            gch.update_gird_array();
            gch.update_start_array();
            try gch.update_sorted_array();
            gch.detect_collisions();
            //particles_ptr.update_particles_colors();
            
            //Euler method
            // for (0..particles_ptr.len) |i| {
            //
            //     particles_ptr.velocities.x[i] += acc_x * dt;
            //     particles_ptr.velocities.y[i] += acc_y * dt;
            //
            //     particles_ptr.positions.x[i] += particles_ptr.velocities.x[i] * dt;
            //     particles_ptr.positions.y[i] += particles_ptr.velocities.y[i] * dt;
            // }
            

            //LeapFrog
            for (0..particles_ptr.len) |i| {
                const half_velocity_x = particles_ptr.velocities.x[i] + acc_x * dt * 0.5;
                const half_velocity_y = particles_ptr.velocities.y[i] + acc_y * dt * 0.5;


                particles_ptr.positions.x[i] += half_velocity_x * dt;
                particles_ptr.positions.y[i] += half_velocity_y * dt;


                particles_ptr.velocities.x[i] = half_velocity_x + acc_x * dt * 0.5; 
                particles_ptr.velocities.y[i] = half_velocity_y + acc_y * dt * 0.5; 

            }
            
        }
    }



pub fn get_distance_squared(particles_ptr: *Particles, i: usize, j: usize) f32 {
        const dx_2 = (particles_ptr.positions.x[i] - particles_ptr.positions.x[j]) * (particles_ptr.positions.x[i] - particles_ptr.positions.x[j]);
        const dy_2 = (particles_ptr.positions.y[i] - particles_ptr.positions.y[j]) * (particles_ptr.positions.y[i] - particles_ptr.positions.y[j]);

        return dx_2 + dy_2;
    }

    pub fn check_collision(particles_ptr: *Particles, i: usize, j: usize) bool {
        const distance_sqared = get_distance_squared(particles_ptr,i, j);
        const sum_of_radii_squared = (particles_ptr.radius[i] + particles_ptr.radius[j]) * (particles_ptr.radius[i] + particles_ptr.radius[j]);
        if (distance_sqared <= sum_of_radii_squared) {
            return true;
        }
        return false;
    }

    pub fn get_magnitude(particles_ptr: *Particles, i: usize) f32 {
        const dx = particles_ptr.positions.x[i];
        const dy = particles_ptr.positions.y[i];
        return std.math.sqrt((dx * dx) + (dy * dy));
    }

    pub fn dot_produtct(particles_ptr: *Particles, index: usize, x_comp: f32, y_comp: f32) f32 {
        return particles_ptr.velocities.x[index] * x_comp + particles_ptr.velocities.y[index] * y_comp;
    }

    pub fn resolve_collision(particles_ptr: *Particles, i: usize, j: usize) void {
        const distance = std.math.sqrt(get_distance_squared(particles_ptr,i, j));
        if (distance < 0.001) return;
        var normal_vector_x: f32 = 0;
        var normal_vector_y: f32 = 0;
        const mass_i = 2;
        const mass_j = 2;
        normal_vector_x = (particles_ptr.positions.x[j] - particles_ptr.positions.x[i]) / distance;
        normal_vector_y = (particles_ptr.positions.y[j] - particles_ptr.positions.y[i]) / distance;

        const rel_vel_x = particles_ptr.velocities.x[j] - particles_ptr.velocities.x[i];
        const rel_vel_y = particles_ptr.velocities.y[j] - particles_ptr.velocities.y[i];
        const vel_along_normal = rel_vel_x * normal_vector_x + rel_vel_y * normal_vector_y;
        if (vel_along_normal > 0) return;
        const inv_mass_i: f32 = if (mass_i > 0) 1.0 / @as(f32, mass_i) else 0.0;
        const inv_mass_j: f32 = if (mass_j > 0) 1.0 / @as(f32, mass_j) else 0.0;

        const k = -(1 + particles_ptr.flags.*.PARTICLE_COLLISION_DAMPING) * vel_along_normal / (inv_mass_i + inv_mass_j);

        const min_distance = particles_ptr.radius[i] + particles_ptr.radius[j];
        const overlap = min_distance - distance;
        if (overlap > 0) {
            // Weighted separation based on inverse mass
            // const total_inv_mass = inv_mass_i + inv_mass_j;
            // const correction_factor_i = overlap * (inv_mass_i / total_inv_mass);
            // const correction_factor_j = overlap * (inv_mass_j / total_inv_mass);
            //
            // particles_ptr.positions.x[i] -= normal_vector_x * correction_factor_i;
            // particles_ptr.positions.y[i] -= normal_vector_y * correction_factor_i;
            // particles_ptr.positions.x[j] += normal_vector_x * correction_factor_j;
            // particles_ptr.positions.y[j] += normal_vector_y * correction_factor_j;
            const penalty_strength = 10000.0; // Adjust for stability
            const penalty_acc_x = normal_vector_x * penalty_strength * overlap;
            const penalty_acc_y = normal_vector_y * penalty_strength * overlap;

            particles_ptr.velocities.x[i] -= penalty_acc_x * inv_mass_i * dt;
            particles_ptr.velocities.y[i] -= penalty_acc_y * inv_mass_i * dt;
            particles_ptr.velocities.x[j] += penalty_acc_x * inv_mass_j * dt;
            particles_ptr.velocities.y[j] += penalty_acc_y * inv_mass_j * dt;

        }

        particles_ptr.velocities.x[i] -= normal_vector_x * k * inv_mass_i;
        particles_ptr.velocities.y[i] -= normal_vector_y * k * inv_mass_i;

        particles_ptr.velocities.x[j] += normal_vector_x * k * inv_mass_j;
        particles_ptr.velocities.y[j] += normal_vector_y * k * inv_mass_j;
    }

    pub fn generic_collision_detection(particles_ptr: *Particles) void {
        const generic_collision_detection_ztracy_zone = ztracy.ZoneNC(@src(), "gcd", 0xff_00_f0);
        defer generic_collision_detection_ztracy_zone.End();
        for (0..particles_ptr.len) |x| {
            for (0..particles_ptr.len) |y| {
                if (check_collision(particles_ptr,x, y)) {
                    resolve_collision(particles_ptr,x, y);
                }
            }
        }
    }


};



