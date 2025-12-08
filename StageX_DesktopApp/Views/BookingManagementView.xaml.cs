using PdfSharp.Drawing;
using PdfSharp.Pdf;
using StageX_DesktopApp.Models;
using StageX_DesktopApp.Services;
using StageX_DesktopApp.ViewModels;
using System;
using System.Diagnostics;
using System.Drawing; // Cần System.Drawing.Common
using System.Drawing.Imaging;
using System.IO;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using ZXing;
using ZXing.Common;
using ZXing.Windows.Compatibility;

namespace StageX_DesktopApp.Views
{
    public partial class BookingManagementView : UserControl
    {
        public BookingManagementView()
        {
            InitializeComponent();

            // Đăng ký nhận event in vé từ ViewModel
            if (this.DataContext is BookingManagementViewModel currentVM)
            {
                currentVM.RequestPrintTicket += ExportTicketToPdf;
            }

            // Xử lý khi DataContext thay đổi (để tránh memory leak sự kiện)
            this.DataContextChanged += (s, e) =>
            {
                if (e.OldValue is BookingManagementViewModel oldVM) oldVM.RequestPrintTicket -= ExportTicketToPdf;
                if (e.NewValue is BookingManagementViewModel newVM) newVM.RequestPrintTicket += ExportTicketToPdf;
            };
        }

        // --- HÀM TẠO MÃ VẠCH (BARCODE) ---
        // Input: Mã vé (VD: "893123456789") -> Output: Hình ảnh mã vạch (XImage)
        private XImage GenerateBarcodeXImage(string content)
        {
            try
            {
                // Sử dụng thư viện ZXing để tạo mã vạch
                var writer = new BarcodeWriter
                {
                    Format = BarcodeFormat.CODE_128,
                    Options = new EncodingOptions
                    {
                        Height = 50,  // Chiều cao mã vạch
                        Width = 300,  // Chiều rộng
                        Margin = 0,   // Không lề
                        PureBarcode = true // Chỉ vẽ vạch, không vẽ số bên dưới (số ta tự vẽ sau cho đẹp)
                    }
                };

                // Tạo ảnh Bitmap từ chuỗi số
                using (var bitmap = writer.Write(content))
                {
                    // Chuyển Bitmap sang MemoryStream (PNG) để PDFSharp đọc được
                    var stream = new MemoryStream();
                    bitmap.Save(stream, ImageFormat.Png);
                    stream.Position = 0;

                    // Trả về đối tượng ảnh của PDFSharp
                    return XImage.FromStream(stream);
                }
            }
            catch
            {
                return null;
            }
        }

