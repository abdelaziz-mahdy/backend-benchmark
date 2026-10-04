package com.example.demo;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface NoteRepository extends JpaRepository<Note, Long> {
    @Query(value = "SELECT * FROM note ORDER BY id LIMIT :limit OFFSET :offset", nativeQuery = true)
    List<Note> page(@Param("limit") int limit, @Param("offset") int offset);
}
