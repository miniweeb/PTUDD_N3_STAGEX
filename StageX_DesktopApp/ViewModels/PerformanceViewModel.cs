using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using PdfSharp.Pdf;
using StageX_DesktopApp.Models;
using StageX_DesktopApp.Services;
using System;
using System.Collections.ObjectModel;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;

namespace StageX_DesktopApp.ViewModels
{
    public partial class PerformanceViewModel : ObservableObject
    {
        private readonly DatabaseService _dbService;

        // Danh sách suất diễn hiển thị trên DataGrid
        [ObservableProperty] private ObservableCollection<Performance> _performances;

        // --- NGUỒN DỮ LIỆU CHO COMBOBOX (Dropdown list) ---
        // Danh sách Vở diễn để chọn
        [ObservableProperty] private ObservableCollection<Show> _showsList;
        [ObservableProperty] private ObservableCollection<Theater> _theatersList;
        [ObservableProperty] private ObservableCollection<Theater> _filterTheaters;

        // --- CÁC BIẾN BỘ LỌC (FILTER) ---
        [ObservableProperty] private string _searchShowName;
        [ObservableProperty] private Theater _selectedFilterTheater;
        [ObservableProperty] private DateTime? _selectedFilterDate;

        // --- CÁC BIẾN NHẬP LIỆU TRÊN FORM ---

        // Biến điều khiển việc cho phép sửa chi tiết (Vở, Rạp, Giờ, Giá).
        // Nếu suất diễn đã có vé bán ra, biến này sẽ = false để khóa form lại.
        [ObservableProperty] private bool _isDetailEditable = true;

        // Nguồn dữ liệu cho combobox chọn Giờ (0-23) và Phút (0, 5, 10...)
        [ObservableProperty] private ObservableCollection<int> _hoursList;
        [ObservableProperty] private ObservableCollection<int> _minutesList;

        // Giờ và Phút được chọn
        [ObservableProperty] private int _selectedHour;
        [ObservableProperty] private int _selectedMinute;

        // Chuỗi hiển thị giờ kết thúc (Tự động tính toán = Giờ bắt đầu + Thời lượng vở)
        [ObservableProperty] private string _endTimeStr = "--:--";

        // ID suất diễn đang thao tác (0: Thêm mới, >0: Sửa)
        [ObservableProperty] private int _perfId;

        // Các đối tượng được chọn trên form
        [ObservableProperty] private Show _selectedShow;
        [ObservableProperty] private Theater _selectedTheater;
        [ObservableProperty] private DateTime _perfDate = DateTime.Now;

        // Giá vé nhập vào (dạng chuỗi để dễ binding textbox)
        [ObservableProperty] private string _priceStr;

        // Danh sách trạng thái ("Đang mở bán", "Đã hủy"...)
        [ObservableProperty] private ObservableCollection<string> _statusOptions;
        [ObservableProperty] private string _selectedStatus;

        // Cho phép sửa trạng thái hay không (Luôn true khi sửa, false khi thêm mới)
        [ObservableProperty] private bool _isStatusEnabled;

        [ObservableProperty] private string _saveBtnContent = "Thêm suất diễn";

        public PerformanceViewModel()
        {
            _dbService = new DatabaseService();
            LoadInitDataCommand.Execute(null);
        }

        // Command: Tải toàn bộ dữ liệu cần thiết cho màn hình (Show, Theater, Time...)
        [RelayCommand]
        private async Task LoadInitData()
        {
            // 1. Tải danh sách Vở diễn và Rạp từ DB
            var shows = await _dbService.GetShowsSimpleAsync();
            ShowsList = new ObservableCollection<Show>(shows);

            var theaters = await _dbService.GetTheatersAsync();
            TheatersList = new ObservableCollection<Theater>(theaters);

            // 2. Khởi tạo danh sách Giờ (0-23) và Phút (bước nhảy 5 phút)
            HoursList = new ObservableCollection<int>(Enumerable.Range(0, 24)); 
            var minutes = new List<int>();
            for (int i = 0; i < 60; i += 5) minutes.Add(i);
            MinutesList = new ObservableCollection<int>(minutes);

            // 3. Thiết lập giá trị mặc định cho Form (19:00)
            SelectedHour = 19;
            SelectedMinute = 0;
            UpdateEndTime();

            // 4. Thiết lập bộ lọc Rạp (Thêm mục "Tất cả")
            var filters = theaters.ToList();
            filters.Insert(0, new Theater { TheaterId = 0, Name = "-- Tất cả Rạp --" });
            FilterTheaters = new ObservableCollection<Theater>(filters);
            SelectedFilterTheater = FilterTheaters[0];

            // 5. Tải danh sách suất diễn và reset form
            await LoadPerformances();
            ClearForm();
        }

