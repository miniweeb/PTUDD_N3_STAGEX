# HỌC PHẦN: PHÁT TRIỂN ỨNG DỤNG DESKTOP
## Đề tài: THIẾT KẾ VÀ TRIỂN KHAI ỨNG DỤNG QUẢN LÝ SÂN KHẤU KỊCH - STAGEX
Trong bối cảnh chuyển đổi số diễn ra mạnh mẽ, các đơn vị nghệ thuật biểu diễn, đặc biệt là sân khấu kịch, đang đối mặt với thách thức trong việc quản lý vận hành thủ công. StageX ra đời như một giải pháp phần mềm toàn diện, giúp tin học hóa quy trình quản lý rạp, bán vé, sắp xếp lịch diễn và báo cáo thống kê, nhằm nâng cao hiệu quả kinh doanh và trải nghiệm khán giả.
## Giảng viên hướng dẫn: TS. Nguyễn Mạnh Tuấn
## Nhóm thực hiện (Nhóm 3)
1. Dương Thanh Ngọc - 31231024139
2. Bùi Tấn Đạt - 31221025667 
3. Huỳnh Bảo Nhi - 31231020861 
4. Lê Mỹ Phụng - 31231026280
5. Nguyễn Hoài Thu - 31231026200 
6. Lê Thị Mỹ Trang - 31231026559 
7. Nguyễn Thị Thùy Trang - 31231026201
## Mô tả và Mục tiêu dự án
### Mô tả
StageX là ứng dụng Desktop (WPF) kết hợp với API (.NET Core) phục vụ việc quản lý toàn diện một sân khấu kịch. Hệ thống hỗ trợ hai nhóm đối tượng chính:
- Quản trị viên (Admin): Quản lý hạ tầng (rạp, ghế), tài nguyên (vở diễn, diễn viên), tài khoản và xem báo cáo phân tích/dự báo doanh thu.
- Nhân viên (Staff): Thực hiện nghiệp vụ bán vé tại quầy (POS), in vé, tra cứu đơn hàng và soát vé.
### Mục tiêu
- Số hóa quy trình: Chuyển đổi các nghiệp vụ thủ công (Excel, sổ sách) sang phần mềm.
- Quản lý trực quan: Hệ thống sơ đồ ghế động, cho phép thiết kế rạp và chọn ghế trực quan.
- Tối ưu hóa bán vé: Hỗ trợ bán vé nhanh, tính tiền tự động, tích hợp tạo mã QR thanh toán và in vé PDF.
- Hỗ trợ ra quyết định: Cung cấp Dashboard với các biểu đồ thống kê và ứng dụng Machine Learning (ML.NET) để dự báo doanh thu tương lai.
## Kiến thức và Công nghệ áp dụng
Dự án được xây dựng dựa trên nền tảng .NET 9 và kiến trúc 3 lớp (3-Tier Architecture), áp dụng mô hình MVVM (Model-View-ViewModel).
### Nền tảng & Ngôn ngữ
- Ngôn ngữ: C#
- Framework: .NET 9, WPF (Windows Presentation Foundation) cho giao diện Desktop.
- API: ASP.NET Core Web API (cho module soát vé).
- Cơ sở dữ liệu: MySQL (Sử dụng XAMPP).
### Thư viện & Công nghệ nổi bật
**Giao diện & MVVM:**
- CommunityToolkit.Mvvm: Hỗ trợ mô hình MVVM, Messaging, RelayCommand.

**Xử lý dữ liệu & Database:**
- Pomelo.EntityFrameworkCore.MySql: ORM tương tác với MySQL.
- Stored Procedures: Sử dụng triệt để thủ tục lưu trữ trong MySQL để tối ưu hiệu năng truy vấn và báo cáo.

**Tính năng nâng cao:**
- LiveCharts.Wpf: Vẽ biểu đồ doanh thu, tỷ lệ lấp đầy.
- Microsoft.ML (ML.NET): Sử dụng thuật toán SSA (Singular Spectrum Analysis) để dự báo doanh thu.
- PDFsharp-WPF: Xuất báo cáo và in vé ra file PDF.
- ZXing.Net: Tạo mã vạch (Barcode) trên vé và quét vé.
- BCrypt.Net-Next: Mã hóa mật khẩu an toàn.
- MailKit: Gửi email thông báo tài khoản mới.
- RestSharp: Gọi API VietQR để tạo mã thanh toán chuyển khoản.
## Các chức năng chính
**Dành cho Quản trị viên (Admin)**
1. Dashboard (Bảng điều khiển):
- Xem tổng quan doanh thu, số đơn hàng, vé bán.
- Biểu đồ doanh thu theo tháng (kết hợp đường dự báo từ AI).
- Biểu đồ tình trạng vé (bán/trống).
- Top 5 vở diễn bán chạy.
- Xuất báo cáo PDF.
2. Quản lý Rạp & Ghế:
- Tạo mới rạp, tùy chỉnh số hàng/cột.
- Thiết kế sơ đồ ghế trực quan (gán hạng ghế VIP/Thường, tạo lối đi).
- Quản lý hạng ghế và giá phụ thu.
3. Quản lý Vở diễn:
- Thêm, sửa, xóa thông tin vở diễn (đạo diễn, thời lượng, poster).
- Phân loại vở diễn và gán danh sách diễn viên tham gia.
4. Quản lý Suất diễn:
- Lên lịch biểu diễn (ngày, giờ, rạp) và thiết lập giá vé.
- Tự động cập nhật trạng thái suất diễn.
5. Quản lý Thể loại: Tạo và quản lý danh mục thể loại để phân loại các tác phẩm kịch.
6. Quản lý Diễn viên: Quản lý hồ sơ, thông tin cá nhân và trạng thái hoạt động của nghệ sĩ.
7. Quản lý Tài khoản: Tạo tài khoản cho nhân viên, phân quyền, khóa/mở khóa tài khoản.
  
