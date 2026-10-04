package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/gorilla/mux"
	_ "github.com/lib/pq"
)

var db *sql.DB
var serverReady bool

func runMigration() {
	data, err := os.ReadFile("./migration.sql")
	if err != nil {
		log.Fatalf("Unable to read migration file: %v", err)
	}

	_, err = db.Exec(string(data))
	if err != nil {
		log.Printf("Failed to run migration: %v", err)
		serverReady = false
	} else {
		serverReady = true
	}
}

func main() {
	var err error
	db, err = sql.Open("postgres", fmt.Sprintf("user=%s password=%s dbname=%s host=%s port=%s sslmode=disable",
		os.Getenv("DATABASE_USER"),
		os.Getenv("DATABASE_PASSWORD"),
		os.Getenv("DATABASE_NAME"),
		os.Getenv("DATABASE_HOST"),
		os.Getenv("DATABASE_PORT"),
	))
	if err != nil {
		log.Fatalf("Unable to connect to database: %v", err)
	}
	db.SetMaxOpenConns(10)
	// db.SetMaxIdleConns(5)
	defer db.Close()

	runMigration()

	r := mux.NewRouter()

	r.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if serverReady {
			w.WriteHeader(http.StatusOK)
			w.Write([]byte("Server is ready"))
		} else {
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte("Server is not ready"))
		}
	})

	r.HandleFunc("/no_db_endpoint/", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("No db endpoint"))
	})

	r.HandleFunc("/no_db_endpoint2/", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("No db endpoint2"))
	})

	r.HandleFunc("/notes/", func(w http.ResponseWriter, r *http.Request) {
		if r.Method == "GET" {
			rows, err := db.Query("SELECT * FROM note ORDER BY id DESC LIMIT 100")
			if err != nil {
				http.Error(w, "Error fetching notes" + err.Error(), http.StatusInternalServerError)
				return
			}
			defer rows.Close()

			notes := make([]map[string]interface{}, 0)
			for rows.Next() {
				var id int
				var title, content string
				if err := rows.Scan(&id, &title, &content); err != nil {
					http.Error(w, "Error scanning notes: "+err.Error(), http.StatusInternalServerError)
					return
				}
				note := map[string]interface{}{"id": id, "title": title, "content": content}
				notes = append(notes, note)
			}
			writeJSON(w, notes)
		} else if r.Method == "POST" {
			var note struct {
				Title   string `json:"title"`
				Content string `json:"content"`
			}
			if err := json.NewDecoder(r.Body).Decode(&note); err != nil {
				http.Error(w, err.Error(), http.StatusBadRequest)
				return
			}

			_, err := db.Exec("INSERT INTO note (title, content) VALUES ($1, $2)", note.Title, note.Content)
			if err != nil {
				http.Error(w, "Error creating note: "+err.Error() , http.StatusInternalServerError)
				return
			}
			w.WriteHeader(http.StatusCreated)
			w.Write([]byte("Note created"))
		}
	}).Methods("GET", "POST")

	log.Println("Server running on port 8000")
	log.Fatal(http.ListenAndServe(":8000", r))
}

func writeJSON(w http.ResponseWriter, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(v)
}
