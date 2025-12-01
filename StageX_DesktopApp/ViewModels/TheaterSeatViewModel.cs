using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using CommunityToolkit.Mvvm.Messaging;
using StageX_DesktopApp.Models;
using StageX_DesktopApp.Services;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Media;

namespace StageX_DesktopApp.ViewModels
{
    // --- WRAPPER CLASS ---

    public partial class SeatUiItem : ObservableObject
    {
        public Seat SeatData { get; }

        // [MỚI] Tên hàng dùng để hiển thị (VD: "B" dù dữ liệu gốc là "C")
        private string _visualRowChar;

        [ObservableProperty] private bool _isSelected;
        public IRelayCommand SelectCommand { get; }

        // Constructor nhận thêm visualRowChar
        public SeatUiItem(Seat seat, string visualRowChar, Action<SeatUiItem> onSelect)
        {
            SeatData = seat;
            _visualRowChar = visualRowChar;
            SelectCommand = new RelayCommand(() => onSelect(this));
        }

        // [SỬA] Hiển thị theo tên ảo (Visual) thay vì tên gốc
        public string DisplayText => $"{_visualRowChar}{SeatData.RealSeatNumber}";

        public SolidColorBrush BackgroundColor
        {
            get
            {
                if (SeatData.SeatCategory?.ColorClass is string hex)
                {
                    try { return (SolidColorBrush)new BrushConverter().ConvertFrom(hex.StartsWith("#") ? hex : "#" + hex); }
                    catch { }
                }
                return new SolidColorBrush(Color.FromRgb(50, 50, 50));
            }
        }
        public void RefreshView() { OnPropertyChanged(nameof(BackgroundColor)); OnPropertyChanged(nameof(DisplayText)); }
    }

    public class SeatRowItem
    {
        public string RowName { get; set; }
        public ObservableCollection<object> Items { get; set; }
        // Hàng rỗng (lối đi) sẽ thấp hơn hàng ghế một chút
        public double RowHeight => string.IsNullOrEmpty(RowName) ? 30 : 36;
    }

    // --- VIEWMODEL CHÍNH ---
    public partial class TheaterSeatViewModel : ObservableObject, IRecipient<SeatCategoryChangedMessage>
    {
        private readonly DatabaseService _dbService;

        [ObservableProperty] private ObservableCollection<Theater> _theaters;
        [ObservableProperty] private ObservableCollection<SeatCategory> _categories;
        [ObservableProperty] private ObservableCollection<SeatRowItem> _seatMap;

        public List<Seat> CurrentSeats { get; set; } = new List<Seat>();
        private List<SeatUiItem> _selectedUiItems = new List<SeatUiItem>();

        // Trạng thái Form
        [ObservableProperty] private bool _isCreatingNew = true;
        [ObservableProperty] private bool _isReadOnlyMode = false;
        [ObservableProperty] private string _panelTitle = "TẠO RẠP MỚI";
        [ObservableProperty] private string _saveBtnContent = "Lưu rạp mới";

        // Input
        [ObservableProperty] private string _inputTheaterName = "";
        [ObservableProperty] private string _inputRows = "";
        [ObservableProperty] private string _inputCols = "";
        [ObservableProperty] private Theater _selectedTheater;

        // Hạng ghế & Chọn vùng
        [ObservableProperty] private string _categoryName = "";
        [ObservableProperty] private string _categoryPrice = "";
        [ObservableProperty] private int _editingCategoryId = 0;
        [ObservableProperty] private string _categoryBtnContent = "Thêm";
        [ObservableProperty] private ObservableCollection<string> _rowOptions;
        [ObservableProperty] private ObservableCollection<int> _seatNumberOptions;
        [ObservableProperty] private string _selectedRowOption;
        [ObservableProperty] private int? _selectedStartOption;
        [ObservableProperty] private int? _selectedEndOption;
        [ObservableProperty] private int _selectedAssignCategoryId;

