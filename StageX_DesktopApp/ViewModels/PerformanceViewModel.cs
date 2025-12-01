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
using System.Windows.Controls; // Để dùng ComboBoxItem nếu cần, nhưng tốt nhất nên tránh

namespace StageX_DesktopApp.ViewModels
{
    public partial class PerformanceViewModel : ObservableObject
    {
        private readonly DatabaseService _dbService;

        [ObservableProperty] private ObservableCollection<Performance> _performances;

        // Combobox Sources
        [ObservableProperty] private ObservableCollection<Show> _showsList;
        [ObservableProperty] private ObservableCollection<Theater> _theatersList;
        [ObservableProperty] private ObservableCollection<Theater> _filterTheaters;

        // Filter
        [ObservableProperty] private string _searchShowName;
        [ObservableProperty] private Theater _selectedFilterTheater;
        [ObservableProperty] private DateTime? _selectedFilterDate;
        [ObservableProperty] private bool _isDetailEditable = true;
        //Giờ
        [ObservableProperty] private ObservableCollection<int> _hoursList;
        [ObservableProperty] private ObservableCollection<int> _minutesList;
        [ObservableProperty] private int _selectedHour;
        [ObservableProperty] private int _selectedMinute;
        [ObservableProperty] private string _endTimeStr = "--:--";
        // Form Fields
        [ObservableProperty] private int _perfId;
        [ObservableProperty] private Show _selectedShow;
        [ObservableProperty] private Theater _selectedTheater;
        [ObservableProperty] private DateTime _perfDate = DateTime.Now;
        [ObservableProperty] private string _priceStr;     // Binding text
        [ObservableProperty] private ObservableCollection<string> _statusOptions;
        [ObservableProperty] private string _selectedStatus;
        [ObservableProperty] private bool _isStatusEnabled;
        [ObservableProperty] private string _saveBtnContent = "Thêm suất diễn";

        public PerformanceViewModel()
        {
            _dbService = new DatabaseService();
            LoadInitDataCommand.Execute(null);
        }

        [RelayCommand]
        private async Task LoadInitData()
        {
            var shows = await _dbService.GetShowsSimpleAsync();
            ShowsList = new ObservableCollection<Show>(shows);

            var theaters = await _dbService.GetTheatersAsync();
            TheatersList = new ObservableCollection<Theater>(theaters);

            HoursList = new ObservableCollection<int>(Enumerable.Range(0, 24)); 
            var minutes = new List<int>();
            for (int i = 0; i < 60; i += 5) minutes.Add(i);
            MinutesList = new ObservableCollection<int>(minutes);

            // Mặc định chọn 19:00
            SelectedHour = 19;
            SelectedMinute = 0;
            UpdateEndTime();

            var filters = theaters.ToList();
            filters.Insert(0, new Theater { TheaterId = 0, Name = "-- Tất cả Rạp --" });
            FilterTheaters = new ObservableCollection<Theater>(filters);
            SelectedFilterTheater = FilterTheaters[0];

            await LoadPerformances();
            ClearForm();
        }
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
        partial void OnSelectedShowChanged(Show value) => UpdateEndTime();
        partial void OnSelectedHourChanged(int value) => UpdateEndTime();
        partial void OnSelectedMinuteChanged(int value) => UpdateEndTime();

        [RelayCommand]
        private async Task LoadPerformances()
        {
            int tId = SelectedFilterTheater?.TheaterId ?? 0;
            var list = await _dbService.GetPerformancesAsync(SearchShowName, tId, SelectedFilterDate);

            foreach (var p in list)
            {
                p.ShowTitle = p.Show?.Title;
                p.TheaterName = p.Theater?.Name;
            }
            Performances = new ObservableCollection<Performance>(list);
        }

        [RelayCommand]
        private void ClearFilter()
        {
            SearchShowName = "";
            SelectedFilterTheater = FilterTheaters[0];
            SelectedFilterDate = null;
            LoadPerformancesCommand.Execute(null);
        }

        [RelayCommand]
        private void Edit(Performance p)
        {
            if (p == null) return;
            PerfId = p.PerformanceId;
            // Tìm Show trong list để combobox hiển thị đúng
            SelectedShow = ShowsList.FirstOrDefault(s => s.ShowId == p.ShowId);
            SelectedTheater = TheatersList.FirstOrDefault(t => t.TheaterId == p.TheaterId);
            PerfDate = p.PerformanceDate;
            SelectedHour = p.StartTime.Hours;
            SelectedMinute = p.StartTime.Minutes;
            if (!MinutesList.Contains(SelectedMinute)) SelectedMinute = 0; PriceStr = p.Price.ToString("F0");
            UpdateEndTime();

            StatusOptions = new ObservableCollection<string> { "Đang mở bán", "Đã hủy" };
            if (!StatusOptions.Contains(p.Status))
            {
                StatusOptions.Add(p.Status);
            }
            SelectedStatus = p.Status;
            IsStatusEnabled = true; // Cho phép chọn lại
            SaveBtnContent = "Lưu thay đổi";
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

        [RelayCommand]
        private async Task Save()
        {
            // 1. Parse giá tiền
            decimal.TryParse(PriceStr, out decimal price);

            // 2. Validate dữ liệu
            if (SelectedShow == null || SelectedTheater == null || price <= 0)
            {
                MessageBox.Show("Vui lòng nhập đầy đủ thông tin (Vở diễn, Rạp, Giá vé)!");
                return;
            }

            // 3. Tính toán thời gian
            DateTime startDateTime = PerfDate.Date.Add(new TimeSpan(SelectedHour, SelectedMinute, 0));
            DateTime endDateTime = startDateTime.AddMinutes(SelectedShow.DurationMinutes);
            TimeSpan startTime = new TimeSpan(SelectedHour, SelectedMinute, 0);
            TimeSpan endTime = startTime.Add(TimeSpan.FromMinutes(SelectedShow.DurationMinutes));

            bool isOverlap = await _dbService.CheckPerformanceOverlapAsync(
        SelectedTheater.TheaterId,
        PerfDate,
        startTime,
        endTime,
        PerfId // Truyền ID hiện tại để tránh báo trùng với chính nó khi sửa
    );

            if (isOverlap)
            {
                MessageBox.Show($"Rạp '{SelectedTheater.Name}' đã có suất diễn khác trong khung giờ này!\n" +
                                $"({startTime:hh\\:mm} - {endTime:hh\\:mm})",
                                "Trùng lịch", MessageBoxButton.OK, MessageBoxImage.Warning);
                return; // Dừng lại, không lưu
            }
            // 4. [SỬA QUAN TRỌNG TẠI ĐÂY] 
            // Kiểm tra dựa trên chuỗi SelectedStatus thay vì StatusIndex
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
                await _dbService.SavePerformanceAsync(perf);
                MessageBox.Show(PerfId > 0 ? "Cập nhật thành công!" : "Thêm mới thành công!");
                ClearForm();
                await LoadPerformances();
            }
            catch (Exception ex) { MessageBox.Show("Lỗi: " + ex.Message); }
        }
        [RelayCommand]
        private async Task Delete(Performance p)
        {
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