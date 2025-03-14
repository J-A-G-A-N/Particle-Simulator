pub const Flags = struct {
    WINDOW_WIDTH: i32,
    WINDOW_HEIGHT: i32,
    TARGET_FPS: u16,
    MAX_PARTICLE_COUNT: usize,
    PARTICLE_RADIUS: f32,
    DAMPING_FACTOR: f32,
    PARTICLE_COLLISION_DAMPING: f32,
    GRID_SIZE: f32,
    PAUSED: bool,
    IF_GRAVITY: bool,
};
