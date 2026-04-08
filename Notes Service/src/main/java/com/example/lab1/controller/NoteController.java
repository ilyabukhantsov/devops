package com.example.lab1.controller;

import com.example.lab1.model.Note;
import com.example.lab1.service.NoteService;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/notes")
public class NoteController {
    
    private final NoteService noteService;

    public NoteController(NoteService noteService) {
        this.noteService = noteService;
    }

    @GetMapping(produces = {MediaType.APPLICATION_JSON_VALUE, MediaType.TEXT_HTML_VALUE})
    public ResponseEntity<?> getAll(@RequestHeader(value = "Accept", defaultValue = "application/json") String accept) {
        List<Note> notes = noteService.findAll();

        if (accept.contains("text/html")) {
            StringBuilder html = new StringBuilder("<html><head><meta charset='UTF-8'><title>Notes List</title></head><body>");
            html.append("<h1>Notes List (Option 3858)</h1>");
            html.append("<table border='1' style='width:100%; border-collapse: collapse;'>");
            html.append("<tr style='background-color: #f2f2f2;'><th>ID</th><th>Title</th><th>Action</th></tr>");
            
            for (Note n : notes) {
                html.append("<tr>")
                    .append("<td>").append(n.getId()).append("</td>")
                    .append("<td>").append(n.getTitle()).append("</td>")
                    .append("<td><a href='/notes/").append(n.getId()).append("'>View Detail</a></td>")
                    .append("</tr>");
            }
            
            html.append("</table>");
            html.append("<br><p><i>Request processed as text/html</i></p>");
            html.append("</body></html>");
            return ResponseEntity.ok().contentType(MediaType.TEXT_HTML).body(html.toString());
        }

        return ResponseEntity.ok(notes);
    }

    @PostMapping(consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<Note> create(@RequestBody Note note) {
        Note savedNote = noteService.save(note);
        return new ResponseEntity<>(savedNote, HttpStatus.CREATED);
    }

    @GetMapping(value = "/{id}", produces = {MediaType.APPLICATION_JSON_VALUE, MediaType.TEXT_HTML_VALUE})
    public ResponseEntity<?> getById(@PathVariable Long id, @RequestHeader(value = "Accept", defaultValue = "application/json") String accept) {
        return noteService.findById(id)
                .map(note -> {
                    if (accept.contains("text/html")) {
                        String html = "<html><head><meta charset='UTF-8'><title>View Note</title></head><body>" +
                                "<h1>Viewing Note #" + note.getId() + "</h1>" +
                                "<p><b>Title:</b> " + note.getTitle() + "</p>" +
                                "<p><b>Created At:</b> " + note.getCreatedAt() + "</p>" +
                                "<hr>" +
                                "<div style='background: #eee; padding: 10px; border: 1px solid #ccc;'>" + note.getContent() + "</div>" +
                                "<br><a href='/notes'>Back to List</a>" +
                                "</body></html>";
                        return ResponseEntity.ok().contentType(MediaType.TEXT_HTML).body(html);
                    }
                    return ResponseEntity.ok(note);
                })
                .orElse(ResponseEntity.status(HttpStatus.NOT_FOUND).build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        noteService.deleteById(id);
        return ResponseEntity.noContent().build();
    }
}