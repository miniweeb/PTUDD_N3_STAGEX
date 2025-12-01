using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Stagex.Api.Models
{
    [Table("tickets")]
    public class Ticket
    {
        [Key]
        [Column("ticket_id")]
        public int TicketId { get; set; }

        [Column("booking_id")]
        public int BookingId { get; set; }

        [Column("seat_id")]
        public int SeatId { get; set; }

        [Column("ticket_code")]
        public long TicketCode { get; set; }

        [Column("status")]
        public string Status { get; set; } = string.Empty;

        // Dấu thời gian khi vé được tạo trong cơ sở dữ liệu. Dấu thời gian này sẽ ánh xạ
        // trực tiếp đến cột "created_at" trong bảng vé.
        [Column("created_at")]
        public DateTime? CreatedAt { get; set; }

        // Dấu thời gian khi vé được cập nhật lần cuối. Dấu thời gian này được
        // thiết lập bất cứ khi nào trạng thái vé thay đổi 
        [Column("updated_at")]
        public DateTime? UpdatedAt { get; set; }
    }
}