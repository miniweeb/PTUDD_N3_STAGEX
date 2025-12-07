using System;
using System.Collections.Generic;
using System.Linq; // Cần thêm Linq để xử lý danh sách vé

namespace StageX_DesktopApp.Models
{
    public class BookingDisplayItem
    {
        public int BookingId { get; set; }
        public string CustomerName { get; set; }
        public string CreatorName { get; set; }
        public string ShowTitle { get; set; }
        public string TheaterName { get; set; }
        public DateTime PerformanceTime { get; set; }
        public decimal TotalAmount { get; set; }
        public string Status { get; set; }
        public string SeatList { get; set; }
        public DateTime CreatedAt { get; set; }
        public List<TicketPrintInfo> TicketDetails { get; set; } = new();

        // --- CONSTRUCTOR MẶC ĐỊNH (Cần thiết cho một số trường hợp) ---
        public BookingDisplayItem() { }

        // --- CONSTRUCTOR MAPPING (Logic chuyển đổi nằm ở đây) ---
        public BookingDisplayItem(Booking b)
        {
            BookingId = b.BookingId;
            TotalAmount = b.TotalAmount;
            Status = b.Status;
            CreatedAt = b.CreatedAt;

            // Xử lý thông tin Khách hàng
            if (b.User != null)
            {
                CustomerName = b.User.UserDetail?.FullName ?? b.User.Email;
            }
            else
            {
                CustomerName = ""; // Khách vãng lai không có info
            }

            // Xử lý thông tin Người lập đơn
            if (b.User != null)
            {
                CreatorName = "Online";
            }
            else if (b.CreatedByUser != null)
            {
                CreatorName = b.CreatedByUser.UserDetail?.FullName ?? b.CreatedByUser.AccountName;
            }
            else
            {
                CreatorName = "—";
            }

            // Xử lý thông tin Vở diễn & Rạp
            ShowTitle = b.Performance?.Show?.Title ?? "";
            TheaterName = b.Performance?.Theater?.Name ?? "";

            // Xử lý Thời gian diễn
            var pDate = b.Performance?.PerformanceDate ?? DateTime.MinValue;
            var pTime = b.Performance?.StartTime ?? TimeSpan.Zero;
            PerformanceTime = pDate.Add(pTime);

            // Xử lý Danh sách ghế (SeatList string)
            if (b.Tickets != null)
            {
                var seats = b.Tickets.Select(t => $"{t.Seat?.RowChar}{t.Seat?.SeatNumber}");
                SeatList = string.Join(", ", seats);

                // Xử lý Chi tiết vé để in (TicketDetails)
                TicketDetails = b.Tickets.Select(t => new TicketPrintInfo
                {
                    SeatLabel = $"{t.Seat?.RowChar}{t.Seat?.SeatNumber}",
                    // Giá vé = Giá suất + Giá hạng ghế
                    Price = (b.Performance?.Price ?? 0) + (t.Seat?.SeatCategory?.BasePrice ?? 0),
                    TicketCode = t.TicketCode.ToString()
                }).ToList();
            }
        }
    }
}