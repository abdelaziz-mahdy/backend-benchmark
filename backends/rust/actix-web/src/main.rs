use actix_web::{web, App, HttpResponse, HttpServer, Responder};
use dotenv::dotenv;
use std::env;
use tokio_postgres::{NoTls, Error};
use std::fs;
mod models;
use models::Note;
use anyhow::Result;
use actix_web::web::Json;
async fn run_migration(db_pool: &tokio_postgres::Client) -> Result<(), Error> {
    let migration_script = fs::read_to_string("./migration.sql")
        .expect("Failed to read migration script");
    db_pool.batch_execute(&migration_script).await?;
    Ok(())
}

async fn index() -> impl Responder {
    HttpResponse::Ok().body("Server is ready")
}

async fn no_db_endpoint() -> impl Responder {
    HttpResponse::Ok().body("No db endpoint")
}
async fn no_db_endpoint2() -> impl Responder {
    HttpResponse::Ok().body("No db endpoint2")
}
async fn notes(db_pool: web::Data<tokio_postgres::Client>) -> impl Responder {
    let rows = db_pool.query("SELECT * FROM note ORDER BY id DESC LIMIT 100", &[]).await;
    match rows {
        Ok(rows) => {
            let notes: Vec<Note> = rows.iter().map(|row| Note {
                id: row.get("id"),
                title: row.get("title"),
                content: row.get("content"),
            }).collect();
            HttpResponse::Ok().json(notes)
        },
        Err(e) => HttpResponse::InternalServerError().body(format!("Error fetching notes: {}", e)),
    }
}

// Modified create_note function
async fn create_note(db_pool: web::Data<tokio_postgres::Client>, note: Json<Note>) -> impl Responder {
    let result = db_pool.execute(
        "INSERT INTO note (title, content) VALUES ($1, $2)",
        &[&note.title, &note.content],
    ).await;

    match result {
        Ok(_) => HttpResponse::Created().body("Note created"),
        Err(e) => HttpResponse::InternalServerError().body(format!("Error creating note: {}", e)),
    }
}

#[actix_web::main]
async fn main() -> Result<()> {
    dotenv().ok();

    let database_url = format!(
        "host={} port={} user={} password={} dbname={} sslmode=disable",
        env::var("DATABASE_HOST").expect("DATABASE_HOST must be set"),
        env::var("DATABASE_PORT").expect("DATABASE_PORT must be set"),
        env::var("DATABASE_USER").expect("DATABASE_USER must be set"),
        env::var("DATABASE_PASSWORD").expect("DATABASE_PASSWORD must be set"),
        env::var("DATABASE_NAME").expect("DATABASE_NAME must be set"),
    );

    let (client, connection) = tokio_postgres::connect(&database_url, NoTls).await
        .map_err(anyhow::Error::new)?; // Convert the error to anyhow::Error

    tokio::spawn(async move {
        if let Err(e) = connection.await {
            eprintln!("connection error: {}", e);
        }
    });

    run_migration(&client).await;

    // Additional setup for your actix-web application
    let data = web::Data::new(client);

    HttpServer::new(move || {
        App::new()
            .app_data(data.clone())
            .route("/", web::get().to(index))
            .route("/no_db_endpoint/", web::get().to(no_db_endpoint))
            .route("/no_db_endpoint2/", web::get().to(no_db_endpoint2))
            .route("/notes/", web::get().to(notes))
            .route("/notes/", web::post().to(create_note))
    })
    .bind("0.0.0.0:8000")?
    .run()
    .await
    .map_err(anyhow::Error::new) // Convert the error to anyhow::Error
}