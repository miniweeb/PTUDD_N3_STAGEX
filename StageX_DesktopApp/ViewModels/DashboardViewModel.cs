using CommunityToolkit.Mvvm.ComponentModel;
using LiveCharts;
using LiveCharts.Wpf;
using Microsoft.EntityFrameworkCore;
using StageX_DesktopApp.Data;
using StageX_DesktopApp.Models;
using StageX_DesktopApp.Services;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Windows.Media;

namespace StageX_DesktopApp.ViewModels
{
    public partial class DashboardViewModel : ObservableObject
    {
        private readonly DatabaseService _dbService;

        // --- CÁC BIẾN KPI (KEY PERFORMANCE INDICATORS) ---
        // Các biến này binding trực tiếp lên 4 thẻ số liệu trên cùng của Dashboard
        [ObservableProperty] private string _revenueText = "0đ"; // Tổng doanh thu
        [ObservableProperty] private string _orderText = "0"; // Tổng số đơn hàng
        [ObservableProperty] private string _showText = "0"; // Tổng số vở diễn
        [ObservableProperty] private string _genreText = "0"; // Tổng số thể loại

        // --- BIỂU ĐỒ DOANH THU ---
        // SeriesCollection chứa các đường vẽ (LineSeries)
        [ObservableProperty] private SeriesCollection _revenueSeries;
        // Mảng chứa nhãn trục hoành (Tháng/Năm)
        [ObservableProperty] private string[] _revenueLabels;
        // Formatter để định dạng số tiền trên trục tung (VD: 1,000,000)
        public Func<double, string> RevenueFormatter { get; set; } = value => value.ToString("N0");

        // --- BIỂU ĐỒ TÌNH TRẠNG VÉ ---
        [ObservableProperty] private SeriesCollection _occupancySeries;
        [ObservableProperty] private List<string> _occupancyLabels;

        // Biến lưu trạng thái bộ lọc hiện tại của biểu đồ vé (week/month/year)
        // Dùng để xử lý sự kiện click vào cột biểu đồ
        public string CurrentOccupancyFilter { get; set; } = "week";

        // --- BIỂU ĐỒ TRÒN & BẢNG TOP 5 ---
        [ObservableProperty] private SeriesCollection _pieSeries; // Dữ liệu biểu đồ tròn
        [ObservableProperty] private List<TopShowModel> _topShowsList; // Dữ liệu bảng Top 5

        public DashboardViewModel()
        {
            _dbService = new DatabaseService();

            // Khởi tạo collection rỗng
            RevenueSeries = new SeriesCollection();
            OccupancySeries = new SeriesCollection();
            PieSeries = new SeriesCollection();
            TopShowsList = new List<TopShowModel>();
        }

        // Hàm điều phối chung: Gọi lần lượt các hàm tải dữ liệu thành phần
        public async Task LoadData()
        {
            await LoadSummary();       // 1. Tải 4 thẻ KPI
            await LoadRevenueChart();  // 2. Tải biểu đồ doanh thu
            await LoadOccupancy("week"); // 3. Tải biểu đồ vé (mặc định theo tuần)
            await LoadPieChart();      // 4. Tải biểu đồ tròn
            await LoadTopShows();      // 5. Tải danh sách top 5
        }

        // 1. Tải dữ liệu tổng quan (KPI Cards)
        private async Task LoadSummary()
        {
            // Gọi Stored Procedure lấy số liệu tổng hợp
            var sum = await _dbService.GetDashboardSummaryAsync();
            if (sum != null)
            {
                // Cập nhật lên giao diện, định dạng tiền tệ và số lượng
                RevenueText = $"{sum.total_revenue:N0}đ";
                OrderText = sum.total_bookings.ToString();
                ShowText = sum.total_shows.ToString();
                GenreText = sum.total_genres.ToString();
            }
        }

