using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using LiveCharts;
using LiveCharts.Wpf;
using StageX_DesktopApp.Services;
using StageX_DesktopApp.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
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

        // =========================================================
        // [QUAN TRỌNG] PHẦN BẠN BỊ THIẾU Ở LẦN TRƯỚC
        // =========================================================
        [ObservableProperty]
        private DateTime _filterStartDate = DateTime.Now.AddDays(-30);

        [ObservableProperty]
        private DateTime _filterEndDate = DateTime.Now;
        // =========================================================

        // --- BIỂU ĐỒ TÌNH TRẠNG VÉ ---
        [ObservableProperty] private SeriesCollection _occupancySeries;
        [ObservableProperty] private List<string> _occupancyLabels;
        public string CurrentOccupancyFilter { get; set; } = "week";

        // --- BIỂU ĐỒ TRÒN & BẢNG TOP 5 ---
        [ObservableProperty] private SeriesCollection _pieSeries;
        [ObservableProperty] private List<TopShowModel> _topShowsList;

        public DashboardViewModel()
        {
            _dbService = new DatabaseService();
            RevenueSeries = new SeriesCollection();
            OccupancySeries = new SeriesCollection();
            PieSeries = new SeriesCollection();
            TopShowsList = new List<TopShowModel>();
        }

        public async Task LoadData()
        {
            await FilterByDate();
            await LoadSummary();
            await LoadRevenueChart();
            await LoadOccupancy("week");
        }

        // --- HÀM LỌC THEO NGÀY ---
        [RelayCommand]
        private async Task FilterByDate()
        {
            if (FilterStartDate > FilterEndDate)
            {
                MessageBox.Show("Ngày bắt đầu không được lớn hơn ngày kết thúc!", "Lỗi", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            // --- QUAN TRỌNG: Gọi hàm tải lại các phần cần lọc ---

            // A. Tải lại 4 thẻ Tổng quan (Revenue, Orders...)
            await LoadSummary(FilterStartDate, FilterEndDate);

            // B. Tải lại Biểu đồ tròn & Top 5
            await LoadPieChart(FilterStartDate, FilterEndDate);
            await LoadTopShows(FilterStartDate, FilterEndDate);
        }

        // 3. Cập nhật hàm LoadSummary (Nhận tham số ngày)
        private async Task LoadSummary(DateTime? start = null, DateTime? end = null)
        {
            // Gọi Service với tham số ngày
            var sum = await _dbService.GetDashboardSummaryAsync(start, end);

            if (sum != null)
            {
                RevenueText = $"{sum.total_revenue:N0}đ";
                OrderText = sum.total_bookings.ToString();
                ShowText = sum.total_shows.ToString();
                GenreText = sum.total_genres.ToString();
            }
        }
        private async Task LoadSummary()
        {
            var sum = await _dbService.GetDashboardSummaryAsync();
            if (sum != null)
            {
                RevenueText = $"{sum.total_revenue:N0}đ";
                OrderText = sum.total_bookings.ToString();
                ShowText = sum.total_shows.ToString();
                GenreText = sum.total_genres.ToString();
            }
        }

        private async Task LoadRevenueChart()
        {
            try
            {
                var rawData = await _dbService.GetRevenueMonthlyAsync();
                var historyData = new List<RevenueInput>();

                if (rawData.Any())
                {
                    var parsed = rawData.Select(r => {
                        // Sửa lỗi: RevenueMonthly dùng .month chứ không phải .period
                        if (DateTime.TryParse(r.month, out DateTime dt))
                            return new RevenueInput { Date = dt, TotalRevenue = (float)r.total_revenue };
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

                // Dự báo (ML.NET)
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

        public async Task LoadOccupancy(string filter)
        {
            CurrentOccupancyFilter = filter;
            var data = await _dbService.GetOccupancyDataAsync(filter);

            var sold = new ChartValues<double>();
            var unsold = new ChartValues<double>();
            var labels = new List<string>();

            var anchorDate = DateTime.Now;
            var culture = System.Globalization.CultureInfo.InvariantCulture;

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
                var cal = culture.Calendar;
                var currentWeek = cal.GetWeekOfYear(anchorDate, System.Globalization.CalendarWeekRule.FirstDay, DayOfWeek.Monday);
                for (int i = 3; i >= 0; i--)
                {
                    int weekNum = currentWeek - i;
                    if (weekNum <= 0) weekNum += 52;
                    string key = $"Tuần {weekNum}";

                    var item = data.FirstOrDefault(x => x.period == key);
                    double s = item != null ? (double)item.sold_tickets : 0;
                    double u = item != null ? (double)item.unsold_tickets : 0;

                    labels.Add(key);
                    sold.Add(s);
                    unsold.Add(u);
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
                    double u = item != null ? (double)item.unsold_tickets : 0;

                    labels.Add(key);
                    sold.Add(s);
                    unsold.Add(u);
                }
            }

            OccupancySeries = new SeriesCollection
            {
                new StackedColumnSeries { Title = "Đã bán", Values = sold, Fill = new SolidColorBrush(Color.FromRgb(255,193,7)), DataLabels = true },
                new StackedColumnSeries { Title = "Còn trống", Values = unsold, Fill = new SolidColorBrush(Color.FromRgb(60,60,60)), DataLabels = true, Foreground = Brushes.White }
            };
            OccupancyLabels = labels;
        }

        public async Task LoadPieChart(DateTime? start = null, DateTime? end = null)
        {
            var topShows = await _dbService.GetTopShowsAsync(start, end);
            var series = new SeriesCollection();

            foreach (var show in topShows)
            {
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

        public async Task LoadTopShows(DateTime? start = null, DateTime? end = null)
        {
            var shows = await _dbService.GetTopShowsAsync(start, end);

            TopShowsList = shows.Select((s, i) => new TopShowModel
            {
                Index = i + 1,
                show_name = s.show_name,
                sold_tickets = s.sold_tickets
            }).ToList();
        }
    }
}