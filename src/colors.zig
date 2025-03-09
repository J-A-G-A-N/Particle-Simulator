const sdl = @import("zsdl2");

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

