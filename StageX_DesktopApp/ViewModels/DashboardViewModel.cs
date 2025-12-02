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

        // --- CÁC BIẾN KPI ---
        [ObservableProperty] private string _revenueText = "0đ";
        [ObservableProperty] private string _orderText = "0";
        [ObservableProperty] private string _showText = "0";
        [ObservableProperty] private string _genreText = "0";

        // --- BIỂU ĐỒ DOANH THU ---
        [ObservableProperty] private SeriesCollection _revenueSeries;
        [ObservableProperty] private string[] _revenueLabels;
        public Func<double, string> RevenueFormatter { get; set; } = value => value.ToString("N0");

        // --- BIỂU ĐỒ TÌNH TRẠNG VÉ (OCCUPANCY) ---
        [ObservableProperty] private SeriesCollection _occupancySeries;
        [ObservableProperty] private List<string> _occupancyLabels;

        public string CurrentOccupancyFilter { get; set; } = "week";

        // --- BIỂU ĐỒ TRÒN & BẢNG TOP 5 ---
        [ObservableProperty] private SeriesCollection _pieSeries;
        [ObservableProperty] private List<TopShowModel> _topShowsList;

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

        // 2. Tải dữ liệu cho Biểu đồ Doanh thu (Line Chart) theo 12 tháng
        private async Task LoadRevenueChart()
        {
            try
            {
                // Lấy dữ liệu thô từ DB (Tháng, Doanh thu)
                var rawData = await _dbService.GetRevenueMonthlyAsync();

                var historyData = new List<RevenueInput>();

                if (rawData.Any())
                {
                    var parsed = rawData.Select(r => {
                        // Ưu tiên parse yyyy-MM-01 (từ code SQL mới)
                        if (DateTime.TryParse(r.month, out DateTime dt))
                            return new RevenueInput { Date = dt, TotalRevenue = (float)r.total_revenue };
                        // Fallback cho định dạng cũ MM/yyyy
                        if (DateTime.TryParseExact(r.month, "MM/yyyy", null, System.Globalization.DateTimeStyles.None, out DateTime dt2))
                            return new RevenueInput { Date = dt2, TotalRevenue = (float)r.total_revenue };
                        return null;
                    }).Where(x => x != null).OrderBy(x => x.Date).ToList();

                    if (parsed.Any())
                    {
                        var minDate = parsed.First().Date;
                        var maxDate = parsed.Last().Date;
                        for (var d = minDate; d <= maxDate; d = d.AddMonths(1))
                        {
                            var existing = parsed.FirstOrDefault(x => x.Date.Year == d.Year && x.Date.Month == d.Month);
                            historyData.Add(existing ?? new RevenueInput { Date = d, TotalRevenue = 0 });
                        }
                    }
                }

                // ML.NET Forecast
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

                var chartValuesHistory = new ChartValues<double>();
                var chartValuesForecast = new ChartValues<double>();
                var labels = new List<string>();

                foreach (var item in historyData)
                {
                    chartValuesHistory.Add(item.TotalRevenue);
                    chartValuesForecast.Add(double.NaN);
                    labels.Add(item.Date.ToString("MM/yy"));
                }

                if (prediction != null)
                {
                    chartValuesForecast.RemoveAt(chartValuesForecast.Count - 1);
                    chartValuesForecast.Add(historyData.Last().TotalRevenue);

                    DateTime lastDate = historyData.Last().Date;
                    for (int i = 0; i < horizon; i++)
                    {
                        float val = prediction.ForecastedRevenue[i];
                        if (val < 0) val = 0;
                        chartValuesForecast.Add(val);
                        labels.Add(lastDate.AddMonths(i + 1).ToString("MM/yy"));
                    }
                }

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

                // Cấu hình Series cho LiveCharts
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
        public async Task LoadOccupancy(string filter)
        {
            CurrentOccupancyFilter = filter; // Cập nhật biến Filter

            var data = await _dbService.GetOccupancyDataAsync(filter);
            var sold = new ChartValues<double>();
            var unsold = new ChartValues<double>();
            var labels = new List<string>();

            var anchorDate = new DateTime(2025, 11, 30);
            var culture = System.Globalization.CultureInfo.InvariantCulture;

            if (filter == "year")
            {
                foreach (var item in data)
                {
                    labels.Add(item.period);
                    sold.Add((double)item.sold_tickets);
                    unsold.Add((double)item.sold_tickets * 0.3);
                }
            }
            else if (filter == "month")
            {
                var cal = culture.Calendar;
                var currentWeek = cal.GetWeekOfYear(anchorDate, System.Globalization.CalendarWeekRule.FirstDay, DayOfWeek.Monday);
                for (int i = 3; i >= 0; i--)
                {
                    int weekNum = currentWeek - i;
                    if (weekNum <= 0) weekNum += 52;
                    string key = $"Tuần {weekNum}";
                    var item = data.FirstOrDefault(x => x.period == key);
                    double s = item != null ? (double)item.sold_tickets : 0;
                    labels.Add(key); sold.Add(s); unsold.Add(s > 0 ? s * 0.4 : 0);
                }
            }
            else // week
            {
                for (int i = 6; i >= 0; i--)
                {
                    var d = anchorDate.AddDays(-i);
                    string key = d.ToString("dd/MM", culture);
                    var item = data.FirstOrDefault(x => x.period == key);
                    double s = item != null ? (double)item.sold_tickets : 0;
                    labels.Add(key); sold.Add(s); unsold.Add(s > 0 ? s * 0.5 : 0);
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
        public async Task LoadPieChart(DateTime? start = null, DateTime? end = null)
        {
            var topShows = await _dbService.GetTopShowsAsync(start, end);
            var series = new SeriesCollection();
            foreach (var show in topShows)
            {
                // Tạo từng pie cho mỗi vở diễn
                series.Add(new PieSeries
                {
                    Title = show.show_name,
                    Values = new ChartValues<double> { (double)show.sold_tickets },
                    DataLabels = true,
                    LabelPoint = point => $"{point.Participation:P0}"
                });
            }
            PieSeries = series;
        }
        // 5. Tải danh sách Top 5 Vở diễn (Bảng xếp hạng)
        public async Task LoadTopShows(DateTime? start = null, DateTime? end = null)
        {
            var shows = await _dbService.GetTopShowsAsync(start, end);
            // Chuyển đổi dữ liệu sang Model hiển thị (thêm số thứ tự Index)
            TopShowsList = shows.Select((s, i) => new TopShowModel
            {
                Index = i + 1,
                show_name = s.show_name,
                sold_tickets = s.sold_tickets
            }).ToList();
        }
    }
}