        public TheaterSeatViewModel()
        {
            _dbService = new DatabaseService();
            WeakReferenceMessenger.Default.RegisterAll(this);
            Application.Current.Dispatcher.InvokeAsync(async () =>
            {
                await LoadData();
                ResetToCreateMode();
            });
        }

        public void Receive(SeatCategoryChangedMessage m) => Application.Current.Dispatcher.InvokeAsync(async () => await LoadData(true));

        private async Task LoadData(bool onlyCats = false)
        {
            if (!onlyCats) Theaters = new ObservableCollection<Theater>(await _dbService.GetTheatersWithStatusAsync());
            Categories = new ObservableCollection<SeatCategory>(await _dbService.GetSeatCategoriesAsync());
        }

        // --- 1. LOGIC VẼ SƠ ĐỒ THÔNG MINH (VISUAL MAPPING) ---
        private void RefreshVisualMap()
        {
            _selectedUiItems.Clear();

            if (CurrentSeats == null || CurrentSeats.Count == 0)
            {
                SeatMap = new ObservableCollection<SeatRowItem>();
                return;
            }

            // Tìm hàng lớn nhất theo dữ liệu gốc (VD: D)
            var distinctRows = CurrentSeats.Select(s => s.RowChar.Trim().ToUpper()).Distinct().ToList();
            if (distinctRows.Count == 0) return;

            string maxRowChar = distinctRows.OrderBy(r => r.Length).ThenBy(r => r).Last();
            int maxRowIndex = RowCharToIndex(maxRowChar);
            int maxCol = CurrentSeats.Max(s => s.SeatNumber);

            var newMap = new ObservableCollection<SeatRowItem>();

            // Biến đếm để đặt tên hàng hiển thị (A, B, C...) liên tục
            int visualRowCounter = 0;

            // Quét từ A -> MaxRow (0 -> 3)
            // Dù hàng B (index 1) bị xóa, vòng lặp vẫn chạy qua nó
            for (int i = 0; i <= maxRowIndex; i++)
            {
                string physicalRowChar = IndexToRowChar(i); // Tên gốc: A, B, C...
                var seatsInRow = CurrentSeats.Where(s => s.RowChar == physicalRowChar).ToList();

                if (seatsInRow.Count > 0)
                {
                    // -- HÀNG CÓ GHẾ --
                    // Tính tên hiển thị mới (VD: C -> B nếu hàng B bị xóa)
                    string visualLabel = IndexToRowChar(visualRowCounter);
                    visualRowCounter++; // Tăng đếm cho hàng kế tiếp

                    var rowItem = new SeatRowItem { RowName = visualLabel, Items = new ObservableCollection<object>() };

                    for (int c = 1; c <= maxCol; c++)
                    {
                        var seat = seatsInRow.FirstOrDefault(s => s.SeatNumber == c);
                        // Truyền visualLabel vào SeatUiItem để nó hiển thị B1 thay vì C1
                        rowItem.Items.Add(seat != null ? new SeatUiItem(seat, visualLabel, OnSeatClicked) : null);
                    }
                    newMap.Add(rowItem);
                }
                else
                {
                    // -- HÀNG BỊ XÓA (LỐI ĐI) --
                    // KHÔNG tăng visualRowCounter => Hàng kế tiếp sẽ dùng lại tên này
                    newMap.Add(new SeatRowItem { RowName = "", Items = new ObservableCollection<object>() });
                }
            }
            SeatMap = newMap;

            // Cập nhật ComboBox theo tên hiển thị (Visual Labels)
            var visualRows = newMap.Where(r => !string.IsNullOrEmpty(r.RowName)).Select(r => r.RowName).ToList();
            RowOptions = new ObservableCollection<string>(visualRows);
            SeatNumberOptions = new ObservableCollection<int>(Enumerable.Range(1, maxCol));
        }