**Dành cho Nhân viên (Staff)**
1. Bán vé (POS):
- Chọn vở diễn, suất chiếu (hỗ trợ chế độ Giờ cao điểm).
- Chọn ghế trực tiếp trên sơ đồ (hiển thị màu sắc theo hạng và trạng thái).
- Thanh toán: Tiền mặt (tự tính tiền thừa) hoặc Chuyển khoản (tự sinh mã QR VietQR).
2. Quản lý Đơn hàng & In vé:
- Tra cứu đơn hàng theo mã, tên khách, SĐT.
- In vé ra file PDF (bao gồm thông tin vé và Barcode kiểm soát).
3. Soát vé (Ticket Scanning):
- Nhập mã vé hoặc quét barcode để kiểm tra tính hợp lệ.
- Cập nhật trạng thái vé ("Đã sử dụng") theo thời gian thực.
4. Hồ sơ cá nhân: Cập nhật thông tin, đổi mật khẩu.
## Hướng dẫn Cài đặt & Triển khai
### Yêu cầu hệ thống
Visual Studio 2022 (hoặc mới hơn) hỗ trợ .NET 9.
MySQL Server (khuyên dùng XAMPP/WAMP).
### Các bước cài đặt
1. Cơ sở dữ liệu:
Mở công cụ quản lý MySQL (phpMyAdmin hoặc MySQL Workbench).
Tạo database tên stagex_db.
Import file stagex_db.sql (nằm trong thư mục gốc) để tạo bảng và Stored Procedures.
2. Cấu hình kết nối:
Mở file StageX_DesktopApp/Data/AppDbContext.cs (hoặc appsettings.json trong project API).
Cập nhật chuỗi kết nối (Connection String) phù hợp với máy cá nhân:
"Server=localhost;Database=stagex_db;User=root;Password=;"
3. Chạy ứng dụng:
Mở file solution StageX.sln bằng Visual Studio.
Đặt StageX_DesktopApp làm Startup Project.
Nhấn Start (F5) để chạy ứng dụng.
Tùy chọn: Để dùng tính năng quét vé qua API, chạy song song project Stagex.Api.
### Tài khoản mặc định
**Admin:**
- User: admin
- Pass: 12345

**Nhân viên:**
- User: staff
- Pass: 12345
## Cấu trúc dự án
Dự án tuân theo mô trúc MVVM và chia tách các tầng rõ ràng:
### StageX_DesktopApp: Project chính (WPF).
**Views:** Chứa các file .xaml và code-behind giao diện (LoginView, DashboardView, SellTicketView...).

**ViewModels:** Xử lý logic nghiệp vụ, cầu nối giữa View và Model (LoginViewModel, MainViewModel...).

**Models:** Các lớp ánh xạ bảng CSDL (User, Show, Ticket...) và các lớp DTO.

**Services:**
- DatabaseService.cs: Xử lý truy vấn DB, gọi Stored Procedures.
- RevenueForecastingService.cs: Logic dự báo doanh thu bằng ML.NET.
- VietQRService.cs: Tích hợp tạo mã QR.
- TicketScanService.cs: Gọi API quét vé.
- SoundManager.cs: Quản lý âm thanh thông báo.

**Utilities:** Các converter (BoolToVisibility, MenuConverters) và Helper.

### stagex_api:
Project Web API (.NET Core) phục vụ chức năng quét vé online.

## Hạn chế và Hướng phát triển
### Hạn chế:
Chưa tích hợp cổng thanh toán online tự động xác thực (IPN), hiện tại nhân viên phải xác nhận thủ công khi khách chuyển khoản.

Chưa quản lý lịch tập của diễn viên và hậu đài.

Chưa hỗ trợ mô hình chuỗi nhiều chi nhánh rạp.
### Hướng phát triển:
Xây dựng Mobile App cho khách hàng đặt vé online.

Tích hợp thanh toán VNPAY/Momo tự động.

Mở rộng module quản lý kho đạo cụ và thiết bị sân khấu.
## Lời cảm ơn
Để hoàn thành tốt đề tài này chúng em xin cảm ơn TS. Nguyễn Mạnh Tuấn. Chúng em xin trân trọng cảm ơn Thầy đã tận tình giúp đỡ, hướng dẫn và định hướng kiến thức chuyên môn cũng như kỹ năng thực tế cho chúng em trong suốt quá trình thực hiện đồ án.
