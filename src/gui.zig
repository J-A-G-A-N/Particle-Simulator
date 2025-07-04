const std = @import("std");
const stdout = std.io.getStdOut().writer();
const sdl = @import("zsdl2");
const sdl_image_load = @import("zsdl2_image").load;

pub const Gui = struct {
    window: Window,
    renderer: Renderer,
    const Self = @This();
    pub fn init(title: ?[*:0]const u8, width: i32, height: i32) !Self {
        var window = try Window.init(title, width, height);
        const renderer = try Renderer.init(&window, -1, .{ .accelerated = true });
        return Self{
            .window = window,
            .renderer = renderer,
        };
    }

    pub fn deinit(self: *Self) void {
        self.renderer.deinit();
        self.window.deinit();
    }

    pub fn maintainFPS(self: *@This(), time_stamp_ns: i128, fps: u64) void {
        _ = self;
        const current_time_stamp_ns = std.time.nanoTimestamp();
        const frame_time_ns: u64 = std.time.ns_per_s / fps;

        const elapsed_time = current_time_stamp_ns - time_stamp_ns;

        if (elapsed_time < frame_time_ns) {
            const remaining_time_ns = frame_time_ns - elapsed_time;
            const remaining_time_u64: u64 = @intCast(remaining_time_ns);
            const elapsed_ms = @divTrunc(elapsed_time, std.time.ns_per_ms);
            stdout.print("\x1b[2J\x1b[H", .{}) catch {};
            stdout.print("Frame Render Time:{d:.3} ms\n", .{elapsed_ms}) catch {};
            std.time.sleep(remaining_time_u64);
        }
    }
};

const Window = struct {
    sdl_window: *sdl.Window,
    const Self = @This();
    pub fn init(title: ?[*:0]const u8, width: i32, height: i32) !Self {
        return Self{
            .sdl_window = try sdl.createWindow(title, 0, 0, width, height, .{ .allow_highdpi = false }),
        };
    }

    pub fn deinit(self: *Self) void {
        sdl.destroyWindow(self.sdl_window);
    }
};

const Renderer = struct {
    sdl_renderer: *sdl.Renderer,
    const Self = @This();
    pub fn init(window: *Window, index: ?i32, flags: sdl.Renderer.Flags) !Self {
        return Self{
            .sdl_renderer = try sdl.createRenderer(window.sdl_window, index, flags),
        };
    }

    pub fn deinit(self: *Self) void {
        sdl.destroyRenderer(self.sdl_renderer);
    }

    pub fn clearScreen(self: Self, sdl_color: sdl.Color) !void {
        try self.sdl_renderer.setDrawColor(sdl_color);
    }

    pub fn renderTexture(self: *Self, texture_2D: Texture_2D, rect: sdl.FRect, color: sdl.Color) !void {
        try sdl.setTextureColorMod(
            texture_2D.texture.?,
            color.r,
            color.g,
            color.b,
        );
        try sdl.renderCopyF(self.sdl_renderer, texture_2D.texture.?, null, &rect);
    }

    pub fn drawCircle(self: *Self, circle_texture: Texture_2D, radius: f32, x: f32, y: f32, color: sdl.Color) !void {
        const dia = 2.0 * radius;
        try self.renderTexture(circle_texture, .{ .h = dia, .w = dia, .x = x - radius, .y = y - radius }, color);
    }

    pub fn drawCircles(self: *Self, circle_texture: Texture_2D, radius: f32, x: *[]f32, y: *[]f32, colors: *[]sdl.Color) !void {
        for (x.*, y.*, 0..) |dx, dy, i| {
            try self.drawCircle(circle_texture, radius, dx, dy, colors.*[i]);
        }
    }
};

pub const Texture_2D = struct {
    texture: ?*sdl.Texture,

    const Self = @This();
    pub fn loadTexture(self: *Self, renderer: Renderer, file_path: [:0]const u8) !void {
        const texture_surface = try sdl_image_load(file_path);

        defer sdl.freeSurface(texture_surface);

        self.texture = try sdl.createTextureFromSurface(renderer.sdl_renderer, texture_surface);
    }

    pub fn destoryTexture_2D(self: *Self) void {
        self.texture.?.*.destroy();
    }
};
