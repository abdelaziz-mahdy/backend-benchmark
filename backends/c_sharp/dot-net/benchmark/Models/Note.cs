using System.ComponentModel.DataAnnotations;

namespace Models
{
    public class Note
    {
        public int Id { get; set; }
        public string? Title { get; set; } // Nullable
        public string? Content { get; set; } // Nullable
    }

}
