using System;

namespace StageX_DesktopApp.Models
{
    /// Model hỗ trợ hiển thị danh sách Top 5 vở diễn bán chạy trên Dashboard.
    public class TopShowModel
    {
        // Số thứ tự (STT: 1, 2, 3...)
        public int Index { get; set; }

        // Tên vở diễn (Khớp với tên cột trả về từ Stored Procedure hoặc mapping cũ)
        public string show_name { get; set; } = string.Empty;

        // Số lượng vé đã bán
        public long sold_tickets { get; set; }
    }
}