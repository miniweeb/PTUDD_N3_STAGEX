using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using StageX_DesktopApp.Data;
using StageX_DesktopApp.Models;
using StageX_DesktopApp.Services;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.ObjectModel;
using System.Threading.Tasks;
using System.Windows.Threading;

namespace StageX_DesktopApp.ViewModels
{
    // ViewModel xử lý toàn bộ luồng "Quét vé"
    public partial class TicketScanViewModel : ObservableObject
    {
        private readonly TicketScanService _scanService;

        // Mã vé nhập từ TextBox (binding 2 chiều)
        [ObservableProperty]
        private string ticketCode = string.Empty;

        // Danh sách lịch sử quét để hiển thị ra UI
        [ObservableProperty]
        private ObservableCollection<ScanHistoryItem> scanHistory = new();

        // Danh sách vé đã được soát – load từ DB
        [ObservableProperty]
        private ObservableCollection<Ticket> usedTickets = new();

        // Timer tự động làm mới danh sách vé đã soát
        private readonly DispatcherTimer _refreshTimer;

        public TicketScanViewModel()
        {
            // Khởi tạo service (API endpoint)
            _scanService = new TicketScanService("http://localhost:5000/");

            // Tải danh sách vé đã quét khi mở màn hình
            _ = LoadUsedTicketsAsync();

            // Tự động refresh mỗi 5 giây
            _refreshTimer = new DispatcherTimer
            {
                Interval = TimeSpan.FromSeconds(5)
            };
            _refreshTimer.Tick += async (_, __) => await LoadUsedTicketsAsync();
            _refreshTimer.Start();
        }

        // Tải tất cả vé có trạng thái "Đã sử dụng" từ DB
        private async Task LoadUsedTicketsAsync()
        {
            using var context = new AppDbContext();

            List<Ticket> tickets;
            try
            {
                tickets = await context.Tickets
                    .Where(t => t.Status == "Đã sử dụng")
                    .OrderByDescending(t => t.UpdatedAt)
                    .ToListAsync();
            }
            catch
            {
                // Không làm gì nếu lỗi DB
                return;
            }

            UsedTickets.Clear();
            foreach (var t in tickets)
            {
                UsedTickets.Add(t);
            }
        }

        // Command khi người dùng nhấn nút "Quét"
        [RelayCommand]
        private async Task ScanAsync()
        {
            if (string.IsNullOrWhiteSpace(TicketCode))
                return;

            string trimmedCode = TicketCode.Trim();
            string message;

            // Validate mã vé phải là 13 chữ số
            bool isNumeric = long.TryParse(trimmedCode, out long numericCode);
            if (!isNumeric || trimmedCode.Length != 13 ||
                numericCode < 1000000000000L || numericCode > 9999999999999L)
            {
                message = $"Mã vé không hợp lệ: {trimmedCode}. Mã vé phải gồm 13 chữ số.";

                ScanHistory.Add(new ScanHistoryItem
                {
                    Timestamp = DateTime.Now,
                    TicketCode = trimmedCode,
                    Message = message
                });

                TicketCode = string.Empty;
                return;
            }

            // Thử quét qua API → Nếu lỗi thì fallback sang DB local
            try
            {
                message = await _scanService.ScanTicketAsync(trimmedCode);
            }
            catch
            {
                message = await ScanTicketLocallyAsync(trimmedCode);
            }

            // Ghi vào lịch sử quét
            ScanHistory.Add(new ScanHistoryItem
            {
                Timestamp = DateTime.Now,
                TicketCode = trimmedCode,
                Message = message
            });

            TicketCode = string.Empty;

            // Làm mới danh sách vé đã sử dụng
            await LoadUsedTicketsAsync();
        }

        // Hàm fallback: quét vé trực tiếp bằng DB khi API không hoạt động
        private static async Task<string> ScanTicketLocallyAsync(string trimmedCode)
        {
            using var context = new AppDbContext();

            long numericCode = long.Parse(trimmedCode);
            var ticket = await context.Tickets.FirstOrDefaultAsync(t => t.TicketCode == numericCode);

            if (ticket == null)
                return $"Không tìm thấy vé có mã {trimmedCode}.";

            switch (ticket.Status)
            {
                case "Đang chờ":
                    return "Vé chưa được xác thực. Vui lòng xác nhận thanh toán trước.";

                case "Đã sử dụng":
                    return "Vé này đã được sử dụng.";

                case "Đã hủy":
                    return "Vé này đã bị hủy và không còn giá trị.";

                case "Hợp lệ":
                case "Hơp lệ": // chấp nhận lỗi chính tả từ DB
                    ticket.Status = "Đã sử dụng";
                    ticket.UpdatedAt = DateTime.Now;
                    await context.SaveChangesAsync();
                    return $"Vé hợp lệ. Đã cập nhật trạng thái vé {trimmedCode}.";

                default:
                    return $"Trạng thái vé không hợp lệ: {ticket.Status}.";
            }
        }
    }
}