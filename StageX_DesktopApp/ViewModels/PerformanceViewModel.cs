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

        // Form Fields
        [ObservableProperty] private int _perfId;
        [ObservableProperty] private Show _selectedShow;
        [ObservableProperty] private Theater _selectedTheater;
        [ObservableProperty] private DateTime _perfDate = DateTime.Now;
        [ObservableProperty] private string _startTimeStr; // Binding text (HH:mm)
        [ObservableProperty] private string _priceStr;     // Binding text
        [ObservableProperty] private int _statusIndex = 0; // 0: Mở bán, 1: Hủy
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

            var filters = theaters.ToList();
            filters.Insert(0, new Theater { TheaterId = 0, Name = "-- Tất cả Rạp --" });
            FilterTheaters = new ObservableCollection<Theater>(filters);
            SelectedFilterTheater = FilterTheaters[0];

            await LoadPerformances();
        }

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
            StartTimeStr = p.StartTime.ToString(@"hh\:mm");
            PriceStr = p.Price.ToString("F0");
            StatusIndex = (p.Status == "Đã hủy") ? 1 : 0;
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
            StartTimeStr = "";
            PriceStr = "";
            StatusIndex = 0;
            SaveBtnContent = "Thêm suất diễn";
            IsDetailEditable = true;
        }

        [RelayCommand]
        private async Task Save()
        {
            if (SelectedShow == null || SelectedTheater == null ||
                !TimeSpan.TryParse(StartTimeStr, out TimeSpan start) ||
                !decimal.TryParse(PriceStr, out decimal price))
            {
                MessageBox.Show("Vui lòng nhập đầy đủ thông tin!");
                return;
            }

            var perf = new Performance
            {
                PerformanceId = PerfId,
                ShowId = SelectedShow.ShowId,
                TheaterId = SelectedTheater.TheaterId,
                PerformanceDate = PerfDate,
                StartTime = start,
                Price = price,
                Status = StatusIndex == 1 ? "Đã hủy" : "Đang mở bán"
            };

            try
            {
                await _dbService.SavePerformanceAsync(perf);
                MessageBox.Show("Lưu thành công!");
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