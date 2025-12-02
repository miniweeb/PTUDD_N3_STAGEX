using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using StageX_DesktopApp.Models;
using StageX_DesktopApp.Services;
using StageX_DesktopApp.Utilities;
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
    // --- CÁC CLASS HỖ TRỢ ---
    public class BillSeatItem { public int SeatId { get; set; } public string SeatLabel { get; set; } public decimal Price { get; set; } }
    public class LegendItem { public string Name { get; set; } public SolidColorBrush Color { get; set; } }

    // 1. Wrapper cho Nút Suất chiếu Cao điểm (Viền vàng)
    public partial class PeakUiItem : ObservableObject
    {
        public PeakPerformanceInfo Data { get; }
        [ObservableProperty] private bool _isSelected;
        public PeakUiItem(PeakPerformanceInfo data) { Data = data; }
    }

    // 2. Wrapper cho Ghế (Sơ đồ)
    public partial class TicketSeatUiItem : ObservableObject
    {
        public SeatStatus Data { get; }
        [ObservableProperty] private bool _isSelected;
        public IRelayCommand SelectCommand { get; }
        public string VisualRowChar { get; }

        public TicketSeatUiItem(SeatStatus data, string visualRow, bool isSelected, Action<TicketSeatUiItem> onSelect)
        {
            Data = data; VisualRowChar = visualRow; IsSelected = isSelected;
            SelectCommand = new RelayCommand(() => onSelect(this), () => !Data.IsSold);
        }
        public string DisplayText => $"{VisualRowChar}{Data.SeatNumber}";
        public string TooltipText => Data.IsSold ? "Đã bán" : $"{Data.CategoryName} (+{Data.BasePrice:N0}đ)";
        public SolidColorBrush BackgroundColor => Data.IsSold ? new SolidColorBrush(Color.FromRgb(80, 80, 80)) : Data.SeatColor;
    }

    // 3. Wrapper cho Hàng ghế
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
        private readonly VietQRService _qrService;

        [ObservableProperty] private List<ShowInfo> _shows;
        [ObservableProperty] private List<PerformanceInfo> _performances;

        // List dùng Wrapper PeakUiItem
        [ObservableProperty] private ObservableCollection<PeakUiItem> _topPerformances;

        [ObservableProperty] private ObservableCollection<BillSeatItem> _billSeats = new();
        [ObservableProperty] private ObservableCollection<LegendItem> _legendItems = new();

        // Dữ liệu sơ đồ ghế MVVM
        [ObservableProperty] private ObservableCollection<TicketRowItem> _seatMap;

        [ObservableProperty] private bool _isPeakMode = false;
        [ObservableProperty] private ShowInfo _selectedShow;
        [ObservableProperty] private PerformanceInfo _selectedPerformance;
        [ObservableProperty] private string _selectedShowText;
        [ObservableProperty] private string _selectedPerfText;
        [ObservableProperty] private string _totalText = "Thành tiền: 0đ";
        [ObservableProperty] private string _changeText = "0đ";
        [ObservableProperty] private string _cashGiven;
        [ObservableProperty] private bool _isCashPayment = true;
        [ObservableProperty] private bool _isQrVisible = false;
        [ObservableProperty] private BitmapImage _qrImageSource;

        private int _currentPerfId;
        private decimal _currentPrice;

        public SellTicketViewModel()
        {
            _dbService = new DatabaseService();
            _qrService = new VietQRService();
            Task.Run(async () => await InitData());
        }

        private async Task InitData()
        {
            await Application.Current.Dispatcher.InvokeAsync(async () =>
            {
                IsPeakMode = false; IsCashPayment = true;
                Shows = await _dbService.GetActiveShowsAsync();
            });
        }

        // --- LOGIC VẼ SƠ ĐỒ  ---
        private void BuildVisualSeatMap(List<SeatStatus> seats)
        {
            if (seats == null || seats.Count == 0) { SeatMap = new ObservableCollection<TicketRowItem>(); return; }

            var distinctRows = seats.Where(s => !string.IsNullOrEmpty(s.RowChar))
                                    .Select(s => s.RowChar.Trim().ToUpper()).Distinct()
                                    .OrderBy(r => r.Length).ThenBy(r => r).ToList();

            if (distinctRows.Count == 0) return;

            string maxRowChar = distinctRows.Last();
            int maxRowIndex = (string.IsNullOrEmpty(maxRowChar) ? 0 : (int)(maxRowChar[0] - 'A'));
            int maxCol = seats.Max(s => s.SeatNumber);

            var newMap = new ObservableCollection<TicketRowItem>();
            int visualRowCounter = 0;

            for (int i = 0; i <= maxRowIndex; i++)
            {
                string physicalRowChar = ((char)('A' + i)).ToString();
                var seatsInRow = seats.Where(s => s.RowChar == physicalRowChar).ToList();

                if (seatsInRow.Any())
                {
                    string visualLabel = ((char)('A' + visualRowCounter++)).ToString();
                    var rowItem = new TicketRowItem { RowName = visualLabel, Items = new ObservableCollection<object>() };

                    for (int c = 1; c <= maxCol; c++)
                    {
                        var seat = seatsInRow.FirstOrDefault(s => s.SeatNumber == c);
                        if (seat != null)
                        {
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
                    newMap.Add(new TicketRowItem { RowName = "", Items = new ObservableCollection<object>() });
                }
            }
            SeatMap = newMap;
        }

        private void OnSeatClicked(TicketSeatUiItem item)
        {
            if (item.Data.IsSold) return; // Không cho phép chọn ghế đã bán

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


        // --- LOGIC CHỌN SUẤT (CAO ĐIỂM & THƯỜNG) ---

        [RelayCommand]
        private async Task SwitchMode(string mode)
        {
            IsPeakMode = (mode == "Peak");
            ClearAllData();

            if (IsPeakMode)
            {
                IsCashPayment = false;
                var tops = await _dbService.GetTopPerformancesAsync(); // Gọi proc_top3_nearest_performances_extended
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

        partial void OnSelectedShowChanged(ShowInfo value) { if (value != null) { SelectedShowText = $"Vở diễn: {value.title}"; LoadPerformances(value.show_id); } }
        private async void LoadPerformances(int showId) => Performances = await _dbService.GetPerformancesByShowAsync(showId);
        partial void OnSelectedPerformanceChanged(PerformanceInfo value) { if (value != null) SelectPerformanceLogic(value.performance_id, value.price, value.Display); }

        private async void SelectPerformanceLogic(int perfId, decimal price, string display)
        {
            _currentPerfId = perfId; _currentPrice = price; SelectedPerfText = $"Suất chiếu: {display}";
            BillSeats.Clear(); UpdateTotal();
            try
            {
                var seats = await _dbService.GetSeatsWithStatusAsync(perfId);

                // Gọi hàm vẽ sơ đồ (Lúc trước bị thiếu dòng này)
                BuildVisualSeatMap(seats);

                // Tạo chú thích (Fix lỗi lặp)
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

        partial void OnCashGivenChanged(string value) => UpdateTotal();
        private async void UpdateTotal()
        {
            decimal total = BillSeats.Sum(x => x.Price); TotalText = $"Thành tiền: {total:N0}đ";
            if (decimal.TryParse(CashGiven, out decimal given)) { decimal change = given - total; ChangeText = change >= 0 ? $"{change:N0}đ" : $"-{Math.Abs(change):N0}đ"; } else ChangeText = "0đ";
            if (!IsCashPayment && total > 0) { IsQrVisible = true; QrImageSource = await _qrService.GenerateQrCodeAsync((int)total, "Thanh toan ve STAGEX"); } else { IsQrVisible = false; QrImageSource = null; }
        }
        [RelayCommand] private void SelectPayment(string method) { IsCashPayment = (method == "Cash"); UpdateTotal(); }
        [RelayCommand]
        private async Task SaveOrder()
        {
            if (_currentPerfId == 0 || !BillSeats.Any())
            {
                MessageBox.Show("Vui lòng chọn suất và ghế!");
                return;
            }
            decimal total = BillSeats.Sum(x => x.Price);

            // Kiểm tra điều kiện thanh toán tiền mặt
            if (IsCashPayment)
            {
                if (!decimal.TryParse(CashGiven, out decimal given) || given % 1000 != 0 || given < total)
                {
                    MessageBox.Show("Tiền không hợp lệ hoặc thiếu!");
                    return;
                }
            }

            try
            {
                // 1. Tạo booking – proc_create_booking_pos
                int bookingId = await _dbService.CreateBookingPOSAsync(null, _currentPerfId, total, AuthSession.CurrentUser?.UserId ?? 0);
                if (bookingId > 0)
                {
                    // 2. Tạo payment và vé – proc_create_payment và proc_create_ticket
                    await _dbService.CreatePaymentAndTicketsAsync(
                        bookingId,
                        total,
                        IsCashPayment ? "Tiền mặt" : "Chuyển khoản",
                        BillSeats.Select(s => s.SeatId).ToList());
                    MessageBox.Show("Thanh toán thành công!");
                    // Refresh lại sơ đồ ghế và dữ liệu
                    if (IsPeakMode) SwitchMode("Peak");
                    else SelectPerformanceLogic(_currentPerfId, _currentPrice, SelectedPerfText.Replace("Suất chiếu: ", ""));
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show("Lỗi: " + ex.Message);
            }
        }

        private void ClearAllData() { SelectedShow = null; SelectedPerformance = null; _currentPerfId = 0; _currentPrice = 0; SelectedShowText = ""; SelectedPerfText = ""; BillSeats.Clear(); LegendItems.Clear(); CashGiven = ""; UpdateTotal(); SeatMap = null; }
    }
}