using LiveCharts.Wpf;
using PdfSharp.Drawing;
using PdfSharp.Fonts;
using PdfSharp.Pdf;
using StageX_DesktopApp.Services;
using StageX_DesktopApp.ViewModels;
using System;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace StageX_DesktopApp.Views
{
    public partial class DashboardView : UserControl
    {
        public DashboardView()
        {
            InitializeComponent();

        }
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
        // ==============================================================================
        //  SỰ KIỆN CLICK NÚT XUẤT PDF
        // ==============================================================================
        private async void BtnExportPdf_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                string filePath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Desktop),
                    $"BaoCao_StageX_{DateTime.Now:yyyyMMdd_HHmmss}.pdf");

                var doc = new PdfDocument();
                doc.Info.Title = "Báo cáo Dashboard StageX";

                PdfPage page = doc.AddPage();
                page.Size = PdfSharp.PageSize.A4; // Khai báo khổ A4 chuẩn
                page.Orientation = PdfSharp.PageOrientation.Landscape;
                XGraphics gfx = XGraphics.FromPdfPage(page);

                // 1. VẼ NỀN ĐEN (Cho giống giao diện App)
                gfx.DrawRectangle(new XSolidBrush(XColor.FromArgb(26, 26, 26)), 0, 0, page.Width, page.Height);

                // 2. CẤU HÌNH FONT (Hỗ trợ Tiếng Việt)
                // Đăng ký bảng mã Windows-1252 cho .NET Core/9
                System.Text.Encoding.RegisterProvider(System.Text.CodePagesEncodingProvider.Instance);

                XPdfFontOptions options = new XPdfFontOptions(PdfFontEncoding.Unicode);
                XFont fTitle = new XFont("Arial", 24, XFontStyle.Bold, options);
                XFont fHeader = new XFont("Arial", 16, XFontStyle.Bold, options);
                XFont fNormal = new XFont("Arial", 12, XFontStyle.Regular, options);
                XFont fKPI = new XFont("Arial", 20, XFontStyle.Bold, options);

                // 3. VẼ TIÊU ĐỀ & NGÀY
                double y = 30;
                gfx.DrawString("BÁO CÁO TỔNG QUAN STAGEX", fTitle, XBrushes.White, new XRect(0, y, page.Width, 40), XStringFormats.TopCenter);
                y += 40;
                gfx.DrawString($"Ngày xuất: {DateTime.Now:dd/MM/yyyy HH:mm}", fNormal, XBrushes.LightGray, new XRect(0, y, page.Width, 20), XStringFormats.TopCenter);
                y += 50;

                // 4. VẼ KPI (THÔNG TIN TỔNG QUAN)
                // Vẽ thủ công từng ô để đẹp hơn và chắc chắn hiện dữ liệu
                double kpiY = y;
                double kpiWidth = (page.Width - 80) / 4;

                DrawKPIBox(gfx, "TỔNG DOANH THU", RevenueTotalText.Text, 40, kpiY, kpiWidth, fNormal, fKPI);
                DrawKPIBox(gfx, "ĐƠN HÀNG", OrderTotalText.Text, 40 + kpiWidth, kpiY, kpiWidth, fNormal, fKPI);
                DrawKPIBox(gfx, "VỞ DIỄN", ShowTotalText.Text, 40 + kpiWidth * 2, kpiY, kpiWidth, fNormal, fKPI);
                DrawKPIBox(gfx, "THỂ LOẠI", GenreTotalText.Text, 40 + kpiWidth * 3, kpiY, kpiWidth, fNormal, fKPI);

                y += 80; // Xuống dòng sau phần KPI

                // 5. CHỤP ẢNH BIỂU ĐỒ (CHẤT LƯỢNG CAO)
                // Scale = 2.0 (Nhân đôi độ phân giải để ảnh nét khi in)
                double scale = 3.0;

                // Kích thước hiển thị trên PDF
                double margin = 40;
                double chartWidthPDF = (page.Width - (margin * 3)) / 2;
                double chartHeightPDF = 180;
                double col1_X = margin;
                double col2_X = page.Width / 2 + 10;
                double currentY = y;

                // Chờ UI ổn định
                await Task.Delay(200);

                // --- Biểu đồ Doanh thu ---
                gfx.DrawString("DOANH THU THEO THÁNG", fHeader, XBrushes.Cyan, col1_X, currentY);
                var imgRevenue = CaptureChartHighQuality(RevenueChart, scale);
                if (imgRevenue != null)
                    gfx.DrawImage(imgRevenue, col1_X, currentY + 25, chartWidthPDF, chartHeightPDF);

                // --- Biểu đồ Occupancy ---
                gfx.DrawString("TÌNH TRẠNG VÉ (BÁN/TRỐNG)", fHeader, XBrushes.Cyan, col2_X, currentY);
                var imgOccupancy = CaptureChartHighQuality(OccupancyChart, scale);
                if (imgOccupancy != null)
                    gfx.DrawImage(imgOccupancy, col2_X, currentY + 25, chartWidthPDF, chartHeightPDF);

                currentY += chartHeightPDF + 50;

                // --- Biểu đồ Tròn ---
                gfx.DrawString("TỶ LỆ VÉ THEO VỞ DIỄN", fHeader, XBrushes.Cyan, col1_X, currentY);
                var imgPie = CaptureChartHighQuality(ShowPieChart, scale);
                if (imgPie != null)
                    // Pie cần vẽ vuông, căn giữa cột trái
                    gfx.DrawImage(imgPie, col1_X + (chartWidthPDF - chartHeightPDF) / 2, currentY + 25, chartHeightPDF, chartHeightPDF);

                // --- Bảng Top 5 ---
                gfx.DrawString("TOP 5 VỞ DIỄN BÁN CHẠY", fHeader, XBrushes.Cyan, col2_X, currentY);
                var imgTop5 = CaptureChartHighQuality(TopShowsGrid, scale);
                if (imgTop5 != null)
                    gfx.DrawImage(imgTop5, col2_X, currentY + 25, chartWidthPDF, 200); // Chiều cao bảng khoảng 200 là vừa

                // 6. LƯU VÀ MỞ FILE
                doc.Save(filePath);
                doc.Close();

                SoundManager.PlaySuccess();
                MessageBox.Show($"Xuất PDF thành công!\nĐã lưu tại: {filePath}", "Thành công", MessageBoxButton.OK, MessageBoxImage.Information);

                try { Process.Start(new ProcessStartInfo(filePath) { UseShellExecute = true }); } catch { }
            }
            catch (Exception ex)
            {
                SoundManager.PlayError();
                MessageBox.Show("Lỗi xuất PDF: " + ex.Message);
            }
        }

        // Hàm vẽ ô KPI thủ công (để đảm bảo nét và đúng vị trí)
        private void DrawKPIBox(XGraphics gfx, string title, string value, double x, double y, double w, XFont fontTitle, XFont fontValue)
        {
            // Vẽ khung (tùy chọn, ở đây vẽ text thôi cho sạch)
            // gfx.DrawRectangle(new XPen(XColor.FromArgb(50, 50, 50)), x + 5, y, w - 10, 60);

            gfx.DrawString(title, fontTitle, XBrushes.Orange,
                new XRect(x, y, w, 20), XStringFormats.Center);

            gfx.DrawString(value, fontValue, XBrushes.White,
                new XRect(x, y + 25, w, 30), XStringFormats.Center);
        }

        // ==============================================================================
        //  HÀM CHỤP ẢNH CHẤT LƯỢNG CAO (FIX MỜ)
        // ==============================================================================
        private XImage CaptureChartHighQuality(UIElement element, double scale)
        {
            try
            {
                // 1. Lấy kích thước thực tế
                double actualWidth = element.RenderSize.Width;
                double actualHeight = element.RenderSize.Height;

                if (actualWidth == 0 || actualHeight == 0) return null;

                // 2. Tính toán kích thước ảnh đầu ra (Nhân với scale, ví dụ x3)
                int renderWidth = (int)(actualWidth * scale);
                int renderHeight = (int)(actualHeight * scale);

                // 3. Tạo RenderTargetBitmap với DPI cao
                // 96 * scale sẽ tạo ra ảnh có mật độ điểm ảnh cao
                RenderTargetBitmap renderTarget = new RenderTargetBitmap(
                    renderWidth, renderHeight,
                    96 * scale, 96 * scale,
                    PixelFormats.Pbgra32);

                // 4. Vẽ control vào bitmap
                DrawingVisual drawingVisual = new DrawingVisual();
                using (DrawingContext drawingContext = drawingVisual.RenderOpen())
                {
                    // Vẽ nền tối đệm để tránh nền trong suốt
                    drawingContext.DrawRectangle(new SolidColorBrush(Color.FromRgb(30, 30, 30)), null, new Rect(0, 0, actualWidth, actualHeight));

                    // Vẽ nội dung control
                    VisualBrush visualBrush = new VisualBrush(element);
                    drawingContext.DrawRectangle(visualBrush, null, new Rect(0, 0, actualWidth, actualHeight));
                }

                renderTarget.Render(drawingVisual);

                // 5. Chuyển sang XImage
                return BitmapToXImage(renderTarget);
            }
            catch
            {
                return null;
            }
        }

        private MemoryStream BitmapToStream(BitmapSource bmp)
        {
            var stream = new MemoryStream();
            var encoder = new PngBitmapEncoder();
            encoder.Frames.Add(BitmapFrame.Create(bmp));
            encoder.Save(stream);
            stream.Position = 0;
            return stream;
        }

        private XImage BitmapToXImage(BitmapSource bmp)
        {
            using var ms = BitmapToStream(bmp);
            var bytes = ms.ToArray();
            var tempMs = new MemoryStream(bytes);
            return XImage.FromStream(tempMs);
        }
    }
}