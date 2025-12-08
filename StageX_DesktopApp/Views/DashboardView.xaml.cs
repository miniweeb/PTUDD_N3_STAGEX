using LiveCharts;
using LiveCharts.Wpf;
using PdfSharp.Drawing;
using PdfSharp.Fonts;
using PdfSharp.Pdf;
using StageX_DesktopApp.Services;
using StageX_DesktopApp.ViewModels;
using System;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using StageX_DesktopApp.Services;

namespace StageX_DesktopApp.Views
{
    public partial class DashboardView : UserControl
    {
        public DashboardView()
        {
            InitializeComponent();

            this.Loaded += DashboardView_Loaded;
        }
        private async void DashboardView_Loaded(object sender, RoutedEventArgs e)
        {
            // Lấy ViewModel từ DataContext ra để gọi hàm LoadData
            if (this.DataContext is DashboardViewModel vm)
            {
                await vm.LoadData();
            }
        }

        // --- SỰ KIỆN: XỬ LÝ CÁC NÚT LỌC (TUẦN / THÁNG / NĂM) ---
        // Logic này để ở View vì nó liên quan trực tiếp đến việc đổi màu nút bấm (UI)
        private async void FilterButton_Click(object sender, RoutedEventArgs e)
        {
            // Lấy ViewModel hiện tại
            if (this.DataContext is DashboardViewModel vm)
            {
                string filter = "week"; // Mặc định

                // Kiểm tra xem nút nào đang được chọn
                if (MonthFilterButton.IsChecked == true) filter = "month";
                if (YearFilterButton.IsChecked == true) filter = "year";

                // Gọi hàm load lại dữ liệu trong ViewModel
                await vm.LoadOccupancy(filter);
            }
        }

        private async void OccupancyChart_DataClick(object sender, ChartPoint chartPoint)
        {
            // Lấy ViewModel từ DataContext
            if (this.DataContext is DashboardViewModel vm)
            {
                // 1. Kiểm tra và lấy nhãn của cột vừa click
                if (vm.OccupancyLabels == null || (int)chartPoint.X >= vm.OccupancyLabels.Count) return;
                string label = vm.OccupancyLabels[(int)chartPoint.X];

                DateTime start = DateTime.MinValue;
                DateTime end = DateTime.MaxValue;
                bool isValidDate = false;

                int year = 2025;

                // 2. Xử lý logic thời gian dựa trên Filter đang chọn
                if (vm.CurrentOccupancyFilter == "week")
                {
                    if (DateTime.TryParseExact($"{label}/{year}", "dd/MM/yyyy", null, DateTimeStyles.None, out DateTime date))
                    {
                        start = date.Date; 
                        end = date.Date.AddDays(1).AddTicks(-1); 
                        isValidDate = true;
                    }
                }
                else if (vm.CurrentOccupancyFilter == "month")
                {
                    // Click vào tuần (VD: "Tuần 48") -> Lọc data trong 7 ngày của tuần đó
                    string weekNumStr = label.Replace("Tuần ", "");
                    if (int.TryParse(weekNumStr, out int weekNum))
                    {
                        start = FirstDateOfWeekISO8601(year, weekNum);
                        end = start.AddDays(7).AddTicks(-1);
                        isValidDate = true;
                    }
                }
                else if (vm.CurrentOccupancyFilter == "year")
                {
                    // Click vào năm (VD: "2025") -> Lọc data cả năm
                    if (int.TryParse(label, out int y))
                    {
                        start = new DateTime(y, 1, 1);
                        end = new DateTime(y, 12, 31, 23, 59, 59);
                        isValidDate = true;
                    }
                }

                // 3. Gọi ViewModel để cập nhật dữ liệu nếu ngày hợp lệ
                if (isValidDate)
                {
                    await vm.LoadPieChart(start, end);
                    await vm.LoadTopShows(start, end);
                }
            }
        }

        public static DateTime FirstDateOfWeekISO8601(int year, int weekOfYear)
        {
            DateTime jan1 = new DateTime(year, 1, 1);
            int daysOffset = DayOfWeek.Thursday - jan1.DayOfWeek;

            DateTime firstThursday = jan1.AddDays(daysOffset);
            var cal = CultureInfo.CurrentCulture.Calendar;
            int firstWeek = cal.GetWeekOfYear(firstThursday, CalendarWeekRule.FirstFourDayWeek, DayOfWeek.Monday);

            var weekNum = weekOfYear;
            if (firstWeek <= 1)
            {
                weekNum -= 1;
            }

            var result = firstThursday.AddDays(weekNum * 7);
            return result.AddDays(-3); // Trả về Thứ 2 đầu tuần
        }

        // --- CHỨC NĂNG CHÍNH: XUẤT BÁO CÁO PDF ---
        private async void BtnExportPdf_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                // 1. Hiển thị màn hình chờ (Loading) để chặn người dùng bấm lung tung
                LoadingOverlay.Visibility = Visibility.Visible;
                ExportProgressBar.Value = 0;
                ProgressStatusText.Text = "Đang khởi tạo...";
                await Task.Delay(50); // Đợi UI render xong overlay

