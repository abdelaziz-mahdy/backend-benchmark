use serde::{Deserialize, Serialize};

#[derive(Serialize)]
pub struct Note {
    pub id: i32,
    pub title: String,
    pub content: String,
}

#[derive(Deserialize)]
pub struct NewNote {
    pub title: String,
    pub content: String,
}

#[derive(Deserialize)]
pub struct Page {
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}
