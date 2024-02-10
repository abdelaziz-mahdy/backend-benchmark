// src/models.rs
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize)]
pub struct Note {
    pub id: i32,
    pub title: String,
    pub content: String,
}

// Used for creating new notes, does not include an id
#[derive(Serialize, Deserialize)]
pub struct NewNote {
    pub title: String,
    pub content: String,
}