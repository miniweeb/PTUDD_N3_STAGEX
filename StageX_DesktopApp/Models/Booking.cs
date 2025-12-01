using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace StageX_DesktopApp.Models
{
    [Table("bookings")]
    public class Booking
    {
        [Key]
        [Column("booking_id")]
        public int BookingId { get; set; }

        [Column("user_id")]
        public int? UserId { get; set; }

        [Column("performance_id")]
        public int PerformanceId { get; set; }

        [Column("total_amount")]
        public decimal TotalAmount { get; set; }

        [Column("booking_status")]
        public string Status { get; set; }

        [Column("created_at")]
        public DateTime CreatedAt { get; set; }
        [Column("created_by")]
        public int? CreatedBy { get; set; }

        // Navigation đến user người tạo:
        [ForeignKey("CreatedBy")]
        public virtual User CreatedByUser { get; set; }

        // Navigation Properties
        public virtual User User { get; set; }
        public virtual Performance Performance { get; set; }
        public virtual ICollection<Ticket> Tickets { get; set; }
        public virtual ICollection<Payment> Payments { get; set; }
    }
}