        // --- HÀM CHÍNH: XUẤT VÉ RA PDF ---
        private void ExportTicketToPdf(BookingDisplayItem b)
        {
            try
            {
                // Kiểm tra: Nếu đơn hàng không có vé nào thì không in
                if (b.TicketDetails == null || b.TicketDetails.Count == 0)
                {
                    MessageBox.Show("Không tìm thấy thông tin vé để in!");
                    return;
                }

                // 1. Tạo file PDF mới
                PdfDocument document = new PdfDocument();
                document.Info.Title = $"Ve_{b.BookingId}";

                // Cấu hình Encoding cho .NET Core/NET 5+ để hỗ trợ tiếng Việt
                System.Text.Encoding.RegisterProvider(System.Text.CodePagesEncodingProvider.Instance);
                XPdfFontOptions options = new XPdfFontOptions(PdfFontEncoding.Unicode);

                // 2. Cấu hình Font chữ và Bút vẽ
                XFont fontTitle = new XFont("Arial", 18, XFontStyle.Bold, options);
                XFont fontHeader = new XFont("Arial", 12, XFontStyle.Bold, options);
                XFont fontNormal = new XFont("Arial", 10, XFontStyle.Regular, options);
                XFont fontSmall = new XFont("Arial", 8, XFontStyle.Regular, options);

                // Khai báo Màu sắc (Brush/Pen)
                XBrush bgBrush = new XSolidBrush(XColor.FromArgb(26, 26, 26)); // Nền đen
                XBrush textWhite = XBrushes.White;
                XBrush textGold = new XSolidBrush(XColor.FromArgb(255, 193, 7)); // Chữ vàng
                XBrush textGray = XBrushes.LightGray;
                XPen linePen = new XPen(XColor.FromArgb(60, 60, 60), 1); // Đường kẻ xám

                // 3. Vòng lặp: Mỗi vé (Ticket) sẽ được in trên 1 trang PDF riêng biệt
                foreach (var ticket in b.TicketDetails)
                {
                    // Tạo trang khổ A6 (105mm x 148mm)
                    PdfPage page = document.AddPage();
                    page.Width = XUnit.FromMillimeter(105);
                    page.Height = XUnit.FromMillimeter(148);

                    XGraphics gfx = XGraphics.FromPdfPage(page);
                    double margin = 12; double y = 5;
                    double pageWidth = page.Width;

                    // Vẽ nền đen full trang
                    gfx.DrawRectangle(bgBrush, 0, 0, page.Width, page.Height);
                    // Vẽ khung viền vàng bao quanh vé
                    gfx.DrawRectangle(new XPen(XColor.FromArgb(255, 193, 7), 2), margin, margin, pageWidth - margin * 2, page.Height - margin * 2);

                    // --- VẼ LOGO ---
                    try
                    {
                        string logoPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Assets", "logo.png");
                        if (File.Exists(logoPath))
                        {
                            XImage logo = XImage.FromFile(logoPath);
                            // Vẽ logo ở giữa phía trên, kích thước 40x40
                            gfx.DrawImage(logo, (pageWidth - 50) / 2, y, 50, 50);
                            y += 50;
                        }
                        else y += 10;
                    }
                    catch { y += 10; }

                    // --- VẼ THÔNG TIN VÉ ---
                    // Tiêu đề rạp
                    gfx.DrawString("STAGEX THEATER", fontTitle, textGold, new XRect(0, y, pageWidth, 20), XStringFormats.TopCenter);
                    y += 27;
                    gfx.DrawString("VÉ XEM KỊCH", fontHeader, textWhite, new XRect(0, y, pageWidth, 20), XStringFormats.TopCenter);
                    y += 25;

                    // Đường kẻ ngang phân cách
                    gfx.DrawLine(linePen, margin + 5, y, pageWidth - margin - 5, y);
                    y += 15;

                    double leftX = margin + 8;

                    // Helper function để vẽ dòng thông tin (Label: Value)
                    void DrawRow(string label, string value, bool boldValue = false)
                    {
                        gfx.DrawString(label, fontNormal, textGray, leftX, y);
                        var fontVal = boldValue ? fontHeader : fontNormal;
                        gfx.DrawString(value ?? "—", fontVal, textWhite, leftX + 80, y);
                        y += 18;
                    }

                    // 3. Vẽ thông tin chung
                    DrawRow("Mã đơn:", $"#{b.BookingId}");
                    DrawRow("Khách:", b.CustomerName);
                    DrawRow("Người lập:", b.CreatorName);
                    DrawRow("Ngày tạo:", b.CreatedAt.ToString("dd/MM/yyyy HH:mm"));
                    y += 8;

                    // 4. Vẽ tên Vở diễn (Cho phép xuống dòng nếu dài)
                    gfx.DrawString("Vở diễn:", fontHeader, textGray, leftX, y);
                    y += 17;
                    gfx.DrawString(b.ShowTitle, fontTitle, textGold, new XRect(leftX, y, pageWidth - margin * 2 - 20, 50), XStringFormats.TopLeft);
                    y += 35;

                    DrawRow("Rạp:", b.TheaterName);
                    DrawRow("Suất:", b.PerformanceTime.ToString("HH:mm - dd/MM/yyyy"));
                    y += 5;

                    // 5. Vẽ thông tin riêng của vé này (Ghế + Giá)
                    gfx.DrawString("Ghế:", fontHeader, textGray, leftX, y);
                    gfx.DrawString(ticket.SeatLabel, fontTitle, textGold, leftX + 60, y);
                    y += 15;

                    gfx.DrawString("GIÁ VÉ:", fontHeader, textWhite, leftX, y + 5);
                    gfx.DrawString($"{ticket.Price:N0} đ", fontTitle, textGold, pageWidth - leftX - 100, y + 0);
                    y += 20;

                    // 6. Vẽ Mã vạch (Barcode)
                    // Tính toán vị trí barcode
                    double bcW = 160;
                    double bcH = 35;
                    double bcX = (pageWidth - bcW) / 2;

                    // Vẽ nền trắng cho khu vực Barcode (bắt buộc để máy quét đọc được trên nền đen)
                    gfx.DrawRectangle(XBrushes.White, bcX - 5, y, bcW + 10, bcH + 15);

                    // Tạo và vẽ Barcode
                    XImage realBarcode = GenerateBarcodeXImage(ticket.TicketCode);
                    if (realBarcode != null)
                    {
                        gfx.DrawImage(realBarcode, bcX, y + 5, bcW, 25);
                    }

                    // Vẽ mã số (màu đen) bên dưới vạch để dự phòng
                    gfx.DrawString(ticket.TicketCode, fontSmall, XBrushes.Black,
                                   new XRect(0, y + 32, pageWidth, 10), XStringFormats.TopCenter);

                    y += 55; // Cách ra để viết lời cảm ơn
                    gfx.DrawString("Cảm ơn quý khách!", fontSmall, textGray, new XRect(0, y, pageWidth, 10), XStringFormats.TopCenter);
                }

                // Lưu file ra Desktop
                string folder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Desktop), "StageX_Tickets");
                if (!Directory.Exists(folder)) Directory.CreateDirectory(folder);

                string fileName = $"Ve_{b.BookingId}_{DateTime.Now:HHmmss}.pdf";
                string fullPath = Path.Combine(folder, fileName);

                document.Save(fullPath);

                // Tự động mở file PDF sau khi lưu
                try { Process.Start(new ProcessStartInfo(fullPath) { UseShellExecute = true }); } catch { }

                SoundManager.PlaySuccess();
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi in vé: {ex.Message}");
            }
        }
    }
}