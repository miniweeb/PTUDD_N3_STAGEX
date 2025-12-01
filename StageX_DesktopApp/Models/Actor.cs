using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace StageX_DesktopApp.Models
{
    [Table("actors")] // Ánh xạ bảng 'actors'
    public class Actor
    {
        [Key]
        [Column("actor_id")]
        public int ActorId { get; set; }

        [Column("full_name")]
        public string FullName { get; set; }
        [Column("date_of_birth")] public DateTime? DateOfBirth { get; set; }
        [Column("gender")] public string? Gender { get; set; }

        [Column("nick_name")]
        public string? NickName { get; set; }

        [Column("email")]
        public string? Email { get; set; }

        [Column("phone")]
        public string? Phone { get; set; }

        [Column("status")]
        public string Status { get; set; } // 'Hoạt động', 'Ngừng hoạt động'

        // Mối quan hệ Nhiều-Nhiều với Show (Vở diễn)
        public virtual ICollection<Show> Shows { get; set; } = new List<Show>();
    }
}