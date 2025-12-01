using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace StageX_DesktopApp.Models
{
    [Table("shows")] // Ánh xạ tới bảng 'shows'
    public class Show
    {
        [Key]
        [Column("show_id")]
        public int ShowId { get; set; }

        [Column("title")]
        public string Title { get; set; }

        [Column("description")]
        public string Description { get; set; }

        [Column("duration_minutes")]
        public int DurationMinutes { get; set; }

        [Column("director")]
        public string Director { get; set; }

        [Column("poster_image_url")]
        public string PosterImageUrl { get; set; }

        [Column("status")]
        public string Status { get; set; }

        // Ghi chú: Dùng để hiển thị (không có trong CSDL)
        [NotMapped]
        public string GenresDisplay { get; set; }

        [NotMapped]
        public string ActorsDisplay { get; set; }

        // Ghi chú: Mối quan hệ Nhiều-Nhiều
        public virtual ICollection<Actor> Actors { get; set; } = new List<Actor>();
        public virtual ICollection<Genre> Genres { get; set; } = new List<Genre>();
    }
}