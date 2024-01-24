// backends/c#/dot-net/Data/NoteContext.cs
using Microsoft.EntityFrameworkCore;
using Models;

namespace Data
{
    public class NoteContext : DbContext
    {
        public NoteContext(DbContextOptions<NoteContext> options) : base(options)
        {
        }

        public DbSet<Note> Notes { get; set; }
    }
}