using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using StageX_DesktopApp.Models;
using StageX_DesktopApp.Services;
using StageX_DesktopApp.Utilities;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Text.RegularExpressions;

namespace StageX_DesktopApp.ViewModels
{
    public partial class AccountViewModel : ObservableObject
    {
        // Khai báo các Service để tương tác với Database và Email
        private readonly DatabaseService _dbService;
        private readonly MailService _mailService;

        // Danh sách tài khoản hiển thị trên DataGrid
        [ObservableProperty] private List<User> _accounts;

        // --- CÁC BIẾN BINDING CHO FORM NHẬP LIỆU ---
        [ObservableProperty] private int _userId; // ID = 0 là thêm mới, > 0 là sửa
        [ObservableProperty] private string _accountName;
        [ObservableProperty] private string _email;
        [ObservableProperty] private int _roleIndex = -1;   // Index cho ComboBox Vai trò: 0=Nhân viên, 1=Admin, -1=Chưa chọn
        [ObservableProperty] private int _statusIndex = 0;  // Index cho ComboBox Trạng thái: 0=Hoạt động, 1=Khóa

        // --- CÁC BIẾN ĐIỀU KHIỂN GIAO DIỆN ---
        [ObservableProperty] private string _formTitle = "THÊM TÀI KHOẢN MỚI";
        [ObservableProperty] private string _saveBtnContent = "Thêm tài khoản";

        // Biến này binding vào IsEnabled của TextBox/PasswordBox
        // True: Cho phép nhập (khi thêm mới)
        // False: Khóa không cho nhập (khi sửa, để tránh đổi tên đăng nhập/email)
        [ObservableProperty] private bool _isDetailEditable = true;
        // Biến này binding vào IsEnabled của ComboBox Trạng thái
        // True: Cho phép sửa (khi update)
        // False: Khóa (khi thêm mới mặc định là hoạt động)
        [ObservableProperty] private bool _isStatusEnabled = false;

        public AccountViewModel()
        {
            _dbService = new DatabaseService();
            _mailService = new MailService();
            LoadAccountsCommand.Execute(null);
        }

        // Hàm tải danh sách tài khoản từ DB
        [RelayCommand]
        private async Task LoadAccounts()
        {
            Accounts = await _dbService.GetAdminStaffUsersAsync();
        }
        // Hàm xử lý khi bấm nút "Sửa" trên bảng
        [RelayCommand]
        private void Edit(User user)
        {
            if (user == null) return;
            // Đổi tiêu đề và nội dung nút
            FormTitle = "CHỈNH SỬA TÀI KHOẢN";
            SaveBtnContent = "Lưu thay đổi";
            // Đổ dữ liệu từ dòng được chọn lên Form
            UserId = user.UserId;
            AccountName = user.AccountName;
            Email = user.Email;
            // Chuyển đổi từ chuỗi sang index cho ComboBox
            RoleIndex = (user.Role == "Admin") ? 1 : 0;
            StatusIndex = (user.Status == "khóa") ? 1 : 0;

            // Cấu hình trạng thái giao diện:
            IsStatusEnabled = true; // Cho sửa trạng thái
            IsDetailEditable = false;      // Đánh dấu là đang sửa
        }