        // Hàm Logic: Tự động tính giờ kết thúc dựa trên Giờ bắt đầu + Thời lượng vở diễn
        private void UpdateEndTime()
        {
            if (SelectedShow == null)
            {
                EndTimeStr = "--:--";
                return;
            }

            // Lấy thời lượng từ Vở diễn (DurationMinutes)
            int duration = SelectedShow.DurationMinutes;

            // Tạo thời gian bắt đầu giả định (dùng ngày hiện tại để tính toán)
            DateTime start = DateTime.Today.AddHours(SelectedHour).AddMinutes(SelectedMinute);

            // Cộng thời lượng
            DateTime end = start.AddMinutes(duration);

            // Cập nhật text hiển thị
            EndTimeStr = end.ToString("HH:mm");
        }

        // Các hàm partial này được sinh tự động bởi CommunityToolkit.Mvvm
        // Khi các thuộc tính thay đổi, chúng sẽ gọi UpdateEndTime để tính lại giờ kết thúc ngay lập tức
        partial void OnSelectedShowChanged(Show value) => UpdateEndTime();
        partial void OnSelectedHourChanged(int value) => UpdateEndTime();
        partial void OnSelectedMinuteChanged(int value) => UpdateEndTime();

        // Command: Tải danh sách suất diễn từ DB theo bộ lọc
        [RelayCommand]
        private async Task LoadPerformances()
        {
            int tId = SelectedFilterTheater?.TheaterId ?? 0;
            var list = await _dbService.GetPerformancesAsync(SearchShowName, tId, SelectedFilterDate);

            foreach (var p in list)
            {

                var showObj = ShowsList.FirstOrDefault(s => s.ShowId == p.ShowId);
                p.ShowTitle = showObj?.Title ?? "Không xác định"; // Gán tên vở

                var theaterObj = TheatersList.FirstOrDefault(t => t.TheaterId == p.TheaterId);
                p.TheaterName = theaterObj?.Name ?? "Không xác định"; // Gán tên rạp

                p.Show = showObj;
                p.Theater = theaterObj;
            }
            // --------------------

            Performances = new ObservableCollection<Performance>(list);
        }

        // Command: Xóa bộ lọc và tải lại
        [RelayCommand]
        private void ClearFilter()
        {
            SearchShowName = "";
            SelectedFilterTheater = FilterTheaters[0];
            SelectedFilterDate = null;
            LoadPerformancesCommand.Execute(null);
        }

        // Command: Đổ dữ liệu lên Form để chỉnh sửa
        [RelayCommand]
        private void Edit(Performance p)
        {
            if (p == null) return;
            PerfId = p.PerformanceId;

            // Tìm đối tượng Show và Theater tương ứng trong danh sách nguồn để Combobox hiển thị đúng
            SelectedShow = ShowsList.FirstOrDefault(s => s.ShowId == p.ShowId);
            SelectedTheater = TheatersList.FirstOrDefault(t => t.TheaterId == p.TheaterId);

            PerfDate = p.PerformanceDate;
            SelectedHour = p.StartTime.Hours;
            SelectedMinute = p.StartTime.Minutes;

            if (!MinutesList.Contains(SelectedMinute)) SelectedMinute = 0; PriceStr = p.Price.ToString("F0");
            UpdateEndTime();

            // Cấu hình trạng thái (Status)
            StatusOptions = new ObservableCollection<string> { "Đang mở bán", "Đã hủy" };
            if (!StatusOptions.Contains(p.Status))
            {
                StatusOptions.Add(p.Status);
            }

            SelectedStatus = p.Status;
            IsStatusEnabled = true; // Cho phép chọn lại
            SaveBtnContent = "Lưu thay đổi";

            // Kiểm tra Logic nghiệp vụ: Nếu đã có vé bán ra -> Khóa sửa thông tin quan trọng
            if (p.HasBookings)
            {
                // Đã có vé -> Chỉ cho sửa Status (IsDetailEditable = false)
                IsDetailEditable = false;
                MessageBox.Show("Suất diễn này đang có đơn đặt vé.\nBạn chỉ được phép thay đổi TRẠNG THÁI, không thể sửa thông tin chi tiết hoặc xóa.", "Lưu ý", MessageBoxButton.OK, MessageBoxImage.Information);
            }
            else
            {
                // Chưa có vé -> Cho sửa hết
                IsDetailEditable = true;
            }
        }

