using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using StageX_DesktopApp.Models;
using StageX_DesktopApp.Services;
using StageX_DesktopApp.Services.Momo;
using StageX_DesktopApp.Utilities;
using System.Diagnostics;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace StageX_DesktopApp.ViewModels
{
    // --- CÁC CLASS HỖ TRỢ UI ---
    // Item trong giỏ hàng (DataGrid bên phải)
    public class BillSeatItem { public int SeatId { get; set; } public string SeatLabel { get; set; } public decimal Price { get; set; } }
    // Item cho phần chú thích màu sắc
    public class LegendItem { public string Name { get; set; } public SolidColorBrush Color { get; set; } }

    // 1. WRAPPER CHO NÚT SUẤT CHIẾU CAO ĐIỂM
    // Thêm thuộc tính IsSelected để tô viền vàng khi chọn
    public partial class PeakUiItem : ObservableObject
    {
        public PeakPerformanceInfo Data { get; }
        [ObservableProperty] private bool _isSelected;
        public PeakUiItem(PeakPerformanceInfo data) { Data = data; }
    }

    // 2. WRAPPER CHO TỪNG Ô GHẾ TRÊN SƠ ĐỒ
    public partial class TicketSeatUiItem : ObservableObject
    {
        public SeatStatus Data { get; }// Dữ liệu gốc
        [ObservableProperty] private bool _isSelected; // True = Đang chọn vào giỏ (Viền vàng)
        public IRelayCommand SelectCommand { get; } // Lệnh khi click vào ghế
        public string VisualRowChar { get; } // Tên hàng hiển thị (để xử lý logic lối đi)

        public TicketSeatUiItem(SeatStatus data, string visualRow, bool isSelected, Action<TicketSeatUiItem> onSelect)
        {
            Data = data; VisualRowChar = visualRow; IsSelected = isSelected;
            // Command gọi callback onSelect. Disable nếu ghế đã bán (!Data.IsSold)
            SelectCommand = new RelayCommand(() => onSelect(this), () => !Data.IsSold);
        }
        // Hiển thị tên ghế theo hàng ảo
        public string DisplayText => $"{VisualRowChar}{Data.SeatNumber}";
        public string TooltipText => Data.IsSold ? "Đã bán" : $"{Data.CategoryName} (+{Data.BasePrice:N0}đ)";
        public SolidColorBrush BackgroundColor => Data.IsSold ? new SolidColorBrush(Color.FromRgb(80, 80, 80)) : Data.SeatColor;
    }

    // 3. WRAPPER CHO MỘT HÀNG GHẾ (ITEMS CONTROL DỌC)
    public class TicketRowItem
    {
        public string RowName { get; set; }
        public ObservableCollection<object> Items { get; set; }
        public double RowHeight => string.IsNullOrEmpty(RowName) ? 30 : 45;
    }

    // --- VIEWMODEL CHÍNH ---
    public partial class SellTicketViewModel : ObservableObject
    {
        private readonly DatabaseService _dbService;
        // Momo service replaces the old VietQR service for online payment
        private readonly MomoService _momoService;

        // Fields to store the generated MoMo identifiers so we can query status later
        private string _momoOrderId = string.Empty;
        private string _momoRequestId = string.Empty;

        // Fields to store VNPay identifiers to query status later
        private string _vnPayOrderId = string.Empty;
        private string _vnPayTransactionDate = string.Empty;

        // Timer to poll payment status automatically for online payments
        private System.Windows.Threading.DispatcherTimer? _paymentTimer;
        private bool _isCheckingPayment = false;

        // Dữ liệu nguồn cho ComboBox
        [ObservableProperty] private List<ShowInfo> _shows;
        [ObservableProperty] private List<PerformanceInfo> _performances;

        // List suất chiếu cao điểm (Dùng Wrapper PeakUiItem)
        [ObservableProperty] private ObservableCollection<PeakUiItem> _topPerformances;

        // Giỏ hàng và Chú thích
        [ObservableProperty] private ObservableCollection<BillSeatItem> _billSeats = new();
        [ObservableProperty] private ObservableCollection<LegendItem> _legendItems = new();

        // Dữ liệu để vẽ sơ đồ ghế
        [ObservableProperty] private ObservableCollection<TicketRowItem> _seatMap;

        // Trạng thái giao diện
        [ObservableProperty] private bool _isPeakMode = false;
        [ObservableProperty] private ShowInfo _selectedShow;
        [ObservableProperty] private PerformanceInfo _selectedPerformance;
        // Text hiển thị thông tin
        [ObservableProperty] private string _selectedShowText;
        [ObservableProperty] private string _selectedPerfText;
        [ObservableProperty] private string _totalText = "Thành tiền: 0đ";
        // Phần thanh toán
        [ObservableProperty] private string _changeText = "0đ";
        [ObservableProperty] private string _cashGiven;
        [ObservableProperty] private bool _isCashPayment = true;
        [ObservableProperty] private bool _isQrVisible = false;
        [ObservableProperty] private BitmapImage _qrImageSource;

        // Collection of supported online payment providers (used when IsCashPayment == false)
        [ObservableProperty]
        private ObservableCollection<string> _onlineProviders = new() { "MoMo", "VNPay" };

        // Currently selected online provider ("MoMo" or "VNPay")
        [ObservableProperty] private string _selectedOnlineProvider = "MoMo";

        // Online payment status message displayed while waiting for completion
        [ObservableProperty] private string? _onlineStatusMessage;

        // Flag indicating we are waiting for online payment confirmation
        [ObservableProperty] private bool _isOnlineWaiting = false;

        // Biến tạm lưu giá vé cơ bản và ID suất diễn đang chọn
        private int _currentPerfId;
        private decimal _currentPrice;

        public SellTicketViewModel()
        {
            _dbService = new DatabaseService();
            _momoService = new MomoService();
            Task.Run(async () => await InitData());
        }
        // Hàm khởi tạo dữ liệu ban đầu
        private async Task InitData()
        {
            await Application.Current.Dispatcher.InvokeAsync(async () =>
            {
                IsPeakMode = false; IsCashPayment = true;
                Shows = await _dbService.GetActiveShowsAsync();
            });
        }

        // --- LOGIC VẼ SƠ ĐỒ TỰ ĐỘNG (CORE LOGIC) ---
        // Hàm này biến List ghế phẳng từ DB thành cấu trúc Hàng/Cột cho giao diện
        private void BuildVisualSeatMap(List<SeatStatus> seats)
        {
            if (seats == null || seats.Count == 0) { SeatMap = new ObservableCollection<TicketRowItem>(); return; }

            // 1. Tìm danh sách các Hàng có trong dữ liệu (A, C, D...)
            var distinctRows = seats.Where(s => !string.IsNullOrEmpty(s.RowChar))
                                    .Select(s => s.RowChar.Trim().ToUpper()).Distinct()
                                    .OrderBy(r => r.Length).ThenBy(r => r).ToList();

            if (distinctRows.Count == 0) return;
            // Tìm hàng lớn nhất (VD: D -> Index 3) để biết vòng lặp chạy đến đâu
            string maxRowChar = distinctRows.Last();
            int maxRowIndex = (string.IsNullOrEmpty(maxRowChar) ? 0 : (int)(maxRowChar[0] - 'A'));
            // Tìm số cột lớn nhất
            int maxCol = seats.Max(s => s.SeatNumber);

            var newMap = new ObservableCollection<TicketRowItem>();
            int visualRowCounter = 0;
            // 2. Vòng lặp quét từ A -> Hàng cuối cùng
            for (int i = 0; i <= maxRowIndex; i++)
            {
                string physicalRowChar = ((char)('A' + i)).ToString();
                // Lấy tất cả ghế thuộc hàng này
                var seatsInRow = seats.Where(s => s.RowChar == physicalRowChar).ToList();

                if (seatsInRow.Any())
                {
                    // == TRƯỜNG HỢP CÓ GHẾ ==
                    // Đặt tên hiển thị mới (VD: C -> B nếu hàng B bị xóa làm lối đi)
                    string visualLabel = ((char)('A' + visualRowCounter++)).ToString();
                    var rowItem = new TicketRowItem { RowName = visualLabel, Items = new ObservableCollection<object>() };
                    // Quét từng cột từ 1 -> MaxCol
                    for (int c = 1; c <= maxCol; c++)
                    {
                        var seat = seatsInRow.FirstOrDefault(s => s.SeatNumber == c);
                        if (seat != null)
                        {
                            // Có ghế -> Tạo nút ghế
                            // Kiểm tra xem ghế này đã có trong giỏ hàng chưa để tô viền vàng
                            bool isSelected = BillSeats.Any(b => b.SeatId == seat.SeatId);
                            var uiItem = new TicketSeatUiItem(seat, visualLabel, isSelected, OnSeatClicked);
                            rowItem.Items.Add(uiItem);
                        }
                        else rowItem.Items.Add(null);
                    }
                    newMap.Add(rowItem);
                }
                else
                {
                    // == TRƯỜNG HỢP HÀNG BỊ XÓA (LỐI ĐI) ==
                    // Tạo hàng rỗng, không tăng visualRowCounter
                    newMap.Add(new TicketRowItem { RowName = "", Items = new ObservableCollection<object>() });
                }
            }
            SeatMap = newMap;
        }
        // Hàm xử lý khi Click vào một ghế
        private void OnSeatClicked(TicketSeatUiItem item)
        {
            if (item.Data.IsSold) return; // Không cho phép chọn ghế đã bán
            // Kiểm tra xem ghế đã có trong giỏ chưa
            var existing = BillSeats.FirstOrDefault(x => x.SeatId == item.Data.SeatId);
            if (existing != null)
            {
                // Nếu đã chọn thì bỏ chọn
                BillSeats.Remove(existing);
                item.IsSelected = false;
            }
            else
            {
                // Thêm ghế vào hóa đơn với giá = giá ghế + phụ thu suất
                BillSeats.Add(new BillSeatItem
                {
                    SeatId = item.Data.SeatId,
                    SeatLabel = item.DisplayText,
                    Price = item.Data.BasePrice + _currentPrice
                });
                item.IsSelected = true;
            }
            UpdateTotal();
        }


        // --- LOGIC CHỌN SUẤT DIỄN ---
        // Chuyển đổi chế độ (Mặc định <-> Cao điểm)
        [RelayCommand]
        private async Task SwitchMode(string mode)
        {
            IsPeakMode = (mode == "Peak");
            ClearAllData();

            if (IsPeakMode)
            {
                IsCashPayment = false; // Mặc định Chuyển khoản cho nhanh
                var tops = await _dbService.GetTopPerformancesAsync();
                // Tạo danh sách Wrapper cho nút bấm (để có tính năng tô viền)
                var list = new List<PeakUiItem>();
                foreach (var p in tops) list.Add(new PeakUiItem(p));
                while (list.Count < 3) list.Add(new PeakUiItem(new PeakPerformanceInfo { performance_id = 0 }));
                TopPerformances = new ObservableCollection<PeakUiItem>(list);
            }
            else
            {
                IsCashPayment = true;
                Shows = await _dbService.GetActiveShowsAsync(); // Gọi proc_active_shows
            }
        }

        // Xử lý khi bấm nút ở Chế độ Cao điểm
        [RelayCommand]
        private void SelectPeakPerformance(PeakUiItem item)
        {
            if (item == null || item.Data.performance_id == 0) return;

            // Tô viền vàng cho nút vừa chọn
            foreach (var p in TopPerformances) p.IsSelected = false;
            item.IsSelected = true;

            SelectedShowText = $"Vở diễn: {item.Data.show_title}";
            SelectPerformanceLogic(item.Data.performance_id, item.Data.price, item.Data.Display);
        }
        // Xử lý khi chọn Vở diễn từ ComboBox (Mode Thường)
        partial void OnSelectedShowChanged(ShowInfo value)
        {
            if (value != null)
            {
                SelectedShowText = $"Vở diễn: {value.title}"; LoadPerformances(value.show_id);
            }
        }
        private async void LoadPerformances(int showId)
            => Performances = await _dbService.GetPerformancesByShowAsync(showId);

        // Xử lý khi chọn Suất diễn từ ComboBox (Mode Thường)
        partial void OnSelectedPerformanceChanged(PerformanceInfo value)
        {
            if (value != null)
                SelectPerformanceLogic(value.performance_id, value.price, value.Display);
        }

        // Logic chung khi chọn suất diễn (Tải ghế + Tạo chú thích)
        private async void SelectPerformanceLogic(int perfId, decimal price, string display)
        {
            _currentPerfId = perfId; _currentPrice = price; SelectedPerfText = $"Suất chiếu: {display}";
            BillSeats.Clear(); UpdateTotal();
            try
            {
                // Tải danh sách ghế từ DB
                var seats = await _dbService.GetSeatsWithStatusAsync(perfId);

                // Gọi hàm vẽ sơ đồ 
                BuildVisualSeatMap(seats);

                // Tạo danh sách chú thích (Legend) - Group by Tên & Giá để không bị lặp
                var distinctCats = seats.Where(s => !string.IsNullOrEmpty(s.CategoryName))
                                        .GroupBy(s => new { s.CategoryName, s.BasePrice })
                                        .Select(g => g.First())
                                        .OrderBy(x => x.BasePrice);

                var legends = new List<LegendItem>();
                foreach (var cat in distinctCats) legends.Add(new LegendItem { Name = $"{cat.CategoryName} (+{cat.BasePrice:N0}đ)", Color = cat.SeatColor });
                LegendItems = new ObservableCollection<LegendItem>(legends);
            }
            catch (Exception ex) { MessageBox.Show("Lỗi tải dữ liệu: " + ex.Message); }
        }

        // --- LOGIC THANH TOÁN ---
        // Khi nhập tiền khách đưa -> Tính lại tiền thừa và QR
        partial void OnCashGivenChanged(string value) => UpdateTotal();

        private async void UpdateTotal()
        {
            decimal total = BillSeats.Sum(x => x.Price);
            TotalText = $"Thành tiền: {total:N0}đ";
            // Calculate change when cash is provided
            if (decimal.TryParse(CashGiven, out decimal given))
            {
                decimal change = given - total;
                ChangeText = change >= 0 ? $"{change:N0}đ" : $"-{Math.Abs(change):N0}đ";
            }
            else
            {
                ChangeText = "0đ";
            }

            // Reset QR and online status
            IsQrVisible = false;
            QrImageSource = null;
            OnlineStatusMessage = null;
            IsOnlineWaiting = false;
            // Stop existing polling timer
            StopPaymentTimer();

            if (total <= 0)
            {
                return;
            }

            // If cash payment, no further action is required
            if (IsCashPayment)
            {
                return;
            }

            // Online payment: depending on selected provider
            if (SelectedOnlineProvider == "MoMo")
            {
                var result = await _momoService.GeneratePaymentAsync(total, "Thanh toan ve STAGEX");
                _momoOrderId = result.OrderId;
                _momoRequestId = result.RequestId;
                if (result.Image == null)
                {
                    MessageBox.Show("Không thể tạo mã QR MoMo. Vui lòng kiểm tra kết nối mạng hoặc thử lại.");
                    return;
                }
                QrImageSource = result.Image;
                IsQrVisible = true;
                OnlineStatusMessage = "Đang chờ thanh toán MoMo...";
                IsOnlineWaiting = true;
                StartPaymentTimer(async () =>
                {
                    string queryRequestId = Guid.NewGuid().ToString("N");
                    bool paid = await _momoService.QueryPaymentAsync(_momoOrderId, queryRequestId);
                    if (paid)
                    {
                        await Application.Current.Dispatcher.InvokeAsync(async () => await FinalizeOnlineOrder(total, "Chuyển khoản"));
                    }
                });
            }
        }
        [RelayCommand]
        private void SelectPayment(string method)
        {
            // Only two main methods: Cash or Transfer
            IsCashPayment = method == "Cash";
            // When switching to cash, clear any online status
            if (IsCashPayment)
            {
                OnlineStatusMessage = null;
                IsOnlineWaiting = false;
            }
            UpdateTotal();
        }
        // Lưu đơn hàng khi thanh toán bằng tiền mặt.
        // Đối với thanh toán chuyển khoản (MoMo/VNPay), việc lưu đơn hàng sẽ được
        // thực hiện tự động khi xác nhận thành công, do đó nút lưu chỉ áp dụng cho cash.
        [RelayCommand]
        private async Task SaveOrder()
        {
            // Ensure we have selected a performance and at least one seat
            if (_currentPerfId == 0 || !BillSeats.Any())
            {
                MessageBox.Show("Vui lòng chọn suất và ghế!");
                return;
            }

            decimal total = BillSeats.Sum(x => x.Price);

            // Only cash payments are manually saved. Online payments will auto finalize.
            if (!IsCashPayment)
            {
                MessageBox.Show("Đang xử lý thanh toán chuyển khoản. Vui lòng đợi xác nhận tự động.");
                return;
            }

            // Validate cash amount (must be multiple of 1000 and >= total)
            if (!decimal.TryParse(CashGiven, out decimal given) || given % 1000 != 0 || given < total)
            {
                MessageBox.Show("Tiền không hợp lệ hoặc thiếu!");
                return;
            }

            try
            {
                int bookingId = await _dbService.CreateBookingPOSAsync(null, _currentPerfId, total, AuthSession.CurrentUser?.UserId ?? 0);
                if (bookingId > 0)
                {
                    await _dbService.CreatePaymentAndTicketsAsync(bookingId, total, "Tiền mặt", BillSeats.Select(s => s.SeatId).ToList());
                    MessageBox.Show("Thanh toán thành công!");
                    // Refresh the seat map and data
                    if (IsPeakMode) await SwitchMode("Peak"); else SelectPerformanceLogic(_currentPerfId, _currentPrice, SelectedPerfText.Replace("Suất chiếu: ", ""));
                    // Clear selections after saving
                    BillSeats.Clear();
                    UpdateTotal();
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show("Lỗi: " + ex.Message);
            }
        }

        private void ClearAllData()
        {
            SelectedShow = null; SelectedPerformance = null; _currentPerfId = 0; _currentPrice = 0; SelectedShowText = ""; SelectedPerfText = ""; BillSeats.Clear(); LegendItems.Clear(); CashGiven = ""; UpdateTotal(); SeatMap = null;
        }

        /// <summary>
        /// Invoked when the SelectedOnlineProvider property changes.  When online payment
        /// is selected, this will refresh the payment details (QR code or URL).
        /// </summary>
        partial void OnSelectedOnlineProviderChanged(string value)
        {
            if (!IsCashPayment)
            {
                UpdateTotal();
            }
        }

        /// <summary>
        /// Start the dispatcher timer to periodically call the provided async action.
        /// This timer runs every 3 seconds until stopped or until the action triggers a finalize.
        /// </summary>
        private void StartPaymentTimer(Func<Task> asyncAction)
        {
            StopPaymentTimer();
            _paymentTimer = new System.Windows.Threading.DispatcherTimer();
            _paymentTimer.Interval = TimeSpan.FromSeconds(3);
            _paymentTimer.Tick += async (s, e) =>
            {
                // Prevent overlapping calls
                if (_isCheckingPayment) return;
                _isCheckingPayment = true;
                try
                {
                    _ = asyncAction();
                }
                finally
                {
                    _isCheckingPayment = false;
                }
            };
            _paymentTimer.Start();
        }

        /// <summary>
        /// Stop and dispose the payment polling timer if it exists.
        /// </summary>
        private void StopPaymentTimer()
        {
            if (_paymentTimer != null)
            {
                _paymentTimer.Stop();
                _paymentTimer = null;
            }
        }

        /// <summary>
        /// Finalize an online order after a successful payment. This creates the booking,
        /// payment and tickets, refreshes the seat map, displays a success message
        /// and clears the current selection.
        /// </summary>
        /// <param name="total">Total amount of the order</param>
        /// <param name="method">Payment method name to store in DB</param>
        private async Task FinalizeOnlineOrder(decimal total, string method)
        {
            // Stop polling once we finalize
            StopPaymentTimer();
            // Prevent duplicate finalization
            if (_currentPerfId == 0 || !BillSeats.Any()) return;
            try
            {
                int bookingId = await _dbService.CreateBookingPOSAsync(null, _currentPerfId, total, AuthSession.CurrentUser?.UserId ?? 0);
                if (bookingId > 0)
                {
                    await _dbService.CreatePaymentAndTicketsAsync(bookingId, total, method, BillSeats.Select(s => s.SeatId).ToList());
                    // Show a message box to inform the user of successful online payment.
                    Application.Current.Dispatcher.Invoke(() =>
                    {
                        string provider = SelectedOnlineProvider;
                        string message = provider == "MoMo" ? "Thanh toán MoMo thành công!" : "Thanh toán VNPay thành công!";
                        MessageBox.Show(message, "Thành công", MessageBoxButton.OK, MessageBoxImage.Information);
                    });
                    // Update UI messages in the view as well
                    OnlineStatusMessage = "Thanh toán thành công!";
                    IsOnlineWaiting = false;
                    IsQrVisible = false;
                    // Refresh seat map and data
                    if (IsPeakMode) await SwitchMode("Peak"); else SelectPerformanceLogic(_currentPerfId, _currentPrice, SelectedPerfText.Replace("Suất chiếu: ", ""));
                    // Clear selections
                    BillSeats.Clear();
                    UpdateTotal();
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show("Lỗi khi lưu đơn hàng: " + ex.Message);
            }
        }
    }
}