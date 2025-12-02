using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Stagex.Api.Data;
using Stagex.Api.Models;

namespace Stagex.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class TicketScanController : ControllerBase
    {
        private readonly AppDbContext _dbContext;

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
            if (string.IsNullOrWhiteSpace(code))
            {
                return BadRequest(new
                {
                    code = "BARCODE",
                    codevalue = "No ticket code provided in payload."
                });
            }

            if (!long.TryParse(code, out var numericCode))
            {
                return BadRequest(new
                {
                    code = "BARCODE",
                    codevalue = $"Mã vé không hợp lệ: {code}"
                });
            }

            var ticket = await _dbContext.Tickets.FirstOrDefaultAsync(t => t.TicketCode == numericCode);
            if (ticket == null)
            {
                return NotFound(new
                {
                    code = "BARCODE",
                    codevalue = $"Ticket with code {code} not found."
                });
            }

            // Xét trạng thái hiện tại và cập nhật nếu hợp lệ
            switch (ticket.Status)
            {
                case "Đang chờ":
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
                    // Đánh dấu vé là đã sử dụng và ghi lại thời gian cập nhật. Điều này đảm bảo
                    // cột updated_at phản ánh thời điểm vé được quét.
                    ticket.Status = "Đã sử dụng";
                    ticket.UpdatedAt = DateTime.Now;
                    await _dbContext.SaveChangesAsync();
                    // Trả về một thông báo bao gồm mã vé đã quét để
                    // ứng dụng máy tính có thể hiển thị xác nhận với người dùng
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