const sdl = @import("zsdl2");

const white = sdl.Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
const black = sdl.Color{ .r = 0, .g = 0, .b = 0, .a = 0 };

pub fn hsvToSdlColor(h: f32, s: f32, v: f32, a: u8) sdl.Color {
    const c = v * s;
    const x = c * (1.0 - @abs(@mod(h / 60.0, 2.0) - 1.0));
    const m = v - c;

    var r: f32 = 0;
    var g: f32 = 0;
    var b: f32 = 0;

    if (h < 60.0) {
        r = c;
        g = x;
        b = 0;
    } else if (h < 120.0) {
        r = x;
        g = c;
        b = 0;
    } else if (h < 180.0) {
        r = 0;
        g = c;
        b = x;
    } else if (h < 240.0) {
        r = 0;
        g = x;
        b = c;
    } else if (h < 300.0) {
        r = x;
        g = 0;
        b = c;
    } else {
        r = c;
        g = 0;
        b = x;
    }

    return sdl.Color{
        .r = @intFromFloat((r + m) * 255.0),
        .g = @intFromFloat((g + m) * 255.0),
        .b = @intFromFloat((b + m) * 255.0),
        .a = a,
    };
}
