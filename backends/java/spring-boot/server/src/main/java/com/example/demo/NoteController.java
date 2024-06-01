package com.example.demo;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
public class NoteController {

    @Autowired
    private NoteRepository noteRepository;

    @GetMapping("/notes/")
    public List<Note> getAllNotes() {
        return noteRepository.findAll();
    }

    @PostMapping("/notes/")
    public ResponseEntity<String> createNote(@RequestBody Note note) {
        noteRepository.save(note);
        return ResponseEntity.status(201).body("Note created");
    }

    @GetMapping("/no_db_endpoint/")
    public ResponseEntity<String> noDbEndpoint() {
        return ResponseEntity.ok("No db endpoint");
    }

    @GetMapping("/no_db_endpoint2/")
    public ResponseEntity<String> noDbEndpoint2() {
        return ResponseEntity.ok("No db endpoint2");
    }

    @GetMapping("/")
    public ResponseEntity<String> serverStatus() {
        return ResponseEntity.ok("OK");
    }
}
