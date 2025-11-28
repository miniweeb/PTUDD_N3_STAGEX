using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace StageX_DesktopApp.Models
{
    [Table("shows")]
    public class Show
    {
        [Key]
        [Column("show_id")]
        public int ShowId { get; set; }

        [Column("title")]
        public string Title { get; set; } // Tiêu đề bắt buộc (NOT NULL trong DB) nên giữ nguyên

        [Column("description")]
        public string? Description { get; set; } // <--- Thêm dấu ? (Cho phép Null)

        [Column("duration_minutes")]
        public int DurationMinutes { get; set; }

        [Column("director")]
        public string? Director { get; set; } // <--- Thêm dấu ? (Cho phép Null)

        [Column("poster_image_url")]
        public string? PosterImageUrl { get; set; } // <--- Thêm dấu ? (Cho phép Null)

        [Column("status")]
        public string Status { get; set; }

        [NotMapped]
        public string GenresDisplay { get; set; }

        [NotMapped]
        public string ActorsDisplay { get; set; }

        // Đảm bảo bạn vẫn giữ phần khởi tạo danh sách này từ bước sửa trước
        public virtual ICollection<Genre> Genres { get; set; } = new List<Genre>();
        public virtual ICollection<Actor> Actors { get; set; } = new List<Actor>();
    }
}