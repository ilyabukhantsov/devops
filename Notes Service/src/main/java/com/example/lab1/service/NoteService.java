package com.example.lab1.service;

import com.example.lab1.model.Note;
import java.util.List;
import java.util.Optional;

public interface NoteService {
    List<Note> findAll();
    Optional<Note> findById(Long id);
    Note save(Note note);
    void deleteById(Long id);
}