        // 2. Tải dữ liệu cho Biểu đồ Doanh thu (Line Chart) và thực hiện DỰ BÁO (Forecast)
        private async Task LoadRevenueChart()
        {
            try
            {
                // Bước 1: Lấy dữ liệu thô từ DB (Tháng, Doanh thu)
                var rawData = await _dbService.GetRevenueMonthlyAsync();

                var historyData = new List<RevenueInput>();

                // Bước 2: Chuẩn hóa dữ liệu
                // Dữ liệu từ DB có thể bị thiếu tháng (VD: có tháng 1, tháng 3 nhưng thiếu tháng 2)
                // Cần lấp đầy các tháng thiếu bằng giá trị 0 để biểu đồ và thuật toán dự báo chạy đúng.
                if (rawData.Any())
                {
                    // Parse chuỗi tháng (MM/yyyy) sang DateTime
                    var parsed = rawData.Select(r => {
                        if (DateTime.TryParse(r.month, out DateTime dt))
                            return new RevenueInput { Date = dt, TotalRevenue = (float)r.total_revenue };
                        if (DateTime.TryParseExact(r.month, "MM/yyyy", null, System.Globalization.DateTimeStyles.None, out DateTime dt2))
                            return new RevenueInput { Date = dt2, TotalRevenue = (float)r.total_revenue };
                        return null;
                    }).Where(x => x != null).OrderBy(x => x.Date).ToList();

                    if (parsed.Any())
                    {
                        // Lấp đầy các tháng còn thiếu
                        var minDate = parsed.First().Date;
                        var maxDate = parsed.Last().Date;
                        for (var d = minDate; d <= maxDate; d = d.AddMonths(1))
                        {
                            var existing = parsed.FirstOrDefault(x => x.Date.Year == d.Year && x.Date.Month == d.Month);
                            historyData.Add(existing ?? new RevenueInput { Date = d, TotalRevenue = 0 });
                        }
                    }
                }

                // Bước 3: Gọi ML.NET dự báo doanh thu tương lai
                // Chỉ dự báo nếu có đủ dữ liệu lịch sử (>= 6 tháng)
                bool canForecast = historyData.Count >= 6;
                int horizon = 3;
                RevenueForecast prediction = null;

                if (canForecast)
                {
                    try
                    {
                        var mlService = new RevenueForecastingService();
                        prediction = mlService.Predict(historyData, horizon);
                    }
                    catch { }
                }

                // Bước 4: Chuẩn bị dữ liệu vẽ biểu đồ
                var chartValuesHistory = new ChartValues<double>();
                var chartValuesForecast = new ChartValues<double>();
                var labels = new List<string>();

                foreach (var item in historyData)
                {
                    chartValuesHistory.Add(item.TotalRevenue);
                    chartValuesForecast.Add(double.NaN);
                    labels.Add(item.Date.ToString("MM/yy"));
                }

                // 4b. Vẽ đường dự báo nối tiếp (nếu có)
                if (prediction != null)
                {
                    // Nối điểm cuối của lịch sử vào đầu của dự báo để đường liền mạch
                    chartValuesForecast.RemoveAt(chartValuesForecast.Count - 1);
                    chartValuesForecast.Add(historyData.Last().TotalRevenue);

                    DateTime lastDate = historyData.Last().Date;
                    for (int i = 0; i < horizon; i++)
                    {
                        float val = prediction.ForecastedRevenue[i];
                        if (val < 0) val = 0;
                        chartValuesForecast.Add(val);
                        // Thêm nhãn cho các tháng tương lai
                        labels.Add(lastDate.AddMonths(i + 1).ToString("MM/yy"));
                    }
                }

                // Bước 5: Cấu hình Series cho LiveCharts
                RevenueSeries = new SeriesCollection
                {
                    new LineSeries
                    {
                        Title = "Thực tế",
                        Values = chartValuesHistory,
                        Stroke = new SolidColorBrush(Color.FromRgb(255, 193, 7)),
                        Fill = Brushes.Transparent,
                        PointGeometrySize = 10
                    }
                };
                if (prediction != null)
                {
                    RevenueSeries.Add(new LineSeries
                    {
                        Title = "Dự báo",
                        Values = chartValuesForecast,
                        Stroke = Brushes.Cyan,
                        Fill = Brushes.Transparent,
                        PointGeometrySize = 10,
                        StrokeDashArray = new DoubleCollection { 4 }
                    });
                }
                RevenueLabels = labels.ToArray();
            }
            catch (Exception ex) { System.Diagnostics.Debug.WriteLine("Revenue Error: " + ex.Message); }
        }

