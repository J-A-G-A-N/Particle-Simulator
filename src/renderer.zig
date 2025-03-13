const sdl = @import("zsdl2");
const ztracy = @import("ztracy");
const colors = @import("colors.zig");
const texture2d = @import("textures.zig").texture2d;


pub const Renderer = struct {
    r:*sdl.Renderer,

    pub fn init(self:*@This(),window:*sdl.Window,index:?i32,flags:sdl.Renderer.Flags) !void {
        self.r = try sdl.createRenderer(
            window, 
            index,
            flags,
        );

    }    

    pub fn clearBackground(self:*@This(), color: sdl.Color) !void {
        try self.r.setDrawColor(color);
        try self.r.clear();
    }

   pub fn destroy(self:*@This())void{
        self.r.destroy();
   } 
   
    
   
   pub fn render_circles_texture_2d(self:*@This(),texture2D:texture2d,circles:struct {
       X:[] f32,
       Y:[] f32,
       color:[]sdl.Color},
       radius: f32,)!void{


        const renderCircles_ztracy_zone = ztracy.ZoneNC(@src(), "drawCircles", 0xff_f0_00);
        defer renderCircles_ztracy_zone.End();
        try sdl.setTextureBlendMode(texture2D.texture.?, .blend);
        _ = sdl.setHint(sdl.hint_windows_dpi_awareness, "permonitorv2"); 
        _ = sdl.setHint(sdl.hint_video_external_context, "1");

    for (0..circles.X.len) |i| {
        try self.render_texture_2d(texture2D, .{
            .x = circles.X[i] - radius,  // Centering Fix
            .y = circles.Y[i] - radius,  // Centering Fix
            .w = radius * 2,  // Scaling Fix
            .h = radius * 2   // Scaling Fix
        }, circles.color[i]);
     // try self.r.setDrawColor(sdl.Color{ .r = 255, .g = 0, .b = 255, .a = 255 }); // Magenta
     //    try self.r.drawRectF(sdl.FRect{
     //        .x = circles.X[i] - radius,
     //        .y = circles.Y[i] - radius,
     //        .w = radius * 2,
     //        .h = radius * 2,
     //    });

    }

   }
    pub fn render_texture_2d(self:*@This(),texture2D:texture2d,rect:struct {
        x:f32,
        y:f32,
        w:f32,
        h:f32,
    },color:sdl.Color)!void{

         var destination_rectangle = sdl.FRect{
             .x = rect.x,
             .y = rect.y,
             .w = rect.w,
             .h = rect.h,
         };
            //try sdl.setTextureBlendMode(texture2D.texture.?, .blend);
            try sdl.setTextureColorMod(texture2D.texture.?, color.r, color.g, color.b); 
            try sdl.renderCopyF(self.r,texture2D.texture.?,null,&destination_rectangle);

 
    }

   pub fn renderCircles(self: *@This(),comptime size:usize,positions:struct {
    X:[] f32,
    Y:[] f32,}, radius: f32, color:sdl.Color)!void{

    const renderCircles_ztracy_zone = ztracy.ZoneNC(@src(), "drawCircles", 0xff_f0_00);
    defer renderCircles_ztracy_zone.End();
    
    try self.r.setDrawColor(color);
    for(0..size)|i|{

        var x: f32 = 0;
        var y: f32 = radius;
        var d: f32 = 3 - (2 * radius);

        while (y >= x) {
            const center_x = positions.X[i] ;
            const center_y = positions.Y[i] ;
            // Draw horizontal scanlines for filling
            try self.renderHorizontalLineF(center_x - x, center_x + x, center_y - y);
            try self.renderHorizontalLineF(center_x - x, center_x + x, center_y + y);
            try self.renderHorizontalLineF(center_x - y, center_x + y, center_y - x);
            try self.renderHorizontalLineF(center_x - y, center_x + y, center_y + x);

            x += 1;

            if (d > 0) {
                y -= 1;
                d += 4 * (x - y) + 10;
            } else {
                d += 4 * x + 6;
            }
        }

    }
}


pub fn renderCircle(self:*@This(), center_x: f32, center_y: f32, radius: f32, color: sdl.Color) !void {
    const renderfilledcirclef_ztracy_zone = ztracy.ZoneNC(@src(), "drawFilledCircleF", 0xff_f0_00);
    defer renderfilledcirclef_ztracy_zone.End();

    // Set the render draw color
    try self.r.setDrawColor(color);

    var x: f32 = 0;
    var y: f32 = radius;
    var d: f32 = 3 - (2 * radius);

    while (y >= x) {
        // Draw horizontal scanlines for filling
        try self.renderHorizontalLineF(center_x - x, center_x + x, center_y - y);
        try self.renderHorizontalLineF(center_x - x, center_x + x, center_y + y);
        try self.renderHorizontalLineF(center_x - y, center_x + y, center_y - x);
        try self.renderHorizontalLineF(center_x - y, center_x + y, center_y + x);

        x += 1;

        if (d > 0) {
            y -= 1;
            d += 4 * (x - y) + 10;
        } else {
            d += 4 * x + 6;
        }
    }
}



fn renderHorizontalLineF(self:*@This(), x1: f32, x2: f32, y: f32) !void {
    var x: f32 = x1;
    while (x <= x2) : (x += 1) {
        try sdl.renderDrawPointF(self.r, x, y);
    }
}

};
