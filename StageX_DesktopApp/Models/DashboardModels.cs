using System;

namespace StageX_DesktopApp.Models
{
    /// Các lớp dữ liệu phục vụ hiển thị bảng điều khiển.
    /// Các thuộc tính khớp với tên cột trả về từ thủ tục lưu trữ trong cơ sở dữ liệu.
    public class DashboardSummary
    {
        public decimal total_revenue { get; set; }
        public int total_bookings { get; set; }
        public int total_shows { get; set; }
        public int total_genres { get; set; }
    }

    public class RevenueMonthly
    {
        public string month { get; set; } = string.Empty;
        public decimal total_revenue { get; set; }
    }

    public class TicketSold
    {
        public string period { get; set; } = string.Empty;
        public long sold_tickets { get; set; }
    }

    public class TopShow
    {
        public string show_name { get; set; } = string.Empty;
        public long sold_tickets { get; set; }
    }
    public class ChartDataModel
    {
        public string period { get; set; }
        public long sold_tickets { get; set; }
        public long unsold_tickets { get; set; } 
    }

}