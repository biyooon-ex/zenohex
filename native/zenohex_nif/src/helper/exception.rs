#[derive(rustler::NifException)]
#[module = "ArgumentError"]
pub struct ArgumentError {
    pub message: String,
}