        // Command: Reset form về trạng thái thêm mới
        [RelayCommand]
        private void ClearForm()
        {
            PerfId = 0;
            SelectedShow = null;
            SelectedTheater = null;
            PerfDate = DateTime.Now;
            SelectedHour = 19; SelectedMinute = 0;
            PriceStr = "";
            StatusOptions = new ObservableCollection<string> { "Đang mở bán" };
            SelectedStatus = "Đang mở bán";
            IsStatusEnabled = false; // Khóa không cho bấm
            SaveBtnContent = "Thêm suất diễn";
            IsDetailEditable = true;
        }

        // Command: Lưu dữ liệu (Thêm mới hoặc Cập nhật)
        [RelayCommand]
        private async Task Save()
        {
            // 1. Parse và Validate dữ liệu đầu vào
            decimal.TryParse(PriceStr, out decimal price);

            if (SelectedShow == null || SelectedTheater == null || price <= 0)
            {
                MessageBox.Show("Vui lòng nhập đầy đủ thông tin (Vở diễn, Rạp, Giá vé)!");
                return;
            }

            // 2. Tính toán thời gian thực tế (Start & End)
            DateTime startDateTime = PerfDate.Date.Add(new TimeSpan(SelectedHour, SelectedMinute, 0));
            DateTime endDateTime = startDateTime.AddMinutes(SelectedShow.DurationMinutes);
            TimeSpan startTime = new TimeSpan(SelectedHour, SelectedMinute, 0);
            TimeSpan endTime = startTime.Add(TimeSpan.FromMinutes(SelectedShow.DurationMinutes));

            // 3. Kiểm tra Trùng lịch (Overlap Check)
            // Gọi Service để xem Rạp này vào giờ này có suất nào khác đang chiếu không
            bool isOverlap = await _dbService.CheckPerformanceOverlapAsync(
                SelectedTheater.TheaterId, 
                PerfDate,
                startTime,
                endTime,
                PerfId );// Truyền ID hiện tại để tránh báo trùng với chính nó khi sửa

            if (isOverlap)
            {
                MessageBox.Show($"Rạp '{SelectedTheater.Name}' đã có suất diễn khác trong khung giờ này!\n" +
                                $"({startTime:hh\\:mm} - {endTime:hh\\:mm})",
                                "Trùng lịch", MessageBoxButton.OK, MessageBoxImage.Warning);
                return; // Dừng lại, không lưu
            }

            // 4. Kiểm tra Logic thời gian: Không cho mở bán suất đã qua
            if (SelectedStatus == "Đang mở bán")
            {
                if (endDateTime <= DateTime.Now)
                {
                    MessageBox.Show($"Không thể mở bán suất diễn đã kết thúc!\n" +
                                    $"Giờ kết thúc dự kiến: {endDateTime:dd/MM/yyyy HH:mm}\n" +
                                    $"Vui lòng chọn thời gian khác.",
                                    "Thời gian không hợp lệ", MessageBoxButton.OK, MessageBoxImage.Warning);
                    return;
                }
            }

            TimeSpan start = new TimeSpan(SelectedHour, SelectedMinute, 0);

            // 5. Tạo đối tượng Performance để lưu
            var perf = new Performance
            {
                PerformanceId = PerfId,
                ShowId = SelectedShow.ShowId,
                TheaterId = SelectedTheater.TheaterId,
                PerformanceDate = PerfDate,
                StartTime = start,
                Price = price,

                // [ĐÚNG] Gán trạng thái từ ComboBox
                Status = SelectedStatus
            };

            try
            {
                // Gọi Service lưu xuống DB (Insert hoặc Update)
                await _dbService.SavePerformanceAsync(perf);
                MessageBox.Show(PerfId > 0 ? "Cập nhật thành công!" : "Thêm mới thành công!");
                ClearForm();
                await LoadPerformances();
            }
            catch (Exception ex) { MessageBox.Show("Lỗi: " + ex.Message); }
        }

        // Command: Xóa suất diễn
        [RelayCommand]
        private async Task Delete(Performance p)
        {
            // Kiểm tra ràng buộc dữ liệu: Không xóa suất đã bán vé
            if (p.HasBookings)
            {
                MessageBox.Show("Không thể xóa suất diễn này vì đã có vé được bán!", "Cảnh báo", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            if (MessageBox.Show("Xóa suất diễn này?", "Xác nhận", MessageBoxButton.YesNo) == MessageBoxResult.Yes)
            {
                try
                {
                    await _dbService.DeletePerformanceAsync(p.PerformanceId);
                    await LoadPerformances();
                }
                catch
                {
                    MessageBox.Show("Lỗi khi xóa dữ liệu.");
                }
            }
        }
    }
}