        // 3. Tải dữ liệu cho Biểu đồ Lấp đầy (Occupancy) - Stacked Column
        // Hàm này xử lý logic hiển thị theo Tuần, Tháng hoặc Năm
        public async Task LoadOccupancy(string filter)
        {
            CurrentOccupancyFilter = filter;

            // Gọi DB lấy dữ liệu theo bộ lọc
            var data = await _dbService.GetOccupancyDataAsync(filter);
            var sold = new ChartValues<double>();
            var unsold = new ChartValues<double>();
            var labels = new List<string>();

            // Giả lập mốc thời gian hiện tại
            var anchorDate = new DateTime(2025, 11, 30);
            var culture = System.Globalization.CultureInfo.InvariantCulture;

            // Xử lý logic hiển thị trục hoành tùy theo loại lọc
            if (filter == "year")
            {
                foreach (var item in data)
                {
                    labels.Add(item.period);
                    sold.Add((double)item.sold_tickets);
                    unsold.Add((double)item.unsold_tickets);
                }
            }
            else if (filter == "month")
            {
                // Logic: Hiển thị 4 tuần gần nhất
                var cal = culture.Calendar;
                var currentWeek = cal.GetWeekOfYear(anchorDate, System.Globalization.CalendarWeekRule.FirstDay, DayOfWeek.Monday);
                for (int i = 3; i >= 0; i--)
                {
                    int weekNum = currentWeek - i;
                    if (weekNum <= 0) weekNum += 52;
                    string key = $"Tuần {weekNum}";

                    var item = data.FirstOrDefault(x => x.period == key);
                    double s = item != null ? (double)item.sold_tickets : 0;
                    double u = item != null ? (double)item.unsold_tickets : 0; // SỬA: Lấy số liệu thật

                    labels.Add(key);
                    sold.Add(s);
                    unsold.Add(u); // SỬA: Add biến u
                }
            }
            else // week
            {
                // Logic: Hiển thị 7 ngày gần nhất
                for (int i = 6; i >= 0; i--)
                {
                    var d = anchorDate.AddDays(-i);
                    string key = d.ToString("dd/MM", culture);

                    var item = data.FirstOrDefault(x => x.period == key);
                    double s = item != null ? (double)item.sold_tickets : 0;
                    double u = item != null ? (double)item.unsold_tickets : 0; // SỬA: Lấy số liệu thật

                    labels.Add(key);
                    sold.Add(s);
                    unsold.Add(u); // SỬA: Add biến u
                }
            }

            // Cấu hình 2 cột chồng lên nhau
            OccupancySeries = new SeriesCollection
            {
                // Cột Vé đã bán (Màu vàng)
                new StackedColumnSeries { Title = "Đã bán", Values = sold, Fill = new SolidColorBrush(Color.FromRgb(255,193,7)), DataLabels = true },
                // Cột Vé còn trống (Màu xám tối)
                new StackedColumnSeries { Title = "Còn trống", Values = unsold, Fill = new SolidColorBrush(Color.FromRgb(60,60,60)), DataLabels = true, Foreground = Brushes.White }
            };
            OccupancyLabels = labels;
        }

        // 4. Tải dữ liệu Biểu đồ Tròn (Pie Chart) - Tỷ trọng vé bán theo vở diễn
        // Hỗ trợ lọc theo khoảng thời gian (start, end)
        public async Task LoadPieChart(DateTime? start = null, DateTime? end = null)
        {
            // Gọi DB lấy danh sách Top 5 vở diễn bán chạy nhất trong khoảng thời gian
            var topShows = await _dbService.GetTopShowsAsync(start, end);
            var series = new SeriesCollection();

            // Duyệt qua từng vở diễn để tạo các lát cắt (Slice)
            foreach (var show in topShows)
            {
                // Tạo từng PieSeries cho mỗi vở diễn
                series.Add(new PieSeries
                {
                    Title = show.show_name,
                    // Giá trị của slice là số lượng vé bán
                    Values = new ChartValues<double> { (double)show.sold_tickets },
                    DataLabels = true,
                    // Hiển thị nhãn số liệu dạng phần trăm (VD: 30%)
                    LabelPoint = point => $"{point.Participation:P0}"
                });
            }
            // Gán dữ liệu vào biến Binding để View cập nhật
            PieSeries = series;
        }

        // 5. Tải danh sách Top 5 Vở diễn (Bảng xếp hạng chi tiết bên cạnh biểu đồ tròn)
        public async Task LoadTopShows(DateTime? start = null, DateTime? end = null)
        {
            // Lấy dữ liệu tương tự như biểu đồ tròn
            var shows = await _dbService.GetTopShowsAsync(start, end);

            // Chuyển đổi dữ liệu sang Model hiển thị (TopShowModel)
            // Thêm số thứ tự (Index) để hiển thị trên bảng (1, 2, 3...)
            TopShowsList = shows.Select((s, i) => new TopShowModel
            {
                Index = i + 1, // Số thứ tự bắt đầu từ 1 (vì index mảng từ 0)
                show_name = s.show_name,
                sold_tickets = s.sold_tickets
            }).ToList();
        }
    }
}