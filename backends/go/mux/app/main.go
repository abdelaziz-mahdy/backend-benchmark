package main

import (
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"sync/atomic"

	"github.com/gorilla/mux"
	_ "github.com/lib/pq"
)

type Note struct {
	ID      int    `json:"id"`
	Title   string `json:"title"`
	Content string `json:"content"`
}

var db *sql.DB

func env(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func main() {
	var err error
	db, err = sql.Open("postgres", fmt.Sprintf("user=%s password=%s dbname=%s host=%s port=%s sslmode=disable",
		env("DATABASE_USER", "postgres"),
		env("DATABASE_PASSWORD", "postgres"),
		env("DATABASE_NAME", "postgres"),
		env("DATABASE_HOST", "db"),
		env("DATABASE_PORT", "5432"),
	))
	if err != nil {
		log.Fatalf("Unable to open database: %v", err)
	}
	db.SetMaxOpenConns(20)
	db.SetMaxIdleConns(20)
	defer db.Close()

	migration, err := os.ReadFile("./migration.sql")
	if err != nil {
		log.Fatalf("Unable to read migration file: %v", err)
	}
	var migrated atomic.Bool

	r := mux.NewRouter()

	r.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		if !migrated.Load() {
			if _, err := db.Exec(string(migration)); err != nil {
				http.Error(w, "not ready: "+err.Error(), http.StatusServiceUnavailable)
				return
			}
			migrated.Store(true)
		}
		w.Write([]byte("ok"))
	}).Methods("GET")

	r.HandleFunc("/no_db_endpoint/", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"message": "No db endpoint"})
	}).Methods("GET")

	r.HandleFunc("/notes/", func(w http.ResponseWriter, r *http.Request) {
		limit := queryInt(r, "limit", 20)
		offset := queryInt(r, "offset", 0)
		rows, err := db.Query("SELECT id, title, content FROM note ORDER BY id LIMIT $1 OFFSET $2", limit, offset)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		defer rows.Close()
		notes := make([]Note, 0, limit)
		for rows.Next() {
			var n Note
			if err := rows.Scan(&n.ID, &n.Title, &n.Content); err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			notes = append(notes, n)
		}
		writeJSON(w, http.StatusOK, notes)
	}).Methods("GET")

	r.HandleFunc("/notes/", func(w http.ResponseWriter, r *http.Request) {
		var n Note
		if err := json.NewDecoder(r.Body).Decode(&n); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		err := db.QueryRow("INSERT INTO note (title, content) VALUES ($1, $2) RETURNING id", n.Title, n.Content).Scan(&n.ID)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		writeJSON(w, http.StatusCreated, n)
	}).Methods("POST")

	r.HandleFunc("/notes/{id:[0-9]+}", func(w http.ResponseWriter, r *http.Request) {
		id, _ := strconv.Atoi(mux.Vars(r)["id"])
		var n Note
		err := db.QueryRow("SELECT id, title, content FROM note WHERE id = $1", id).Scan(&n.ID, &n.Title, &n.Content)
		if errors.Is(err, sql.ErrNoRows) {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		writeJSON(w, http.StatusOK, n)
	}).Methods("GET")

	log.Println("Server running on port 8000")
	log.Fatal(http.ListenAndServe(":8000", r))
}

func queryInt(r *http.Request, key string, fallback int) int {
	if v, err := strconv.Atoi(r.URL.Query().Get(key)); err == nil && v >= 0 {
		return v
	}
	return fallback
}

func writeJSON(w http.ResponseWriter, status int, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}
