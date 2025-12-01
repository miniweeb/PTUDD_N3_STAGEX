using PdfSharp.Drawing;
using PdfSharp.Pdf;
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

            if (this.DataContext is BookingManagementViewModel currentVM)
            {
                currentVM.RequestPrintTicket += ExportTicketToPdf;
            }

            this.DataContextChanged += (s, e) =>
            {
                if (e.OldValue is BookingManagementViewModel oldVM) oldVM.RequestPrintTicket -= ExportTicketToPdf;
                if (e.NewValue is BookingManagementViewModel newVM) newVM.RequestPrintTicket += ExportTicketToPdf;
            };
        }
        private XImage GenerateBarcodeXImage(string content)
        {
            try
            {
                var writer = new BarcodeWriter
                {
                    Format = BarcodeFormat.CODE_128,
                    Options = new EncodingOptions
                    {
                        Height = 50,
                        Width = 300,
                        Margin = 0,
                        PureBarcode = true
                    }
                };

                using (var bitmap = writer.Write(content))
                {
                    // [SỬA LỖI TẠI ĐÂY]
                    // KHÔNG dùng 'using' cho MemoryStream. 
                    // Chúng ta cần stream này còn MỞ để PdfSharp có thể đọc được khi vẽ.
                    var stream = new MemoryStream();

                    bitmap.Save(stream, ImageFormat.Png);
                    stream.Position = 0;

                    return XImage.FromStream(stream);
                }
            }
            catch
            {
                return null;
            }
        }
        private void ExportTicketToPdf(BookingDisplayItem b)
        {
            try
            {
                // [CẬP NHẬT] Kiểm tra danh sách chi tiết vé
                if (b.TicketDetails == null || b.TicketDetails.Count == 0)
                {
                    MessageBox.Show("Không tìm thấy thông tin vé để in!");
                    return;
                }

                PdfDocument document = new PdfDocument();
                document.Info.Title = $"Ve_{b.BookingId}";

                // [CẤU HÌNH CHO .NET 9] Dùng Unicode
                System.Text.Encoding.RegisterProvider(System.Text.CodePagesEncodingProvider.Instance);
                XPdfFontOptions options = new XPdfFontOptions(PdfFontEncoding.Unicode);

                XFont fontTitle = new XFont("Arial", 18, XFontStyle.Bold, options);
                XFont fontHeader = new XFont("Arial", 12, XFontStyle.Bold, options);
                XFont fontNormal = new XFont("Arial", 10, XFontStyle.Regular, options);
                XFont fontSmall = new XFont("Arial", 8, XFontStyle.Regular, options);

                XBrush bgBrush = new XSolidBrush(XColor.FromArgb(26, 26, 26));
                XBrush textWhite = XBrushes.White;
                XBrush textGold = new XSolidBrush(XColor.FromArgb(255, 193, 7));
                XBrush textGray = XBrushes.LightGray;
                XPen linePen = new XPen(XColor.FromArgb(60, 60, 60), 1);

                // [CẬP NHẬT] Lặp qua từng vé trong danh sách chi tiết
                foreach (var ticket in b.TicketDetails)
                {
                    PdfPage page = document.AddPage();
                    page.Width = XUnit.FromMillimeter(105);
                    page.Height = XUnit.FromMillimeter(148);

                    XGraphics gfx = XGraphics.FromPdfPage(page);
                    double margin = 12; double y = 18;
                    double pageWidth = page.Width;

                    gfx.DrawRectangle(bgBrush, 0, 0, page.Width, page.Height);
                    gfx.DrawRectangle(new XPen(XColor.FromArgb(255, 193, 7), 2), margin, margin, pageWidth - margin * 2, page.Height - margin * 2);

                    // Logo
                    try
                    {
                        string logoPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Assets", "logo.png");
                        if (File.Exists(logoPath))
                        {
                            XImage logo = XImage.FromFile(logoPath);
                            gfx.DrawImage(logo, (pageWidth - 50) / 2, y, 50, 50);
                            y += 55;
                        }
                        else y += 10;
                    }
                    catch { y += 10; }

                    gfx.DrawString("STAGEX THEATER", fontTitle, textGold, new XRect(0, y, pageWidth, 20), XStringFormats.TopCenter);
                    y += 27;
                    gfx.DrawString("VÉ XEM KỊCH", fontHeader, textWhite, new XRect(0, y, pageWidth, 20), XStringFormats.TopCenter);
                    y += 25;

                    gfx.DrawLine(linePen, margin + 5, y, pageWidth - margin - 5, y);
                    y += 15;

                    double leftX = margin + 8;
                    void DrawRow(string label, string value, bool boldValue = false)
                    {
                        gfx.DrawString(label, fontNormal, textGray, leftX, y);
                        var fontVal = boldValue ? fontHeader : fontNormal;
                        gfx.DrawString(value ?? "—", fontVal, textWhite, leftX + 80, y);
                        y += 18;
                    }

                    DrawRow("Mã đơn:", $"#{b.BookingId}");
                    DrawRow("Khách:", b.CustomerName);
                    DrawRow("Người lập:", b.CreatorName);
                    DrawRow("Ngày tạo:", b.CreatedAt.ToString("dd/MM/yyyy HH:mm"));
                    y += 8;

                    gfx.DrawString("Vở diễn:", fontHeader, textGray, leftX, y);
                    y += 17;
                    gfx.DrawString(b.ShowTitle, fontTitle, textGold, new XRect(leftX, y, pageWidth - margin * 2 - 20, 50), XStringFormats.TopLeft);
                    y += 35;

                    DrawRow("Rạp:", b.TheaterName);
                    DrawRow("Suất:", b.PerformanceTime.ToString("HH:mm - dd/MM/yyyy"));
                    y += 5;

                    // [CẬP NHẬT] In thông tin riêng của vé này
                    gfx.DrawString("Ghế:", fontHeader, textGray, leftX, y);
                    gfx.DrawString(ticket.SeatLabel, fontTitle, textGold, leftX + 60, y);
                    y += 35;


                    // [CẬP NHẬT] Thay chữ TỔNG CỘNG bằng GIÁ VÉ và in giá riêng
                    gfx.DrawString("GIÁ VÉ:", fontHeader, textWhite, leftX, y + 5);
                    gfx.DrawString($"{ticket.Price:N0} đ", fontTitle, textGold, pageWidth - leftX - 100, y + 0);
                    y += 40;

                    // Tính toán vị trí
                    double bcW = 160;
                    double bcH = 35;
                    double bcX = (pageWidth - bcW) / 2;

                    // Vẽ nền trắng cho khu vực Barcode (bắt buộc để máy quét đọc được)
                    gfx.DrawRectangle(XBrushes.White, bcX - 5, y, bcW + 10, bcH + 15);

                    // Tạo và vẽ Barcode
                    XImage realBarcode = GenerateBarcodeXImage(ticket.TicketCode);
                    if (realBarcode != null)
                    {
                        gfx.DrawImage(realBarcode, bcX, y + 5, bcW, 25);
                    }

                    // Vẽ mã số (màu đen) bên dưới vạch
                    gfx.DrawString(ticket.TicketCode, fontSmall, XBrushes.Black,
                                   new XRect(0, y + 32, pageWidth, 10), XStringFormats.TopCenter);

                    y += 55; // Cách ra để viết lời cảm ơn
                    gfx.DrawString("Cảm ơn quý khách!", fontSmall, textGray, new XRect(0, y, pageWidth, 10), XStringFormats.TopCenter);
                }

                string folder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Desktop), "StageX_Tickets");
                if (!Directory.Exists(folder)) Directory.CreateDirectory(folder);

                string fileName = $"Ve_{b.BookingId}_{DateTime.Now:HHmmss}.pdf";
                string fullPath = Path.Combine(folder, fileName);

                document.Save(fullPath);
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