                // Tạo file PDF khổ A4 Ngang
                string filePath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Desktop), $"BaoCao_StageX_{DateTime.Now:HHmmss}.pdf");
                var doc = new PdfDocument();
                doc.Info.Title = "Báo cáo Dashboard StageX";
                PdfPage page = doc.AddPage();
                page.Width = XUnit.FromMillimeter(297);
                page.Height = XUnit.FromMillimeter(210);
                XGraphics gfx = XGraphics.FromPdfPage(page);

                // Nền đen
                gfx.DrawRectangle(XBrushes.Black, 0, 0, page.Width, page.Height);

                // Font
                XFont fTitle = new XFont("Arial", 24);
                XFont fHeader = new XFont("Arial", 16);

                ExportProgressBar.Value = 10;
                ProgressStatusText.Text = "Đang vẽ tiêu đề...";
                await Task.Delay(20);

                // 1. Vẽ Tiêu đề & KPI (Giữ nguyên hoặc vẽ đơn giản)
                gfx.DrawString("BÁO CÁO TỔNG QUAN", fTitle, XBrushes.Yellow, new XRect(0, 20, page.Width, 30), XStringFormats.TopCenter);

                ExportProgressBar.Value = 30;
                ProgressStatusText.Text = "Đang xử lý biểu đồ Doanh thu...";
                await Task.Delay(50);


                // Chụp ảnh biểu đồ Doanh thu từ giao diện
                gfx.DrawString("DOANH THU", fHeader, XBrushes.Cyan, 40, 80);
                var imgRevenue = CaptureChartToXImage(RevenueChart, 800, 400); 
                if (imgRevenue != null) gfx.DrawImage(imgRevenue, 40, 110, 350, 180); 

                ExportProgressBar.Value = 50;
                ProgressStatusText.Text = "Đang xử lý biểu đồ Tình trạng vé...";
                await Task.Delay(50);

                // Chụp ảnh biểu đồ Occupancy từ giao diện
                gfx.DrawString("TÌNH TRẠNG VÉ", fHeader, XBrushes.Cyan, 420, 80);
                var imgOccupancy = CaptureChartToXImage(OccupancyChart, 800, 500); 
                if (imgOccupancy != null) gfx.DrawImage(imgOccupancy, 420, 110, 350, 180);

                ExportProgressBar.Value = 70;
                ProgressStatusText.Text = "Đang xử lý biểu đồ Tỷ lệ vé...";
                await Task.Delay(50);

                // Chụp ảnh biểu đồ Pie Chart từ giao diện 
                gfx.DrawString("TỶ LỆ VÉ", fHeader, XBrushes.Cyan, 40, 310);
                var imgPie = CaptureChartToXImage(ShowPieChart, 600, 400); 
                if (imgPie != null) gfx.DrawImage(imgPie, 40, 340, 300, 200);

                ExportProgressBar.Value = 90;
                ProgressStatusText.Text = "Đang xử lý bảng số liệu...";
                await Task.Delay(50);

                // Chụp ảnh bảng từ giao diện 
                gfx.DrawString("TOP 5 VỞ DIỄN", fHeader, XBrushes.Cyan, 420, 310);
                var imgTable = CaptureChartToXImage(TopShowsGrid, 800, 400);
                if (imgTable != null) gfx.DrawImage(imgTable, 420, 340, 350, 200);

                ExportProgressBar.Value = 100;
                ProgressStatusText.Text = "Đang lưu file...";
                await Task.Delay(100);

                SoundManager.PlaySuccess();

                // Lưu và mở file
                doc.Save(filePath);
                LoadingOverlay.Visibility = Visibility.Collapsed;

                Process.Start(new ProcessStartInfo(filePath) { UseShellExecute = true });
            }
            catch (Exception ex) { MessageBox.Show("Lỗi PDF: " + ex.Message); }
        }

        // --- HÀM HỖ TRỢ: CHUYỂN ĐỔI (CHỤP) CONTROL WPF THÀNH ẢNH XIMAGE ---
        // Input: UIElement (Control cần chụp), Width/Height (Kích thước ảnh đầu ra)
        private XImage CaptureChartToXImage(UIElement original, int width, int height)
        {
            try
            {
                // BƯỚC 1: Clone (Sao chép) hình ảnh của Control bằng VisualBrush
                // Tại sao phải làm bước này? Để đảm bảo ta có một bản vẽ sạch, không bị ảnh hưởng bởi các transform khác
                var visual = new DrawingVisual();
                using (var dc = visual.RenderOpen())
                {
                    // Vẽ lại control 'original' lên một hình chữ nhật ảo
                    dc.DrawRectangle(new VisualBrush(original), null, new Rect(0, 0, width, height));
                }

                // BƯỚC 2: Render (Kết xuất) bản vẽ ảo ra thành các điểm ảnh (Bitmap)
                // RenderTargetBitmap là lớp của WPF dùng để biến Vector Graphics thành Raster Image (Pixel)
                // DPI set là 96 (chuẩn màn hình Windows)
                var bmp = new RenderTargetBitmap(width, height, 96, 96, PixelFormats.Pbgra32);
                bmp.Render(visual);

                // BƯỚC 3: Chuyển đổi Bitmap WPF sang định dạng PNG
                var encoder = new PngBitmapEncoder();
                encoder.Frames.Add(BitmapFrame.Create(bmp));

                // BƯỚC 4: Lưu PNG vào bộ nhớ (MemoryStream) và tạo XImage
                using (var ms = new MemoryStream())
                {
                    encoder.Save(ms);
                    ms.Position = 0;

                    // Tạo XImage từ stream.
                    return XImage.FromStream(new MemoryStream(ms.ToArray()));
                }
            }
            catch
            {
                return null;
            }
        }
    }
}