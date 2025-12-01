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
    public partial class TicketScanViewModel : ObservableObject
    {
        private readonly TicketScanService _scanService;

        [ObservableProperty]
        private string ticketCode = string.Empty;

        [ObservableProperty]
        private ObservableCollection<Models.ScanHistoryItem> scanHistory = new();

        /// <summary>
        /// Tập hợp các vé đã được quét và đánh dấu là đã sử dụng. Chế độ xem
        /// liên kết với tập hợp này để hiển thị danh sách các vé đã sử dụng. Nó được
        /// làm mới định kỳ và sau mỗi lần quét thành công để phản ánh
        /// trạng thái hiện tại của cơ sở dữ liệu.
        /// </summary>
        [ObservableProperty]
        private ObservableCollection<Ticket> usedTickets = new();

        private readonly DispatcherTimer _refreshTimer;

        public TicketScanViewModel()
        {
            _scanService = new TicketScanService("http://localhost:5000/");

            // Initial load of used tickets
            _ = LoadUsedTicketsAsync();

            // Thiết lập bộ hẹn giờ để làm mới danh sách vé đã sử dụng theo định kỳ 5s
            _refreshTimer = new DispatcherTimer
            {
                Interval = TimeSpan.FromSeconds(5)
            };
            _refreshTimer.Tick += async (_, __) => await LoadUsedTicketsAsync();
            _refreshTimer.Start();
        }

        /// <summary>
        /// Lấy danh sách vé đã sử dụng từ cơ sở dữ liệu và cập nhật list
        /// <xem cref="UsedTickets"/>. Chỉ trả về những vé có trạng thái
        /// "Đã sử dụng" và được sắp xếp theo thời gian
        /// cập nhật lần cuối (giảm dần).
        /// </summary>
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
                // Không log, không throw — nếu lỗi DB thì giữ nguyên danh sách cũ
                return;
            }

            // Chỉ cập nhật UI nếu query thành công
            UsedTickets.Clear();
            foreach (var t in tickets)
            {
                UsedTickets.Add(t);
            }
        }

        [RelayCommand]
        private async Task ScanAsync()
        {
            if (string.IsNullOrWhiteSpace(TicketCode))
            {
                return;
            }

            string trimmedCode = TicketCode.Trim();
            string message;

            // Xác thực mã có chính xác 13 chữ số và nằm trong phạm vi cho phép.
            bool isNumeric = long.TryParse(trimmedCode, out long numericCode);
            if (!isNumeric || trimmedCode.Length != 13 || numericCode < 1000000000000L || numericCode > 9999999999999L)
            {
                message = $"Mã vé không hợp lệ: {trimmedCode}. Mã vé phải gồm 13 chữ số";
                // Ghi lại nỗ lực quét không hợp lệ trong lịch sử
                ScanHistory.Add(new Models.ScanHistoryItem
                {
                    Timestamp = DateTime.Now,
                    TicketCode = trimmedCode,
                    Message = message
                });
                TicketCode = string.Empty;
                return;
            }

            try
            {
                message = await _scanService.ScanTicketAsync(trimmedCode);
            }
            catch (Exception ex)
            {
                message = $"Lỗi: {ex.Message}";
            }

            // Thêm kết quả vào lịch sử quét để lưu giữ hồ sơ.
            ScanHistory.Add(new Models.ScanHistoryItem
            {
                Timestamp = DateTime.Now,
                TicketCode = trimmedCode,
                Message = message
            });

            // Xóa đầu vào cho lần quét tiếp theo
            TicketCode = string.Empty;

            // Làm mới danh sách vé đã sử dụng sau khi quét, vì khi quét thành công
            // có thể trạng thái của vé đã được cập nhật trong cơ sở dữ liệu.
            await LoadUsedTicketsAsync();
        }
    }
}