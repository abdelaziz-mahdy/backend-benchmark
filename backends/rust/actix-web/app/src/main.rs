use actix_web::{web, App, HttpResponse, HttpServer, Responder};
use serde_json::json;
use deadpool_postgres::{Config, ManagerConfig, Pool, PoolConfig, RecyclingMethod, Runtime};
use std::env;
use tokio_postgres::{NoTls, Row};

mod models;
use models::{NewNote, Note, Page};

const MIGRATION: &str = include_str!("../migration.sql");

fn env_or(key: &str, fallback: &str) -> String {
    env::var(key).ok().filter(|v| !v.is_empty()).unwrap_or_else(|| fallback.to_string())
}

fn to_note(row: &Row) -> Note {
    Note { id: row.get(0), title: row.get(1), content: row.get(2) }
}

async fn health(pool: web::Data<Pool>) -> impl Responder {
    match pool.get().await {
        Ok(client) => match client.batch_execute(MIGRATION).await {
            Ok(_) => HttpResponse::Ok().body("ok"),
            Err(e) => HttpResponse::ServiceUnavailable().body(e.to_string()),
        },
        Err(e) => HttpResponse::ServiceUnavailable().body(e.to_string()),
    }
}

async fn no_db_endpoint() -> impl Responder {
    HttpResponse::Ok().json(json!({ "message": "No db endpoint" }))
}

async fn list_notes(pool: web::Data<Pool>, page: web::Query<Page>) -> impl Responder {
    let limit = page.limit.filter(|v| *v >= 0).unwrap_or(20);
    let offset = page.offset.filter(|v| *v >= 0).unwrap_or(0);
    let client = match pool.get().await {
        Ok(c) => c,
        Err(e) => return HttpResponse::InternalServerError().body(e.to_string()),
    };
    let stmt = client
        .prepare_cached("SELECT id, title, content FROM note ORDER BY id LIMIT $1 OFFSET $2")
        .await;
    let rows = match stmt {
        Ok(stmt) => client.query(&stmt, &[&limit, &offset]).await,
        Err(e) => Err(e),
    };
    match rows {
        Ok(rows) => HttpResponse::Ok().json(rows.iter().map(to_note).collect::<Vec<_>>()),
        Err(e) => HttpResponse::InternalServerError().body(e.to_string()),
    }
}

async fn get_note(pool: web::Data<Pool>, id: web::Path<i32>) -> impl Responder {
    let client = match pool.get().await {
        Ok(c) => c,
        Err(e) => return HttpResponse::InternalServerError().body(e.to_string()),
    };
    let stmt = client.prepare_cached("SELECT id, title, content FROM note WHERE id = $1").await;
    let row = match stmt {
        Ok(stmt) => client.query_opt(&stmt, &[&id.into_inner()]).await,
        Err(e) => Err(e),
    };
    match row {
        Ok(Some(row)) => HttpResponse::Ok().json(to_note(&row)),
        Ok(None) => HttpResponse::NotFound().body("not found"),
        Err(e) => HttpResponse::InternalServerError().body(e.to_string()),
    }
}

async fn create_note(pool: web::Data<Pool>, note: web::Json<NewNote>) -> impl Responder {
    let client = match pool.get().await {
        Ok(c) => c,
        Err(e) => return HttpResponse::InternalServerError().body(e.to_string()),
    };
    let stmt = client
        .prepare_cached("INSERT INTO note (title, content) VALUES ($1, $2) RETURNING id, title, content")
        .await;
    let row = match stmt {
        Ok(stmt) => client.query_one(&stmt, &[&note.title, &note.content]).await,
        Err(e) => Err(e),
    };
    match row {
        Ok(row) => HttpResponse::Created().json(to_note(&row)),
        Err(e) => HttpResponse::InternalServerError().body(e.to_string()),
    }
}

#[actix_web::main]
async fn main() -> anyhow::Result<()> {
    let mut cfg = Config::new();
    cfg.host = Some(env_or("DATABASE_HOST", "db"));
    cfg.port = Some(env_or("DATABASE_PORT", "5432").parse()?);
    cfg.user = Some(env_or("DATABASE_USER", "postgres"));
    cfg.password = Some(env_or("DATABASE_PASSWORD", "postgres"));
    cfg.dbname = Some(env_or("DATABASE_NAME", "postgres"));
    cfg.manager = Some(ManagerConfig { recycling_method: RecyclingMethod::Fast });
    cfg.pool = Some(PoolConfig::new(20));
    let pool = cfg.create_pool(Some(Runtime::Tokio1), NoTls)?;
    let data = web::Data::new(pool);

    HttpServer::new(move || {
        App::new()
            .app_data(data.clone())
            .route("/health", web::get().to(health))
            .route("/no_db_endpoint/", web::get().to(no_db_endpoint))
            .route("/notes/", web::get().to(list_notes))
            .route("/notes/", web::post().to(create_note))
            .route("/notes/{id}", web::get().to(get_note))
    })
    .bind("0.0.0.0:8000")?
    .run()
    .await?;
    Ok(())
}
