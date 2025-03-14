const sdl = @import("zsdl2");
const texture2d = @import("textures.zig").texture2d;
const Renderer = @import("renderer.zig").Renderer;
const Font = @import("zsdl2_ttf").Font;

pub const Text = struct {
    x: f32,
    y: f32,
    size: i32,
    text_texture: texture2d,
    font: *Font,
    renderer: *Renderer,
    frect: sdl.FRect,

    pub fn init(self: *@This(), renderer: *Renderer) void {
        self.text_texture.texture = undefined;
        self.renderer = renderer;
        self.frect = .{
            .x = 0,
            .y = 0,
            .w = 0,
            .h = 0,
        };
    }
    pub fn create(renderer: *Renderer) @This() {
        return Text{
            .text_texture.texture,
            .renderer,
            @This().init(renderer),
        };
    }

    pub fn destroy(self: *@This()) void {
        self.text_texture.destroy_texture();
    }

    pub fn load_font(self: *@This(), font: [:0]const u8, f_size: i32) !void {
        self.font = try Font.open(font, f_size);
        self.size = f_size;
    }
    pub fn draw_text(t_texture: *Text, text: [:0]const u8, pos: struct { x: f32, y: f32 }, color: sdl.Color) !void {
        const surface = try Font.renderTextSolid(t_texture.font, text, color);
        defer surface.*.free();
        t_texture.text_texture.texture.? = try sdl.createTextureFromSurface(t_texture.renderer.r, surface);
        defer t_texture.destroy();
        t_texture.frect.x = pos.x;
        t_texture.frect.y = pos.y;
        t_texture.frect.w = @as(f32, @floatFromInt(surface.*.w)) * 0.9;
        t_texture.frect.h = @as(f32, @floatFromInt(surface.*.h)) * 0.8;

        // t_texture.frect.h = @as(f32,@floatFromInt(t_texture.size));
        // t_texture.frect.w = @as(f32,@floatFromInt(text.len * 10));
        try t_texture.renderer.render_texture_2d(t_texture.text_texture, .{
            .x = t_texture.frect.x,
            .y = t_texture.frect.y,
            .h = t_texture.frect.h,
            .w = t_texture.frect.w,
        }, color);
    }
};
