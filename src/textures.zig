const sdl = @import("zsdl2");
const sdl_image = @import("zsdl2_image");
pub const texture2d = struct {
    texture: ?*sdl.Texture,

    pub fn load_texture2d(self:*@This(),r:*sdl.Renderer,file:[:0]const u8)!void{
       const surface = try sdl_image.load(file);
       // freeSurface(surface: *Surface)
       defer sdl.freeSurface(surface);
       self.texture = try sdl.createTextureFromSurface(r,surface);
    }
    
    pub fn destroy_texture(self:*@This())void{
        self.texture.?.*.destroy();
    }
};

