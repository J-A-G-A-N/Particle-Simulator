const sdl = @import("zsdl2");
const std = @import("std");

// //White
pub const White:sdl.Color = .{
    .r = 255,
    .g = 255,
    .b = 255,
    .a = 255 
};

pub const Raywhite:sdl.Color = .{
    .r = 245,
    .g = 245,
    .b = 245,
    .a = 255,
};

pub const Red:sdl.Color = .{
    .r = 255,
    .g = 0,
    .b = 0,
    .a = 255 
};

pub const Green:sdl.Color = .{
    .r = 0,
    .g = 255,
    .b = 0,
    .a = 255 
};

pub const Blue:sdl.Color = .{
    .r = 0,
    .g = 0,
    .b = 255,
    .a = 255 
};

// Black
pub const Black:sdl.Color  = .{
    .r = 0,
    .g = 0,
    .b = 0,
    .a = 255 
};

pub fn jetColor(value: f32) sdl.Color {
    const r: f32 = @min(@max(1.5 - @abs(4.0 * value - 3.0), 0.0), 1.0);
    const g: f32 = @min(@max(1.5 - @abs(4.0 * value - 2.0), 0.0), 1.0);
    const b: f32 = @min(@max(1.5 - @abs(4.0 * value - 1.0), 0.0), 1.0);
    
    return .{
        .r = @as(u8, @intFromFloat(r * 255.0)),
        .g = @as(u8, @intFromFloat(g * 255.0)),
        .b = @as(u8, @intFromFloat(b * 255.0)),
        .a = 255,
    };
}
pub fn hsvToRgb(h: f32, s: f32, v: f32) sdl.Color {
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


pub fn getColor(t: f32) sdl.Color {
    const r = (@sin(t) * 0.5) + 0.5;
    const g = (@sin(t + 0.33 * 2.0 * std.math.pi) * 0.5 ) + 0.5;
    const b = (@sin(t + 0.66 * 2.0 * std.math.pi) * 0.5 ) + 0.5;

    return .{
        .r = @as(u8, @intFromFloat(255.0 * r * r)),
        .g = @as(u8, @intFromFloat(255.0 * g)),
        .b = @as(u8, @intFromFloat(255.0 * b * b)),
        .a = 255,
    };
}