        // Hàm xử lý khi bấm nút "Làm mới / Hủy"
        [RelayCommand]
        private void Clear()
        {
            // Reset về trạng thái Thêm mới
            FormTitle = "Thêm tài khoản mới";
            SaveBtnContent = "Thêm tài khoản";

            UserId = 0;
            AccountName = "";
            Email = "";
            RoleIndex = -1;
            StatusIndex = 0;

            IsStatusEnabled = false; // Mặc định là hoạt động, không cho chọn khóa ngay lúc tạo
            IsDetailEditable = true; // Cho phép nhập liệu đầy đủ
        }
        // Hàm Lưu (Thêm mới hoặc Cập nhật)
        // Nhận tham số là PasswordBox từ View truyền vào
        [RelayCommand]
        private async Task Save(PasswordBox passwordBox)
        {
            string password = passwordBox.Password;
            // Chuyển đổi index ComboBox sang chuỗi để lưu DB
            string role = RoleIndex == 1 ? "Admin" : "Nhân viên";
            string status = StatusIndex == 1 ? "khóa" : "hoạt động";
            // 1. Validate: Kiểm tra rỗng
            if (string.IsNullOrEmpty(AccountName) || string.IsNullOrEmpty(Email) || RoleIndex == -1)
            {
                MessageBox.Show("Vui lòng nhập đủ thông tin!");
                return;
            }
            // 2. Validate: Kiểm tra định dạng Email
            if (!IsValidEmail(Email))
            {
                MessageBox.Show("Email không đúng định dạng! (Ví dụ đúng: ten@gmail.com)", "Lỗi Email", 
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return; // Dừng ngay lập tức
            }
            try
            {
                // Tạo object User chung
                var user = new User
                {
                    UserId = UserId,
                    AccountName = AccountName,
                    Email = Email,
                    Role = role,
                    Status = status,
                    IsVerified = true
                };

                bool isUpdatePass = false; // Cờ đánh dấu có đổi mật khẩu không
                // === TRƯỜNG HỢP THÊM MỚI (ID = 0) ===
                if (UserId == 0)
                {
                    if (string.IsNullOrEmpty(password)) { MessageBox.Show("Cần nhập mật khẩu!"); return; }

                    // 3. Kiểm tra xem tài khoản/email đã tồn tại chưa
                    bool isExist = await _dbService.CheckUserExistsAsync(Email, AccountName);
                    if (isExist)
                    {
                        MessageBox.Show($"Tên tài khoản '{AccountName}' hoặc Email '{Email}' đã tồn tại trong hệ thống!\nVui lòng kiểm tra lại.", "Trùng lặp dữ liệu", 
                            MessageBoxButton.OK, MessageBoxImage.Warning);
                        return; // Dừng ngay lập tức: Không gửi mail, không tạo user
                    }

                    // 4. Gửi mail thông báo mật khẩu cho nhân viên
                    bool sent = await _mailService.SendNewAccountEmailAsync(Email, AccountName, password);
                    if (!sent)
                    {
                        MessageBox.Show("Không thể gửi email. Vui lòng kiểm tra lại Email hoặc kết nối mạng.");
                        return;
                    }
                    // 5. Mã hóa mật khẩu trước khi lưu
                    user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(password);
                }
                // === TRƯỜNG HỢP CẬP NHẬT (ID > 0) ===
                else
                {
                    // Nếu có nhập mật khẩu mới thì mới mã hóa và cập nhật
                    if (!string.IsNullOrEmpty(password))
                    {
                        user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(password);
                        isUpdatePass = true;
                    }
                }
                // 6. Gọi Service lưu xuống Database
                await _dbService.SaveUserAsync(user, isUpdatePass);
                MessageBox.Show(UserId > 0 ? "Cập nhật xong!" : "Tạo mới thành công!");

                passwordBox.Password = ""; // Xóa pass trên UI
                Clear();
                await LoadAccounts();
            }
            catch (Exception ex)
            {
                MessageBox.Show("Lỗi: " + ex.Message);
            }
        }
        // Hàm kiểm tra định dạng Email bằng Regex
        private bool IsValidEmail(string email)
        {
            if (string.IsNullOrWhiteSpace(email)) return false;
            try
            {
                // Regex: Phải có ký tự + @ + ký tự + . + ký tự (ít nhất 2 chữ cái)
                return Regex.IsMatch(email,
                    @"^[^@\s]+@[^@\s]+\.[^@\s]{2,}$",
                    RegexOptions.IgnoreCase, TimeSpan.FromMilliseconds(250));
            }
            catch (RegexMatchTimeoutException) { return false; }
        }
        // Hàm Xóa tài khoản
        [RelayCommand]
        private async Task Delete(User user)
        {
            // Chặn tự xóa chính mình
            if (user.UserId == AuthSession.CurrentUser?.UserId)
            {
                MessageBox.Show("Không thể tự xóa tài khoản đang đăng nhập!", "Cảnh báo", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            // 2. Hỏi xác nhận
            if (MessageBox.Show($"Bạn có chắc chắn muốn xóa tài khoản '{user.AccountName}' không?",
                                "Xác nhận xóa", MessageBoxButton.YesNo, MessageBoxImage.Question) == MessageBoxResult.Yes)
            {
                try
                {
                    // Gọi hàm xóa an toàn (gọi Stored Procedure kiểm tra đơn hàng trước khi xóa)
                    await _dbService.DeleteUserAsync(user.UserId);

                    MessageBox.Show("Đã xóa tài khoản thành công!", "Thông báo", MessageBoxButton.OK, MessageBoxImage.Information);
                    await LoadAccounts();
                }
                catch (Exception ex)
                {
                    // Nếu SP trả về lỗi do ràng buộc đơn hàng, hiển thị thông báo
                    if (ex.Message.Contains("USER_HAS_BOOKING_HISTORY") || 
                        (ex.InnerException != null && ex.InnerException.Message.Contains("USER_HAS_BOOKING_HISTORY")))
                    {
                        MessageBox.Show($"Không thể xóa tài khoản '{user.AccountName}' vì đã có lịch sử giao dịch/đơn hàng.\n\nVui lòng chuyển trạng thái sang 'Khóa' để bảo toàn dữ liệu.",
                                        "Không thể xóa", MessageBoxButton.OK, MessageBoxImage.Warning);
                    }
                    else
                    {
                        // Lỗi khác
                        MessageBox.Show($"Lỗi khi xóa: {ex.Message}", "Lỗi", MessageBoxButton.OK, MessageBoxImage.Error);
                    }
                }
            }
        }
    }
}