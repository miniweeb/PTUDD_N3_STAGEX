using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using StageX_DesktopApp.Models;
using StageX_DesktopApp.Services;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;

namespace StageX_DesktopApp.ViewModels
{
    // Class chứa thông tin chi tiết để IN VÉ
    public class TicketPrintInfo
    {
        public string SeatLabel { get; set; }
        public decimal Price { get; set; }
        public string TicketCode { get; set; }
    }

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

        // [MỚI] Danh sách chi tiết vé để in
        public List<TicketPrintInfo> TicketDetails { get; set; } = new();
    }

    public partial class BookingManagementViewModel : ObservableObject
    {
        private readonly DatabaseService _dbService;
        private List<BookingDisplayItem> _allBookings;

        [ObservableProperty] private ObservableCollection<BookingDisplayItem> _bookings;
        [ObservableProperty] private string _searchKeyword;
        [ObservableProperty] private int _statusIndex = 0;
        [ObservableProperty] private DateTime? _selectedDate;
        public event Action<BookingDisplayItem> RequestPrintTicket;

        public BookingManagementViewModel()
        {
            _dbService = new DatabaseService();
            LoadDataCommand.Execute(null);
        }

        [RelayCommand]
        private async Task LoadData()
        {
            try
            {
                var rawList = await _dbService.GetBookingsAsync();

                _allBookings = rawList.Select(b => new BookingDisplayItem
                {
                    BookingId = b.BookingId,
                    CustomerName = b.User != null ? (b.User.UserDetail?.FullName ?? b.User.Email) : "",
                    CreatorName = b.User != null ? "Online" : (b.CreatedByUser != null ? (b.CreatedByUser.UserDetail?.FullName ?? b.CreatedByUser.AccountName) : "—"),
                    ShowTitle = b.Performance?.Show?.Title ?? "",
                    TheaterName = b.Performance?.Theater?.Name ?? "",
                    PerformanceTime = (b.Performance?.PerformanceDate ?? DateTime.MinValue).Add(b.Performance?.StartTime ?? TimeSpan.Zero),
                    TotalAmount = b.TotalAmount,
                    Status = b.Status,
                    CreatedAt = b.CreatedAt,
                    SeatList = string.Join(", ", b.Tickets.Select(t => $"{t.Seat?.RowChar}{t.Seat?.SeatNumber}")),

                    // [MỚI] Tính toán chi tiết từng vé để in
                    TicketDetails = b.Tickets.Select(t => new TicketPrintInfo
                    {
                        SeatLabel = $"{t.Seat?.RowChar}{t.Seat?.SeatNumber}",
                        // Công thức: Giá vé = Giá suất diễn + Giá hạng ghế (nếu có)
                        Price = (b.Performance?.Price ?? 0) + (t.Seat?.SeatCategory?.BasePrice ?? 0),
                        TicketCode = t.TicketCode.ToString()
                    }).ToList()

                }).ToList();

                Filter();
            }
            catch (Exception ex)
            {
                MessageBox.Show("Lỗi tải dữ liệu: " + ex.Message);
            }
        }

        [RelayCommand]
        private void Filter()
        {
            if (_allBookings == null) return;

            var query = _allBookings.AsEnumerable();

            if (!string.IsNullOrWhiteSpace(SearchKeyword))
            {
                string k = SearchKeyword.ToLower();
                query = query.Where(x =>
            x.BookingId.ToString().Contains(k) ||           // Tìm theo Mã đơn
            x.CustomerName.ToLower().Contains(k) ||         // Tìm theo Tên khách
            (x.CreatorName != null && x.CreatorName.ToLower().Contains(k)) || // Tìm theo Người lập
            (x.ShowTitle != null && x.ShowTitle.ToLower().Contains(k))        // Tìm theo Tên vở diễn
        );
            }

            string statusFilter = StatusIndex switch
            {
                1 => "Đang xử lý",
                2 => "Đã hoàn thành",
                3 => "Đã hủy",
                _ => ""
            };

            if (!string.IsNullOrEmpty(statusFilter))
            {
                if (statusFilter == "Đã hoàn thành")
                    query = query.Where(x => x.Status == "Đã hoàn thành" || x.Status == "Thành công" || x.Status == "Đã thanh toán POS");
                else
                    query = query.Where(x => x.Status == statusFilter);
            }
            if (SelectedDate.HasValue)
            {
                // So sánh phần ngày (Date) bỏ qua phần giờ
                query = query.Where(x => x.CreatedAt.Date == SelectedDate.Value.Date);
            }
            Bookings = new ObservableCollection<BookingDisplayItem>(query);
        }
        [RelayCommand]
        private async Task Refresh()
        {
            // 1. Xóa sạch các điều kiện lọc trên giao diện
            SearchKeyword = "";
            StatusIndex = 0;      // Về "-- Tất cả --"
            SelectedDate = null;  // Xóa chọn ngày

            await LoadData();
        }

        [RelayCommand]
        private void PrintTicket(BookingDisplayItem item)
        {
            if (item != null) RequestPrintTicket?.Invoke(item);
        }
    }
}