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
using System.Windows.Threading;

namespace StageX_DesktopApp.ViewModels
{
    // --- WRAPPER CLASS ---

    public partial class SeatUiItem : ObservableObject
    {
        public Seat SeatData { get; }

        // Tên hàng dùng để hiển thị (VD: "B" dù dữ liệu gốc là "C")
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

        // Hiển thị theo tên ảo (Visual) thay vì tên gốc
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

    // Đại diện cho 1 hàng ghế (Chứa danh sách các SeatUiItem)
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

        // Danh sách rạp và hạng ghế lấy từ DB
        [ObservableProperty] private ObservableCollection<Theater> _theaters;
        [ObservableProperty] private ObservableCollection<SeatCategory> _categories;

        // Dữ liệu chính để binding ra ItemsControl vẽ sơ đồ ghế (List lồng List)
        [ObservableProperty] private ObservableCollection<SeatRowItem> _seatMap;

        public List<Seat> CurrentSeats { get; set; } = new List<Seat>();
        private List<SeatUiItem> _selectedUiItems = new List<SeatUiItem>();

        // Timer tự động refresh seat_category
        private readonly DispatcherTimer _categoryRefreshTimer;

        // --- CÁC BIẾN TRẠNG THÁI FORM ---
        [ObservableProperty] private bool _isCreatingNew = true;
        [ObservableProperty] private bool _isReadOnlyMode = false;
        [ObservableProperty] private string _panelTitle = "TẠO RẠP MỚI";
        [ObservableProperty] private string _saveBtnContent = "Lưu rạp mới";

        // --- CÁC BIẾN INPUT (Tên rạp, số hàng, số cột) ---
        [ObservableProperty] private string _inputTheaterName = "";
        [ObservableProperty] private string _inputRows = "";
        [ObservableProperty] private string _inputCols = "";
        [ObservableProperty] private Theater _selectedTheater;

        // Các biến cho chức năng chọn nhanh vùng ghế (Từ hàng... ghế số... đến...)
        [ObservableProperty] private ObservableCollection<string> _rowOptions;
        [ObservableProperty] private ObservableCollection<int> _seatNumberOptions;
        [ObservableProperty] private string _selectedRowOption;
        [ObservableProperty] private int? _selectedStartOption;
        [ObservableProperty] private int? _selectedEndOption;
        [ObservableProperty] private int _selectedAssignCategoryId;

        public TheaterSeatViewModel()
        {
            _dbService = new DatabaseService();

            // Đăng ký nhận tin nhắn (Messaging) để update khi hạng ghế thay đổi
            WeakReferenceMessenger.Default.RegisterAll(this);

            // Tải dữ liệu ban đầu trên luồng UI
            Application.Current.Dispatcher.InvokeAsync(async () =>
            {
                await LoadData();
                ResetToCreateMode();
            });

            // Khởi tạo timer refresh category mỗi 5s
            _categoryRefreshTimer = new DispatcherTimer
            {
                Interval = TimeSpan.FromSeconds(5)
            };
            _categoryRefreshTimer.Tick += async (_, __) => await RefreshCategoriesOnly();
            _categoryRefreshTimer.Start();
        }

        // Nhận tin nhắn từ ViewModel khác báo hạng ghế đã thay đổi -> Tải lại
        public void Receive(SeatCategoryChangedMessage m) => Application.Current.Dispatcher.InvokeAsync(async () => await LoadData(true));

        private async Task LoadData(bool onlyCats = false)
        {
            if (!onlyCats) Theaters = new ObservableCollection<Theater>(await _dbService.GetTheatersWithStatusAsync());
            Categories = new ObservableCollection<SeatCategory>(await _dbService.GetSeatCategoriesAsync());
        }