        private void OnSeatClicked(SeatUiItem item)
        {
            if (IsReadOnlyMode) return;
            if (_selectedUiItems.Contains(item)) { item.IsSelected = false; _selectedUiItems.Remove(item); }
            else { item.IsSelected = true; _selectedUiItems.Add(item); }
        }

        // --- 2. CHỨC NĂNG THAO TÁC ---

        [RelayCommand]
        private void RemoveSelectedSeats()
        {
            if (_selectedUiItems.Count == 0) { MessageBox.Show("Chưa chọn ghế!"); return; }

            foreach (var item in _selectedUiItems) CurrentSeats.Remove(item.SeatData);
            _selectedUiItems.Clear();

            // [TỐI ƯU] Chỉ xếp lại cột 1,2,3. KHÔNG xếp lại hàng (để giữ lối đi)
            var rows = CurrentSeats.GroupBy(s => s.RowChar);
            foreach (var r in rows)
            {
                var sorted = r.OrderBy(s => s.SeatNumber).ToList();
                for (int i = 0; i < sorted.Count; i++) sorted[i].RealSeatNumber = i + 1;
            }

            RefreshVisualMap(); // Logic vẽ lại sẽ tự động lo việc đặt tên ABC
        }

        [RelayCommand]
        private void SelectRange()
        {
            if (string.IsNullOrEmpty(SelectedRowOption)) return;
            int start = SelectedStartOption ?? 0;
            int end = SelectedEndOption ?? 1000;
            int count = 0;

            // Duyệt qua Visual Map để chọn đúng hàng đang hiển thị
            foreach (var row in SeatMap)
            {
                if (row.RowName == SelectedRowOption)
                {
                    foreach (var item in row.Items.OfType<SeatUiItem>())
                    {
                        if (item.SeatData.SeatNumber >= start && item.SeatData.SeatNumber <= end && !_selectedUiItems.Contains(item))
                        {
                            item.IsSelected = true; _selectedUiItems.Add(item); count++;
                        }
                    }
                }
            }
            if (count > 0) MessageBox.Show($"Đã chọn {count} ghế.");
        }

        [RelayCommand]
        private void PreviewMap()
        {
            if (!int.TryParse(InputRows, out int r) || !int.TryParse(InputCols, out int c) || r <= 0 || c <= 0)
            { MessageBox.Show("Số hàng/cột không hợp lệ"); return; }

            CurrentSeats.Clear();
            for (int i = 0; i < r; i++)
            {
                string charRow = ((char)('A' + i)).ToString();
                for (int j = 1; j <= c; j++)
                    CurrentSeats.Add(new Seat { RowChar = charRow, SeatNumber = j, RealSeatNumber = j });
            }
            RefreshVisualMap();
        }

        // --- 3. CÁC HÀM CRUD & HỆ THỐNG (Giữ nguyên logic tối ưu trước đó) ---
        [RelayCommand]
        private void ResetToCreateMode()
        {
            IsCreatingNew = true; IsReadOnlyMode = false;
            PanelTitle = "1. TẠO RẠP MỚI" ; SaveBtnContent = "Lưu rạp mới";
            SelectedTheater = null; InputTheaterName = ""; InputRows = ""; InputCols = "";
            CurrentSeats.Clear(); RefreshVisualMap();
        }

        [RelayCommand]
        private async Task SelectTheater(object obj)
        {
            if (obj is not Theater t) return;
            SelectedTheater = t; InputTheaterName = t.Name;
            IsCreatingNew = false;

            if (t.CanDelete) { IsReadOnlyMode = false; PanelTitle = $"CHỈNH SỬA: {t.Name}"; SaveBtnContent = "Cập nhật"; }
            else { IsReadOnlyMode = true; PanelTitle = $"CHI TIẾT: {t.Name} (Chỉ xem)"; SaveBtnContent = ""; }

            try { CurrentSeats = await _dbService.GetSeatsByTheaterAsync(t.TheaterId); RefreshVisualMap(); } catch { }
        }

