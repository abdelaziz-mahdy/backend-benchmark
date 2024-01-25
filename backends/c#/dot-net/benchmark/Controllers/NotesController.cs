using Data;
using Microsoft.AspNetCore.Mvc;
using Models;
using Microsoft.EntityFrameworkCore;

namespace csharp_crud_api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class NotesController : ControllerBase
{
    private readonly NoteContext _context;

    public NotesController(NoteContext context)
    {
        _context = context;
    }

// GET: api/notes
[HttpGet]
public async Task<ActionResult<IEnumerable<Note>>> GetNotes()
{
    return await _context.Notes.Take(100).ToListAsync();
}

    // GET: api/notes/5
    [HttpGet("{id}")]
    public async Task<ActionResult<Note>> GetNote(int id)
    {
        var note = await _context.Notes.FindAsync(id);

        if (note == null)
        {
            return NotFound();
        }

        return note;
    }

    // POST api/notes
    [HttpPost]
    public async Task<ActionResult<Note>> PostNote(Note note)
    {
        _context.Notes.Add(note);
        await _context.SaveChangesAsync();

        return CreatedAtAction(nameof(GetNote), new { id = note.Id }, note);
    }

    // PUT api/notes/5
    [HttpPut("{id}")]
    public async Task<IActionResult> PutNote(int id, Note note)
    {
        if (id != note.Id)
        {
            return BadRequest();
        }

        _context.Entry(note).State = EntityState.Modified;
        await _context.SaveChangesAsync();

        return NoContent();
    }

    // DELETE api/notes/5
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteNote(int id)
    {
        var note = await _context.Notes.FindAsync(id);

        if (note == null)
        {
            return NotFound();
        }

        _context.Notes.Remove(note);
        await _context.SaveChangesAsync();

        return NoContent();
    }

    // Dummy endpoint to test the database connection
    [HttpGet("no_db_endpoint")]
    public string no_db_endpoint()
    {
        return "No db endpoint";
    }
    // Dummy endpoint to test the database connection
    [HttpGet("no_db_endpoint2")]
    public string no_db_endpoint2()
    {
        return "No db endpoint2";
    }
}
