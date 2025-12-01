using System;
using System.Net.Http;
using System.Net.Http.Json;
using System.Threading.Tasks;

namespace StageX_DesktopApp.Services
{
    /// <summary>
    /// Dịch vụ package các lệnh gọi đến endpoint quét ticket Stagex.Api.
    /// App demo project có thể gọi dịch vụ này khi mã ticket
    /// cần được xác thực và đánh dấu là đã sử dụng. Dịch vụ sẽ gửi
    /// mã đã quét đến API và trả về thông báo có thể đọc được từ
    /// response. Cấu hình thuộc tính BaseAddress để trỏ đến
    /// API đang chạy cục bộ http://localhost:5000/ khi sử dụng
    /// cổng ASP.NET mặc định).
    /// </summary>
    public class TicketScanService : IDisposable
    {
        private readonly HttpClient _client;
        public TicketScanService(string baseUrl)
        {
            _client = new HttpClient
            {
                BaseAddress = new Uri(baseUrl)
            };
        }

        public async Task<string> ScanTicketAsync(string ticketCode)
        {
            if (string.IsNullOrWhiteSpace(ticketCode))
            {
                throw new ArgumentException("ticketCode is required", nameof(ticketCode));
            }

            var payload = new { code = ticketCode };
            var response = await _client.PostAsJsonAsync("api/TicketScan", payload);

            if (!response.IsSuccessStatusCode)
            {
                // Thử đọc lý do lỗi được API trả về.
                try
                {
                    var error = await response.Content.ReadFromJsonAsync<ApiResponse>();
                    return error?.codevalue ?? $"Lỗi: {response.ReasonPhrase}";
                }
                catch
                {
                    return $"Lỗi: {response.ReasonPhrase}";
                }
            }
            var result = await response.Content.ReadFromJsonAsync<ApiResponse>();
            return result?.codevalue ?? "Không xác định";
        }

        public void Dispose()
        {
            _client.Dispose();
        }

        private class ApiResponse
        {
            public string code { get; set; } = string.Empty;
            public string codevalue { get; set; } = string.Empty;
        }
    }
}