        [RelayCommand]
        private async Task SaveChanges()
        {
            if (IsReadOnlyMode) return;
            if (string.IsNullOrWhiteSpace(InputTheaterName)) { MessageBox.Show("Nhập tên rạp!"); return; }
            if (CurrentSeats == null || CurrentSeats.Count == 0) { MessageBox.Show("Sơ đồ rạp trống!"); return; }
            if (CurrentSeats.Any(s => s.CategoryId == null || s.CategoryId == 0)) { MessageBox.Show("Vui lòng gán hạng ghế!"); return; }

            try
            {
                if (IsCreatingNew)
                {
                    var t = new Theater { Name = InputTheaterName, TotalSeats = CurrentSeats.Count, Status = "Đã hoạt động" };
                    await _dbService.SaveNewTheaterAsync(t, CurrentSeats);
                    MessageBox.Show("Thêm mới thành công!");
                }
                else if (SelectedTheater != null)
                {
                    SelectedTheater.Name = InputTheaterName;
                    await _dbService.UpdateTheaterStructureAsync(SelectedTheater, CurrentSeats);
                    MessageBox.Show("Cập nhật thành công!");
                }
                ResetToCreateMode(); await LoadData();
            }
            catch (Exception ex) { MessageBox.Show("Lỗi: " + ex.Message); }
        }

        [RelayCommand]
        private async Task ApplyCategory()
        {
            if (IsReadOnlyMode || _selectedUiItems.Count == 0 || SelectedAssignCategoryId == 0) return;
            var cat = Categories.FirstOrDefault(c => c.CategoryId == SelectedAssignCategoryId);
            foreach (var item in _selectedUiItems) { item.SeatData.CategoryId = SelectedAssignCategoryId; item.SeatData.SeatCategory = cat; item.IsSelected = false; item.RefreshView(); }
            _selectedUiItems.Clear();
        }

        [RelayCommand] private async Task DeleteTheater(object obj) { if (obj is Theater t && MessageBox.Show($"Xóa {t.Name}?", "Xác nhận", MessageBoxButton.YesNo) == MessageBoxResult.Yes) { try { await _dbService.DeleteTheaterAsync(t.TheaterId); await LoadData(); ResetToCreateMode(); } catch { MessageBox.Show("Không thể xóa!"); } } }

        // Hạng ghế CRUD
        [RelayCommand] private async Task SaveCategory() { if (string.IsNullOrEmpty(CategoryName)) return; decimal.TryParse(CategoryPrice, out decimal p); var c = new SeatCategory { CategoryId = EditingCategoryId, CategoryName = CategoryName, BasePrice = p, ColorClass = EditingCategoryId == 0 ? "1ABC9C" : null }; await _dbService.SaveSeatCategoryAsync(c); MessageBox.Show("Lưu thành công!"); CategoryName = ""; CategoryPrice = ""; EditingCategoryId = 0; CategoryBtnContent = "Thêm"; await LoadData(true); }
        [RelayCommand] private void EditCategory(SeatCategory c) { CategoryName = c.CategoryName; CategoryPrice = c.BasePrice.ToString("F0"); EditingCategoryId = c.CategoryId; CategoryBtnContent = "Lưu"; }
        [RelayCommand] private async Task DeleteCategory(SeatCategory c) { if (MessageBox.Show("Xóa?", "Xác nhận", MessageBoxButton.YesNo) == MessageBoxResult.Yes) { await _dbService.DeleteSeatCategoryAsync(c.CategoryId); await LoadData(true); } }

        // Helpers
        private int RowCharToIndex(string row) => string.IsNullOrEmpty(row) ? 0 : (int)(row[0] - 'A');
        private string IndexToRowChar(int index) => ((char)('A' + index)).ToString();
    }

    public class SeatCategoryChangedMessage { public string Value { get; } public SeatCategoryChangedMessage(string v) => Value = v; }
}