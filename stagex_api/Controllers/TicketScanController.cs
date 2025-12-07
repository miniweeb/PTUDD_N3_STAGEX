using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Stagex.Api.Data;
using Stagex.Api.Models;

namespace Stagex.Api.Controllers
{
    // Định nghĩa đây là một API Controller
    // Route mặc định sẽ là: api/TicketScan
    [ApiController]
    [Route("api/[controller]")]
    public class TicketScanController : ControllerBase
    {
        private readonly AppDbContext _dbContext;
        // Constructor: Inject DbContext để truy cập cơ sở dữ liệu
        public TicketScanController(AppDbContext dbContext)
        {
            _dbContext = dbContext;
        }
        /// Hàm này nhận vào một request chứa JSON mã vé,
        /// Trả về một kết quả(thường là object hoặc JSON) nói rõ vé đó accepted or rejected.</returns>
        [HttpPost]
        public async Task<IActionResult> Post([FromBody] ScanRequest request)
        {
            string? code = null;
            // --- BƯỚC 1: LINH HOẠT LẤY MÃ VÉ TỪ NHIỀU TRƯỜNG KHÁC NHAU ---
            if (!string.IsNullOrWhiteSpace(request.code))
            {
                code = request.code;
            }
            else if (!string.IsNullOrWhiteSpace(request.Barcode))
            {
                code = request.Barcode;
            }
            else if (!string.IsNullOrWhiteSpace(request.TicketCode))
            {
                code = request.TicketCode;
            }
            else if (!string.IsNullOrWhiteSpace(request.ticket_code))
            {
                code = request.ticket_code;
            }
            // Nếu sau khi kiểm tra hết mà vẫn không có mã nào => Báo lỗi thiếu dữ liệu
            if (string.IsNullOrWhiteSpace(code))
            {
                return BadRequest(new
                {
                    code = "BARCODE",
                    codevalue = "No ticket code provided in payload."
                });
            }
            // --- BƯỚC 2: KIỂM TRA ĐỊNH DẠNG SỐ ---
            // Mã vé trong Database là kiểu số (bigint/long).
            // Nếu chuỗi gửi lên chứa chữ cái => Báo lỗi định dạng ngay.
            if (!long.TryParse(code, out var numericCode))
            {
                return BadRequest(new
                {
                    code = "BARCODE",
                    codevalue = $"Mã vé không hợp lệ: {code}"
                });
            }
            // --- BƯỚC 3: TRUY VẤN CƠ SỞ DỮ LIỆU ---
            // Tìm vé đầu tiên trong bảng Tickets khớp với mã vé (TicketCode).
            // Sử dụng FirstOrDefaultAsync để không gây lỗi nếu không tìm thấy (trả về null).
            var ticket = await _dbContext.Tickets.FirstOrDefaultAsync(t => t.TicketCode == numericCode);
            // Nếu vé không tồn tại trong hệ thống => Báo lỗi 404 Not Found
            if (ticket == null)
            {
                return NotFound(new
                {
                    code = "BARCODE",
                    codevalue = $"Ticket with code {code} not found."
                });
            }

            // --- BƯỚC 4: KIỂM TRA TRẠNG THÁI VÉ (LOGIC NGHIỆP VỤ CHÍNH) ---
            switch (ticket.Status)
            {
                case "Đang chờ":
                    // Vé đã được giữ chỗ nhưng chưa thanh toán xong
                    return BadRequest(new
                    {
                        code = "BARCODE",
                        codevalue = "Vé chưa được xác thực. Vui lòng xác nhận thanh toán trước."
                    });
                case "Đã sử dụng":
                    return BadRequest(new
                    {
                        code = "BARCODE",
                        codevalue = "Vé này đã được sử dụng."
                    });
                case "Đã hủy":
                    return BadRequest(new
                    {
                        code = "BARCODE",
                        codevalue = "Vé này đã bị hủy và không còn giá trị."
                    });
                case "Hợp lệ":
                    // --- ĐÂY LÀ TRƯỜNG HỢP THÀNH CÔNG DUY NHẤT ---
                    // 1. Cập nhật trạng thái sang "Đã sử dụng" để ngăn chặn việc dùng lại vé này lần 2.
                    ticket.Status = "Đã sử dụng";

                    // 2. Ghi lại thời gian quét vé thực tế. 
                    // Điều này quan trọng để báo cáo xem khách vào rạp lúc mấy giờ.
                    ticket.UpdatedAt = DateTime.Now;

                    // 3. Lưu thay đổi xuống Database
                    await _dbContext.SaveChangesAsync();

                    // 4. Trả về thông báo thành công cho Client (Desktop App)
                    return Ok(new
                    {
                        code = "BARCODE",
                        codevalue = $"Vé hợp lệ. Đã cập nhật trạng thái vé {code}."
                    });
                default:
                    // Trạng thái không xác định – coi như không hợp lệ
                    return BadRequest(new
                    {
                        code = "BARCODE",
                        codevalue = $"Trạng thái vé không hợp lệ: {ticket.Status}."
                    });
            }
        }
    }
}