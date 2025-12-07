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
    public partial class BookingManagementViewModel : ObservableObject
    {
        private readonly DatabaseService _dbService;

        // Danh sách gốc (Cache): Lưu toàn bộ dữ liệu lấy từ DB. 
        // Khi lọc, ta sẽ query trên list này để tránh gọi lại DB nhiều lần.
        private List<BookingDisplayItem> _allBookings;

        // Danh sách hiển thị: DataGrid sẽ binding vào biến này.
        [ObservableProperty]
        private ObservableCollection<BookingDisplayItem> _bookings;

        // --- CÁC BIẾN BINDING VỚI BỘ LỌC UI ---

        // Từ khóa tìm kiếm (Mã đơn, Tên khách...)
        [ObservableProperty]
        private string _searchKeyword;

        // Index của ComboBox trạng thái (0: Tất cả, 1: Đang xử lý...)
        [ObservableProperty]
        private int _statusIndex = 0;

        // Ngày được chọn (Nullable - có thể null nếu chọn "Tất cả ngày")
        [ObservableProperty]
        private DateTime? _selectedDate;

        // --- SỰ KIỆN (EVENTS) ---

        // Event báo hiệu cho View biết cần in vé.
        // ViewModel không nên trực tiếp thao tác UI/Printer, nên dùng event để View xử lý.
        public event Action<BookingDisplayItem> RequestPrintTicket;

        public BookingManagementViewModel()
        {
            _dbService = new DatabaseService();

            // Gọi lệnh tải dữ liệu ngay khi ViewModel được tạo
            LoadDataCommand.Execute(null);
        }

        [RelayCommand]
        private async Task LoadData()
        {
            try
            {
                // 1. Gọi Service lấy danh sách Booking (Entity) từ CSDL
                // Hàm này đã bao gồm các lệnh .Include() để lấy dữ liệu liên kết (User, Tickets, Seats...)
                var rawList = await _dbService.GetBookingsAsync();

                // 2. Chuyển đổi (Mapping) từ Entity sang DTO (Data Transfer Object)
                // Sử dụng Constructor của BookingDisplayItem để tự xử lý logic map dữ liệu.
                // Cách này giúp code ViewModel gọn gàng, dễ đọc.
                _allBookings = rawList.Select(b => new BookingDisplayItem(b)).ToList();

                // 3. Gọi hàm Filter để áp dụng các bộ lọc hiện tại (nếu có) lên danh sách vừa tải
                Filter();
            }
            catch (Exception ex)
            {
                MessageBox.Show("Lỗi tải dữ liệu: " + ex.Message);
            }
        }
        
        // Command: Lọc dữ liệu (Được gọi khi người dùng gõ phím, chọn ngày, chọn trạng thái).
        [RelayCommand]
        private void Filter()
        {
            // Nếu chưa có dữ liệu gốc thì thoát
            if (_allBookings == null) return;

            // Bắt đầu từ danh sách gốc
            var query = _allBookings.AsEnumerable();

            // 1. Lọc theo từ khóa (SearchKeyword)
            // Tìm kiếm trên nhiều trường: Mã đơn, Tên khách, Người lập, Tên vở diễn
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

            // 2. Lọc theo Trạng thái (Dựa vào index ComboBox)
            string statusFilter = StatusIndex switch
            {
                1 => "Đang xử lý",
                2 => "Đã hoàn thành",
                3 => "Đã hủy",
                _ => "" // Index 0 hoặc khác: Không lọc
            };

            if (!string.IsNullOrEmpty(statusFilter))
            {
                // Xử lý đặc biệt cho trạng thái "Đã hoàn thành" (Gộp nhiều trạng thái con từ DB)
                if (statusFilter == "Đã hoàn thành")
                    query = query.Where(x => x.Status == "Đã hoàn thành" || x.Status == "Thành công" || x.Status == "Đã thanh toán POS");
                else
                    query = query.Where(x => x.Status == statusFilter);
            }

            // 3. Lọc theo Ngày tạo (Nếu người dùng đã chọn ngày)
            if (SelectedDate.HasValue)
            {
                // Chỉ so sánh phần Ngày (Date), bỏ qua phần Giờ
                query = query.Where(x => x.CreatedAt.Date == SelectedDate.Value.Date);
            }

            // Cập nhật kết quả lọc vào biến Bookings để UI tự động hiển thị lại
            Bookings = new ObservableCollection<BookingDisplayItem>(query);
        }

        // Command: Làm mới (Refresh).
        [RelayCommand]
        private async Task Refresh()
        {
            // Reset các biến điều khiển trên giao diện về mặc định
            SearchKeyword = "";
            StatusIndex = 0;      // Về mục "-- Tất cả --"
            SelectedDate = null;  // Xóa chọn ngày

            // Tải lại dữ liệu
            await LoadData();
        }

        // Command: In vé.
        [RelayCommand]
        private void PrintTicket(BookingDisplayItem item)
        {
            // Kích hoạt sự kiện để View (Code-behind) thực hiện logic tạo PDF và in
            if (item != null) RequestPrintTicket?.Invoke(item);
        }
    }
}