        // Refresh seat_category (không reload sơ đồ)
        private async Task RefreshCategoriesOnly()
        {
            try
            {
                var latest = await _dbService.GetSeatCategoriesAsync();

                // Nếu số lượng thay đổi -> Cập nhật lại toàn bộ list
                if (Categories == null || latest.Count != Categories.Count)
                {
                    Categories = new ObservableCollection<SeatCategory>(latest);
                    UpdateSeatCategoryBinding();
                    return;
                }

                // Nếu số lượng không đổi, kiểm tra nội dung bên trong có khác không
                bool changed = false;
                for (int i = 0; i < latest.Count; i++)
                {
                    if (latest[i].CategoryName != Categories[i].CategoryName ||
                        latest[i].BasePrice != Categories[i].BasePrice ||
                        latest[i].ColorClass != Categories[i].ColorClass)
                    {
                        changed = true;
                        break;
                    }
                }

                // Có thay đổi -> Cập nhật UI
                if (changed)
                {
                    Categories = new ObservableCollection<SeatCategory>(latest);
                    UpdateSeatCategoryBinding();
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine("[CategoryRefresh] " + ex.Message);
            }
        }

        // Helper: Duyệt qua sơ đồ ghế đang vẽ để cập nhật lại thông tin Category mới nhất (để đổi màu ghế ngay lập tức)
        private void UpdateSeatCategoryBinding()
        {
            if (SeatMap == null) return;

            foreach (var row in SeatMap)
            {
                foreach (var obj in row.Items)
                {
                    if (obj is SeatUiItem ui)
                    {
                        // Tìm category mới tương ứng với ID trong ghế
                        ui.SeatData.SeatCategory =
                            Categories.FirstOrDefault(c => c.CategoryId == ui.SeatData.CategoryId);

                        ui.RefreshView(); // Báo UI vẽ lại màu
                    }
                }
            }
        }

        // --- 1. LOGIC VẼ SƠ ĐỒ (VISUAL MAPPING) ---
        private void RefreshVisualMap()
        {
            _selectedUiItems.Clear();

            // Nếu không có ghế nào thì gán Map rỗng
            if (CurrentSeats == null || CurrentSeats.Count == 0)
            {
                SeatMap = new ObservableCollection<SeatRowItem>();
                return;
            }

            // Lấy danh sách các chữ cái hàng (A, B, C...) duy nhất
            var distinctRows = CurrentSeats.Select(s => s.RowChar.Trim().ToUpper()).Distinct().ToList();
            if (distinctRows.Count == 0) return;

            // Tìm ký tự hàng lớn nhất (VD: 'H') để biết vòng lặp chạy đến đâu
            string maxRowChar = distinctRows.OrderBy(r => r.Length).ThenBy(r => r).Last();
            int maxRowIndex = RowCharToIndex(maxRowChar);
            int maxCol = CurrentSeats.Max(s => s.SeatNumber);

            var newMap = new ObservableCollection<SeatRowItem>();
            int visualRowCounter = 0;

            // Vòng lặp duyệt từ hàng A đến hàng lớn nhất
            for (int i = 0; i <= maxRowIndex; i++)
            {
                string physicalRowChar = IndexToRowChar(i);
                // Lấy tất cả ghế thuộc hàng này
                var seatsInRow = CurrentSeats.Where(s => s.RowChar == physicalRowChar).ToList();

                if (seatsInRow.Count > 0)
                {
                    // == TRƯỜNG HỢP CÓ GHẾ ==
                    // Tạo nhãn hiển thị mới (VD: Nếu hàng B bị xóa làm lối đi thì hàng C sẽ hiển thị là B)
                    string visualLabel = IndexToRowChar(visualRowCounter);
                    visualRowCounter++;

                    var rowItem = new SeatRowItem { RowName = visualLabel, Items = new ObservableCollection<object>() };

                    // Duyệt từng cột
                    for (int c = 1; c <= maxCol; c++)
                    {
                        var seat = seatsInRow.FirstOrDefault(s => s.SeatNumber == c);
                        // Nếu có ghế -> Thêm nút ghế; Nếu không -> Thêm null (khoảng trống)
                        rowItem.Items.Add(seat != null ? new SeatUiItem(seat, visualLabel, OnSeatClicked) : null);
                    }
                    newMap.Add(rowItem);
                }
                else
                {
                    // == TRƯỜNG HỢP HÀNG BỊ XÓA (LỐI ĐI NGANG) ==
                    // Thêm một hàng rỗng vào giao diện
                    newMap.Add(new SeatRowItem { RowName = "", Items = new ObservableCollection<object>() });
                }
            }

            SeatMap = newMap;

            // Cập nhật lại danh sách hàng cho ComboBox chọn vùng
            var visualRows = newMap.Where(r => !string.IsNullOrEmpty(r.RowName)).Select(r => r.RowName).ToList();
            RowOptions = new ObservableCollection<string>(visualRows);

            // Cập nhật danh sách số ghế cho ComboBox
            SeatNumberOptions = new ObservableCollection<int>(Enumerable.Range(1, maxCol));
        }

        // Hàm xử lý khi click vào một ghế trên sơ đồ
        private void OnSeatClicked(SeatUiItem item)
        {
            if (IsReadOnlyMode) return; // Nếu chế độ chỉ xem thì không cho chọn

            // Logic chọn/bỏ chọn (Toggle)
            if (_selectedUiItems.Contains(item)) { item.IsSelected = false; _selectedUiItems.Remove(item); }
            else { item.IsSelected = true; _selectedUiItems.Add(item); }
        }

        // --- 2. CHỨC NĂNG THAO TÁC CẤU TRÚC RẠP ---
        // Command: Xóa các ghế đang được chọn (Tạo lối đi/khoảng trống)
        [RelayCommand]
        private void RemoveSelectedSeats()
        {
            if (_selectedUiItems.Count == 0) { MessageBox.Show("Chưa chọn ghế!"); return; }

            // Xóa khỏi danh sách dữ liệu gốc
            foreach (var item in _selectedUiItems) CurrentSeats.Remove(item.SeatData);
            _selectedUiItems.Clear();

            // Sắp xếp lại số ghế thực (RealSeatNumber) cho liền mạch
            var rows = CurrentSeats.GroupBy(s => s.RowChar);
            foreach (var r in rows)
            {
                var sorted = r.OrderBy(s => s.SeatNumber).ToList();
                for (int i = 0; i < sorted.Count; i++) sorted[i].RealSeatNumber = i + 1;
            }

            RefreshVisualMap();
        }

        // Command: Chọn vùng ghế (VD: Hàng A, từ 1 đến 5)
        [RelayCommand]
        private void SelectRange()
        {
            if (string.IsNullOrEmpty(SelectedRowOption)) return;
            int start = SelectedStartOption ?? 0;
            int end = SelectedEndOption ?? 1000;
            int count = 0;

            foreach (var row in SeatMap)
            {
                // Tìm đúng hàng người dùng chọn
                if (row.RowName == SelectedRowOption)
                {
                    // Duyệt qua các ghế trong hàng đó
                    foreach (var item in row.Items.OfType<SeatUiItem>())
                    {
                        // Nếu số ghế nằm trong khoảng -> Chọn
                        if (item.SeatData.SeatNumber >= start && item.SeatData.SeatNumber <= end && !_selectedUiItems.Contains(item))
                        {
                            item.IsSelected = true; _selectedUiItems.Add(item); count++;
                        }
                    }
                }
            }
            if (count > 0) MessageBox.Show($"Đã chọn {count} ghế.");
        }

        // Command: Tạo sơ đồ tạm thời (Preview) dựa trên số hàng/cột nhập vào
        [RelayCommand]
        private void PreviewMap()
        {
            if (!int.TryParse(InputRows, out int r) || !int.TryParse(InputCols, out int c) || r <= 0 || c <= 0)
            { MessageBox.Show("Số hàng/cột không hợp lệ"); return; }

            CurrentSeats.Clear();
            // Tạo dữ liệu ghế giả lập
            for (int i = 0; i < r; i++)
            {
                string charRow = ((char)('A' + i)).ToString();
                for (int j = 1; j <= c; j++)
                    CurrentSeats.Add(new Seat { RowChar = charRow, SeatNumber = j, RealSeatNumber = j });
            }
            RefreshVisualMap();
        }

        // --- 3. CÁC HÀM CRUD & HỆ THỐNG ---

        // Command: Reset form về chế độ Tạo mới
        [RelayCommand]
        private void ResetToCreateMode()
        {
            IsCreatingNew = true; IsReadOnlyMode = false;
            PanelTitle = "1. TẠO RẠP MỚI"; SaveBtnContent = "Lưu rạp mới";
            SelectedTheater = null; InputTheaterName = ""; InputRows = ""; InputCols = "";
            CurrentSeats.Clear(); RefreshVisualMap();
        }

        // Command: Khi người dùng chọn 1 rạp trong danh sách bên phải
        [RelayCommand]
        private async Task SelectTheater(object obj)
        {
            if (obj is not Theater t) return;
            SelectedTheater = t; InputTheaterName = t.Name;
            IsCreatingNew = false;

            // Kiểm tra rạp có xóa được không (có suất diễn chưa?)
            // Nếu không xóa được -> Chế độ chỉ xem
            if (t.CanDelete) { IsReadOnlyMode = false; PanelTitle = $"CHỈNH SỬA: {t.Name}"; SaveBtnContent = "Cập nhật"; }
            else { IsReadOnlyMode = true; PanelTitle = $"CHI TIẾT: {t.Name} (Chỉ xem)"; SaveBtnContent = ""; }

            // Tải danh sách ghế của rạp đó từ DB và vẽ lên
            try { CurrentSeats = await _dbService.GetSeatsByTheaterAsync(t.TheaterId); RefreshVisualMap(); } catch { }
        }

        // Command: Lưu Rạp (Thêm mới hoặc Cập nhật)
        [RelayCommand]
        private async Task SaveChanges()
        {
            // Nếu đang ở chế độ Xem (ReadOnly) thì không làm gì cả
            if (IsReadOnlyMode) return;

            // 1. Validate dữ liệu cơ bản
            if (string.IsNullOrWhiteSpace(InputTheaterName))
            {
                MessageBox.Show("Vui lòng nhập tên rạp!", "Thiếu thông tin", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            if (CurrentSeats == null || CurrentSeats.Count == 0)
            {
                MessageBox.Show("Sơ đồ rạp trống! Vui lòng tạo ghế trước.", "Thiếu thông tin", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            // Kiểm tra xem tất cả ghế đã được gán hạng chưa
            if (CurrentSeats.Any(s => s.CategoryId == null || s.CategoryId == 0))
            {
                MessageBox.Show("Vui lòng gán hạng ghế cho tất cả các ghế!", "Thiếu thông tin", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            // 2. Validate nâng cao: KIỂM TRA TRÙNG TÊN RẠP
            string targetName = InputTheaterName.Trim();
            // Nếu đang tạo mới thì ID = 0, nếu đang sửa thì lấy ID của rạp hiện tại
            int currentId = IsCreatingNew ? 0 : (SelectedTheater?.TheaterId ?? 0);

            // Gọi DatabaseService để check (Hàm CheckTheaterNameExistsAsync bạn đã thêm ở bước trước)
            bool isDuplicate = await _dbService.CheckTheaterNameExistsAsync(targetName, currentId);

            if (isDuplicate)
            {
                MessageBox.Show($"Tên rạp '{targetName}' đã tồn tại! Vui lòng chọn tên khác.",
                                "Lỗi trùng lặp",
                                MessageBoxButton.OK,
                                MessageBoxImage.Error);
                return; // Dừng lại ngay, không lưu
            }

            // 3. Thực hiện Lưu xuống Database
            try
            {
                if (IsCreatingNew)
                {
                    // === TRƯỜNG HỢP TẠO MỚI ===
                    var t = new Theater
                    {
                        Name = targetName,
                        TotalSeats = CurrentSeats.Count,
                        Status = "Đã hoạt động"
                    };

                    // Gọi Service lưu rạp + danh sách ghế
                    await _dbService.SaveNewTheaterAsync(t, CurrentSeats);

                    MessageBox.Show("Thêm mới thành công!", "Thông báo");

                    // Tải lại dữ liệu và tự động chọn rạp vừa tạo để hiển thị
                    await LoadData();
                    var newTheater = Theaters.FirstOrDefault(x => x.Name == t.Name);
                    if (newTheater != null)
                    {
                        await SelectTheater(newTheater);
                    }
                }
                else if (SelectedTheater != null)
                {
                    // === TRƯỜNG HỢP CẬP NHẬT ===
                    SelectedTheater.Name = targetName;

                    // Gọi Service cập nhật (Xóa ghế cũ, thêm ghế mới)
                    await _dbService.UpdateTheaterStructureAsync(SelectedTheater, CurrentSeats);

                    MessageBox.Show("Cập nhật thành công!", "Thông báo");

                    await LoadData();
                    // Chọn lại rạp đang sửa để hiển thị dữ liệu mới nhất
                    var updatedTheater = Theaters.FirstOrDefault(x => x.TheaterId == SelectedTheater.TheaterId);
                    if (updatedTheater != null) await SelectTheater(updatedTheater);
                }

                // Reset form về trạng thái ban đầu
                ResetToCreateMode();
                await LoadData();
            }
            catch (Exception ex)
            {
                MessageBox.Show("Lỗi hệ thống: " + ex.Message, "Lỗi", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        // Command: Áp dụng hạng ghế cho các ghế đang chọn
        [RelayCommand]
        private async Task ApplyCategory()
        {
            if (IsReadOnlyMode || _selectedUiItems.Count == 0 || SelectedAssignCategoryId == 0) return;

            // Lấy hạng ghế từ ID
            var cat = Categories.FirstOrDefault(c => c.CategoryId == SelectedAssignCategoryId);

            // Duyệt qua các ghế đang chọn và gán ID hạng ghế
            foreach (var item in _selectedUiItems)
            {
                item.SeatData.CategoryId = SelectedAssignCategoryId;
                item.SeatData.SeatCategory = cat;
                item.IsSelected = false;
                item.RefreshView();
            }
            _selectedUiItems.Clear();
        }

        // Command: Xóa rạp
        [RelayCommand]
        private async Task DeleteTheater(object obj)
        {
            if (obj is Theater t && MessageBox.Show($"Xóa {t.Name}?", "Xác nhận", MessageBoxButton.YesNo) == MessageBoxResult.Yes)
            {
                try
                {
                    await _dbService.DeleteTheaterAsync(t.TheaterId);
                    await LoadData();
                    ResetToCreateMode();
                }
                catch { MessageBox.Show("Không thể xóa!"); }
            }
        }

        // Helpers
        private int RowCharToIndex(string row) => string.IsNullOrEmpty(row) ? 0 : (int)(row[0] - 'A');
        private string IndexToRowChar(int index) => ((char)('A' + index)).ToString();
    }

    public class SeatCategoryChangedMessage { public string Value { get; } public SeatCategoryChangedMessage(string v) => Value = v; }
}