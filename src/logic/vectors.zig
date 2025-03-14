const std = @import("std");
const simd = std.simd;

pub const vec2 = struct {
    x: []f32,
    y: []f32,
    len: usize, // Represents the no of used space
    capacity: usize, //Represets the no of spaces
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, size: usize) !vec2 {
        return vec2{
            .x = try allocator.alloc(f32, size),
            .y = try allocator.alloc(f32, size),
            .len = 0,
            .capacity = size,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.x);
        self.allocator.free(self.y);
    }

    pub fn append(self: *vec2, x_val: f32, y_val: f32) !void {
        if (self.len >= self.capacity) try self.resize(self.capacity * 2);
        self.x[self.len] = x_val;
        self.y[self.len] = y_val;
        self.len += 1;
    }

    pub fn resize(self: *vec2, new_capacity: usize) !void {
        const new_x = try self.allocator.realloc(self.x, new_capacity);
        const new_y = try self.allocator.realloc(self.y, new_capacity);
        self.x = new_x;
        self.y = new_y;
        self.capacity = new_capacity;
    }

    pub fn pop(self: *vec2) ?[2]f32 {
        if (self.len == 0) return null;
        self.len -= 1;
        return .{ self.x[self.len], self.y[self.len] };
    }

    pub fn MVSVX(self: *@This(), other: *vec2, result: vec2) void {
        const simdf32vec = @Vector(16, f32);

        var i: usize = 0;
        if (self.len > 16) {
            while (i + 16 <= self.len) : (i += 16) {
                const self_vx: simdf32vec = @as(*const [16]f32, @ptrCast(&self.x[i])).*;
                const other_vx: simdf32vec = @as(*const [16]f32, @ptrCast(&other.x[i])).*;
                const result_vx = self_vx * other_vx;
                @as(*[16]f32, @ptrCast(&result.x[i])).* = result_vx;
            }
            for (i..self.len) |j| {
                result.x[j] = self.x[j] * other.x[j];
            }
        }
    }

    pub fn MVSVY(self: *@This(), other: *vec2, result: vec2) void {
        const simdf32vec = @Vector(16, f32);

        var i: usize = 0;
        if (self.len > 16) {
            while (i + 16 <= self.len) : (i += 16) {
                const self_vy: simdf32vec = @as(*const [16]f32, @ptrCast(&self.y[i])).*;
                const other_vy: simdf32vec = @as(*const [16]f32, @ptrCast(&other.y[i])).*;
                const result_vy = self_vy * other_vy;
                @as(*[16]f32, @ptrCast(&result.y[i])).* = result_vy;
            }
            for (i..self.len) |j| {
                result.y[j] = self.y[j] * other.y[j];
            }
        }
    }

    pub fn MVSV(self: *@This(), other: *vec2, result: vec2) void {
        const simdf32vec = @Vector(16, f32);

        var i: usize = 0;
        if (self.len > 16) {
            while (i + 16 <= self.len) : (i += 16) {
                const self_vx: simdf32vec = @as(*const [16]f32, @ptrCast(&self.x[i])).*;
                const self_vy: simdf32vec = @as(*const [16]f32, @ptrCast(&self.y[i])).*;

                const other_vx: simdf32vec = @as(*const [16]f32, @ptrCast(&other.x[i])).*;
                const other_vy: simdf32vec = @as(*const [16]f32, @ptrCast(&other.y[i])).*;

                const result_vx = self_vx * other_vx;
                const result_vy = self_vy * other_vy;
                @as(*[16]f32, @ptrCast(&result.x[i])).* = result_vx;
                @as(*[16]f32, @ptrCast(&result.y[i])).* = result_vy;
            }
            for (i..self.len) |j| {
                result.x[j] = self.x[j] * other.x[j];
                result.y[j] = self.y[j] * other.y[j];
            }
        }
    }

    //
    //
    //    pub fn MVSVY(self:*@This(),other:*vec2)vec2.y{
    //        const simd_vec = @Vector(self.len, f32);
    //        const vec1y:simd_vec = self.y[0..][0..].*;
    //        const vec2y:simd_vec = other.y[0..][0..].*;
    //        const result_bv = vec1y * vec2y;
    //        const result:vec2.x = result_bv;
    //        return result;
    //
    //    }
    //
    //    // pub fn MVSV(self:*@This(),other:*vec2)vec{
    //    //
    //    // }
    //
    //
};
