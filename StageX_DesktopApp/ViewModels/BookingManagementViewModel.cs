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
    // Class chứa thông tin chi tiết của từng tấm vé để phục vụ việc IN VÉ ra PDF
    // DTO (Data Transfer Object) này giúp gom nhóm dữ liệu cần thiết từ nhiều nguồn (Ticket, Seat, Performance...)
    public class TicketPrintInfo
    {
        public string SeatLabel { get; set; }
        public decimal Price { get; set; }
        public string TicketCode { get; set; }
    }
    // Class đại diện cho một dòng dữ liệu hiển thị trên bảng Đơn hàng (DataGrid)
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
    }
    // ViewModel chính cho màn hình Quản lý Đơn hàng
    public partial class BookingManagementViewModel : ObservableObject
    {
        private readonly DatabaseService _dbService;
        // Danh sách gốc chứa toàn bộ dữ liệu tải từ DB về (dùng để Cache)
        private List<BookingDisplayItem> _allBookings;
        // Danh sách hiển thị trên giao diện (đã qua lọc/tìm kiếm)
        // ObservableCollection giúp giao diện tự cập nhật khi danh sách thay đổi
        [ObservableProperty] private ObservableCollection<BookingDisplayItem> _bookings;
        // --- CÁC BIẾN BỘ LỌC (BINDING VỚI UI) ---
        [ObservableProperty] private string _searchKeyword;
        [ObservableProperty] private int _statusIndex = 0;
        [ObservableProperty] private DateTime? _selectedDate;
        public event Action<BookingDisplayItem> RequestPrintTicket;

        public BookingManagementViewModel()
        {
            _dbService = new DatabaseService();
            LoadDataCommand.Execute(null);
        }

        // Command: Tải dữ liệu từ Database
        [RelayCommand]
        private async Task LoadData()
        {
            try
            {
                // 1. Gọi Service lấy danh sách Booking (kèm chi tiết Ticket, Seat...)
                var rawList = await _dbService.GetBookingsAsync();
                // 2. Chuyển đổi (Map) từ Model gốc (Booking) sang Model hiển thị (BookingDisplayItem)
                // Sử dụng LINQ Select để projection dữ liệu
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

                    // Tính toán chi tiết từng vé để in
                    TicketDetails = b.Tickets.Select(t => new TicketPrintInfo
                    {
                        SeatLabel = $"{t.Seat?.RowChar}{t.Seat?.SeatNumber}",
                        // Công thức: Giá vé = Giá suất diễn + Giá hạng ghế (nếu có)
                        Price = (b.Performance?.Price ?? 0) + (t.Seat?.SeatCategory?.BasePrice ?? 0),
                        TicketCode = t.TicketCode.ToString()
                    }).ToList()

                }).ToList();
                // 3. Gọi hàm Filter để áp dụng các bộ lọc hiện tại (nếu có) lên danh sách vừa tải
                Filter();
            }
            catch (Exception ex)
            {
                MessageBox.Show("Lỗi tải dữ liệu: " + ex.Message);
            }
        }

        // Command: Lọc dữ liệu (được gọi khi gõ text, chọn ngày, chọn trạng thái)
        [RelayCommand]
        private void Filter()
        {
            if (_allBookings == null) return;

            var query = _allBookings.AsEnumerable();
            // 1. Lọc theo từ khóa (Mã đơn hoặc Tên khách)
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
            // 2. Lọc theo Trạng thái (dựa vào index của ComboBox)
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
            // 3. Lọc theo Ngày tạo (nếu người dùng đã chọn ngày)
            if (SelectedDate.HasValue)
            {
                // So sánh phần ngày (Date) bỏ qua phần giờ
                query = query.Where(x => x.CreatedAt.Date == SelectedDate.Value.Date);
            }
            // Cập nhật kết quả lọc ra ObservableCollection để View hiển thị
            Bookings = new ObservableCollection<BookingDisplayItem>(query);
        }
        // Command: Làm mới (Refresh)
        // Xóa sạch bộ lọc và tải lại dữ liệu mới nhất từ Server
        [RelayCommand]
        private async Task Refresh()
        {
            // Xóa sạch các điều kiện lọc trên giao diện
            SearchKeyword = "";
            StatusIndex = 0;      // Về "-- Tất cả --"
            SelectedDate = null;  // Xóa chọn ngày

            await LoadData();
        }

        // Command: In vé
        // Được gọi khi nhấn nút "In vé" trên từng dòng
        [RelayCommand]
        private void PrintTicket(BookingDisplayItem item)
        {
            // Command: In vé
            // Được gọi khi nhấn nút "In vé" trên từng dòng
            if (item != null) RequestPrintTicket?.Invoke(item);
        }
    }
}