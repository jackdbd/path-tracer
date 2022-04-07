pub const UserError = error{
    // the user selected a scene to render, but such scene does not exist.
    SceneNotAvailable,
};
