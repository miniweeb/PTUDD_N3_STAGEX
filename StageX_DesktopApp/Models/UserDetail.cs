using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
namespace StageX_DesktopApp.Models
{
    // Ánh xạ class này với bảng 'user_detail' trong CSDL
    [Table("user_detail")]
    public class UserDetail
    {
        [Key]
        [Column("user_id")]
        public int UserId { get; set; }
        [Column("full_name")]
        public string FullName { get; set; }
        [Column("date_of_birth")]
        public DateTime DateOfBirth { get; set; }
        [Column("address")]
        public string? Address { get; set; }
        [Column("phone")]
        public string? Phone { get; set; }
        // (Quan hệ 1-1: Mỗi User chỉ có 1 UserDetail)
        public virtual User User { get; set; }
    }
}