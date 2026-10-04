package com.example.demo;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
public class NoteController {

    private final NoteRepository notes;

    public NoteController(NoteRepository notes) {
        this.notes = notes;
    }

    @GetMapping("/health")
    public ResponseEntity<String> health() {
        try {
            notes.existsById(0L);
            return ResponseEntity.ok("ok");
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body("not ready: " + e.getMessage());
        }
    }

    @GetMapping("/no_db_endpoint/")
    public Map<String, String> noDbEndpoint() {
        return Map.of("message", "No db endpoint");
    }

    @GetMapping("/notes/")
    public List<Note> list(@RequestParam(defaultValue = "20") int limit,
                           @RequestParam(defaultValue = "0") int offset) {
        return notes.page(Math.max(limit, 0), Math.max(offset, 0));
    }

    @GetMapping("/notes/{id}")
    public ResponseEntity<Note> get(@PathVariable long id) {
        return notes.findById(id).map(ResponseEntity::ok).orElseGet(() -> ResponseEntity.notFound().build());
    }

    @PostMapping("/notes/")
    public ResponseEntity<Note> create(@RequestBody Note note) {
        note.setId(null);
        return ResponseEntity.status(HttpStatus.CREATED).body(notes.save(note));
    }
}
