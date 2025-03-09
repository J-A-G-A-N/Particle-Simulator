const std = @import("std");
const sdl = @import("zsdl2");
const vec2 = @import("vectors.zig").vec2;
const Flags = @import("global.zig").Flags;
const ztracy = @import("ztracy");
const colors = @import("../colors.zig");
const Boundary = @import("solver/boundary.zig").Boundary;
const  Gird_collision_handler = @import("collision_handler.zig").Gird_collision_handler;

////////////////////////////
/// TODO: Update the spawn to check for the boundry flags once created
/// TODO: move the partice's update_positions to a solver inerface
////////////////////////////

const vel:f32 = 500;

pub const Particles = struct {
    positions: vec2,
    velocities: vec2,
    len: usize,
    radius: []f32,
    colors: []sdl.Color,
    flags: *Flags,
    allocator: std.mem.Allocator,

    /// Return a pointer to a circles instance
    pub fn init(allocator: std.mem.Allocator, size: usize, flags_ptr: *Flags) !Particles {
        var particles: Particles = .{
            .positions = try vec2.init(allocator, size),
            .velocities = try vec2.init(allocator, size),
            .len = size,
            .radius = try allocator.alloc(f32, size),
            .colors = try allocator.alloc(sdl.Color, size),
            .flags = flags_ptr,
            .allocator = allocator,
        };
        initialize_particles(&particles);
        return particles;
    }

    fn random_float_clamped_gen(rng: *std.Random, min: f32, max: f32) f32 {
        return std.math.lerp(min, max, rng.float(f32));
    }

    fn random_u8(rng: *std.Random, min: u8, max: u8) u8 {
    return @as(u8, rng.intRangeAtMost(u8, min, max));
}

    pub fn initialize_particles(particles: *Particles) void {
        var prng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));

        var rng = prng.random();
        @memset(particles.*.positions.x, 0);
        @memset(particles.*.positions.y, 0);
        for (0..particles.*.len) |i| {
            particles.*.radius[i] = particles.*.flags.*.PARTICLE_RADIUS;
            particles.*.colors[i] = colors.Red;
            // Take rng in spwan particles and make it a seperate file and implement
            // particles.*.velocities.x[i] = @as(f32, @floatFromInt(rl.getRandomValue(-500, 500)));
            // particles.*.velocities.y[i] = @as(f32, @floatFromInt(rl.getRandomValue(-500, 500)));
            particles.*.velocities.x[i] = random_float_clamped_gen(&rng, -vel,vel);
            particles.*.velocities.y[i] = random_float_clamped_gen(&rng, -vel,vel);
            particles.update_particles_colors();
            //particles.*.colors[i] = getColor(@as(f32,@floatFromInt(i)));
            //const hue: f32 = random_float_clamped_gen(&rng, 0, 360.0); // Full spectrum
            //particles.*.colors[i] = hsvToRgb(hue, 0.8, 0.8);
            //particles.update_particles_colors();
                       // particles.*.colors[i] =  .{
            //     .r  =  random_u8(&rng, 0,255),
            //     .g  =  random_u8(&rng, 0,255),
            //     .b  =  random_u8(&rng, 0,255),
            //     .a  =  255,
            // };
        }
    }
   

    fn hsvToRgb(h: f32, s: f32, v: f32) sdl.Color {
        const c = v * s;
        const x = c * (1.0 - @abs(@mod(h / 60.0, 2.0) - 1.0));
        const m = v - c;
        
        var r: f32 = 0.0;
        var g: f32 = 0.0;
        var b: f32 = 0.0;

        if (h < 60.0) {
            r = c; g = x; b = 0.0;
        } else if (h < 120.0) {
            r = x; g = c; b = 0.0;
        } else if (h < 180.0) {
            r = 0.0; g = c; b = x;
        } else if (h < 240.0) {
            r = 0.0; g = x; b = c;
        } else if (h < 300.0) {
            r = x; g = 0.0; b = c;
        } else {
            r = c; g = 0.0; b = x;
        }

        return .{
            .r = @as(u8, @intFromFloat((r + m) * 255.0)),
            .g = @as(u8, @intFromFloat((g + m) * 255.0)),
            .b = @as(u8, @intFromFloat((b + m) * 255.0)),
            .a = 255,
        };
    }

    
    fn getColor(t: f32) sdl.Color {
    const r = @sin(t);
    const g = @sin(t + 0.33 * 2.0 * std.math.pi);
    const b = @sin(t + 0.66 * 2.0 * std.math.pi);

    return .{
        .r = @as(u8, @intFromFloat(255.0 * r * r)),
        .g = @as(u8, @intFromFloat(255.0 * g)),
        .b = @as(u8, @intFromFloat(255.0 * b * b)),
        .a = 255,
    };
}



    pub fn update_particles_colors(self:*@This())void{
        for (0..self.len) |i| {
        const velocity_magnitude = @sqrt(self.velocities.x[i] * self.velocities.x[i] +
                                     self.velocities.y[i] * self.velocities.y[i]);
        const normalized_value = velocity_magnitude / vel; // Normalize between 0 and 1
            self.colors[i] = colors.jetColor(normalized_value);
       }
    }
    /// Deletes the Circles object
    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.radius);
        self.allocator.free(self.colors);
        self.positions.deinit();
        self.velocities.deinit();
    }

    // make it in way that the program  don't check for gravity for every single calculations

    pub fn update_positions(self: *@This(),gch:*Gird_collision_handler,boundary:*Boundary) !void {
            
        const ztracy_zone = ztracy.ZoneNC(@src(),"update_positions", 0xff_ff_f0);
        ztracy_zone.End();
        const acc_x:f32 = 0;
        var acc_y:f32 = 0;
        if (self.flags.*.IF_GRAVITY == true){
            acc_y = 500;
        }
        const delta_T: f32 = 0.008;
        const substeps: u8 = 8;
        const dt = delta_T / @as(f32, @floatFromInt(substeps));
        for (0..substeps) |_| {
            boundary.check_boundary(self);
            gch.clear_all_array();
            gch.update_gird_array();
            gch.update_start_array();
            try gch.update_sorted_array();
            gch.detect_collisions();
            self.update_particles_colors();
                for (0..self.len) |i| {
                
                self.velocities.x[i] += acc_x * dt;
                self.velocities.y[i] += acc_y * dt;

                self.positions.x[i] += self.velocities.x[i] * dt;
                self.positions.y[i] += self.velocities.y[i] * dt;
            }
        }
    }

    pub fn get_distance(self: *@This(), i: usize, j: usize) f32 {
        const dx_2 = ( self.positions.x[i] -  self.positions.x[j]) * ( self.positions.x[i] -  self.positions.x[j]);
        const dy_2 = ( self.positions.y[i] - self.positions.y[j]) * ( self.positions.y[i] - self.positions.y[j]);

        return std.math.sqrt(dx_2 + dy_2);
    }

    pub fn check_collision(self: *@This(), i: usize, j: usize) bool {
        //std.log.debug("check_collision",.{});
        const distance: f32 = self.get_distance(i, j);
        const sum_of_radii = self.radius[i] + self.radius[j];
        if (distance <= sum_of_radii) {
            return true;
        }
        return false;
    }

    pub fn get_magnitude(self: *@This(), i: usize) f32 {
        const dx = self.positions.x[i];
        const dy = self.positions.y[i];
        return std.math.sqrt((dx*dx) + (dy * dy));
    }

    pub fn dot_produtct(self: *@This(), index: usize, x_comp:f32,y_comp:f32) f32 {
        return self.velocities.x[index] * x_comp + self.velocities.y[index] * y_comp;
    }

    pub fn resolve_collision(self: *@This(), i: usize, j: usize) void {

        //std.log.debug("resolve_collision",.{});
        const distance = self.get_distance(i, j);
        if ( distance < 0.001 ) return;
        var normal_vector_x:f32 = 0 ;
        var normal_vector_y:f32 = 0 ;
        const mass_i = 0.1;
        const mass_j = 0.1;
        normal_vector_x = (self.positions.x[j] - self.positions.x[i]) / distance;
        normal_vector_y = (self.positions.y[j] - self.positions.y[i]) / distance;

        //const p_value = 2 * (self.dot_produtct(i, normal_vector_x,normal_vector_y) - self.dot_produtct(j, normal_vector_x,normal_vector_y)) / (mass_i + mass_j);


        const rel_vel_x = self.velocities.x[j] - self.velocities.x[i];
        const rel_vel_y = self.velocities.y[j] - self.velocities.y[i]; 
        const vel_along_normal = rel_vel_x * normal_vector_x + rel_vel_y * normal_vector_y;
        if (vel_along_normal > 0)return;
        const inv_mass_i: f32 = if (mass_i > 0) 1.0 / @as(f32, mass_i) else 0.0;
        const inv_mass_j: f32 = if (mass_j > 0) 1.0 / @as(f32, mass_j) else 0.0;


        const k = - (1 + self.flags.*.PARTICLE_COLLISION_DAMPING) * vel_along_normal / (inv_mass_i + inv_mass_j);
        // const new_velocity_i_x = self.velocities.x[i] - p_value * normal_vector_x * mass_i ;
        // const new_velocity_i_y = self.velocities.y[i] - p_value * normal_vector_y * mass_i ; 
        //
        // const new_velocity_j_x = self.velocities.x[j] + p_value * normal_vector_x * mass_j ; 
        // const new_velocity_j_y = self.velocities.y[j] + p_value * normal_vector_y * mass_j ;
        const min_distance = self.radius[i] + self.radius[j] ;
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
        
            

        // self.velocities.x[i] = new_velocity_i_x ;
        // self.velocities.y[i] = new_velocity_i_y ;
        //
        // self.velocities.x[j] = new_velocity_j_x ;
        // self.velocities.y[j] = new_velocity_j_y ;
        // const overlap = ( min_distance - distance) ; 
        // if (overlap > 0 ){
        //     const correction_factor_i = overlap * 0.5;
        //     const correction_factor_j = overlap * 0.5;
        //     self.positions.x[i] -= normal_vector_x * correction_factor_i; 
        //     self.positions.y[i] -= normal_vector_y * correction_factor_i; 
        //
        //     self.positions.x[j] += normal_vector_x * correction_factor_j; 
        //     self.positions.y[j] += normal_vector_y * correction_factor_j; 
        //
        // }
        
         
        // const percent: f32 = 1; // Adjust this (higher = stronger push)
        // const slop: f32 = 0.01;   // Small threshold to reduce jitter
        //
        // if (overlap > slop) {
        //     const correction = percent * overlap / (inv_mass_i + inv_mass_j);
        //
        //     self.positions.x[i] -= normal_vector_x * correction * inv_mass_i;
        //     self.positions.y[i] -= normal_vector_y * correction * inv_mass_i;
        //
        //     self.positions.x[j] += normal_vector_x * correction * inv_mass_j;
        //     self.positions.y[j] += normal_vector_y * correction * inv_mass_j;
        // }

    }

    pub fn generic_collision_detection(self:*@This())void{
        const generic_collision_detection_ztracy_zone = ztracy.ZoneNC(@src(),"gcd",0xff_00_f0);
        defer generic_collision_detection_ztracy_zone.End();
        for (0..self.len)|x|{
            for(0..self.len)|y|{
                if (self.check_collision(x,y)){
                    self.resolve_collision(x,y);
                }
            }
        }
    }
        
};


