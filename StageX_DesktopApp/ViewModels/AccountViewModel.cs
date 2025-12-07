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
    // ViewModel quản lý chức năng: Xem, Thêm, Sửa, Xóa tài khoản người dùng (Admin/Staff)
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

        // --- CÁC BIẾN ĐIỀU KHIỂN TRẠNG THÁI GIAO DIỆN ---
        [ObservableProperty] private string _formTitle = "THÊM TÀI KHOẢN MỚI";
        [ObservableProperty] private string _saveBtnContent = "Thêm tài khoản";
        [ObservableProperty] private bool _isDetailEditable = true; // True: Cho phép nhập (khi thêm mới),  False: Khóa không cho nhập (khi sửa)
        [ObservableProperty] private bool _isStatusEnabled = false;  // True: Cho phép sửa (khi update), False: Khóa (khi thêm mới mặc định là hoạt động)

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

            // 1. Cập nhật giao diện sang chế độ "Chỉnh sửa"
            FormTitle = "CHỈNH SỬA TÀI KHOẢN";
            SaveBtnContent = "Lưu thay đổi";

            // 2. Đổ dữ liệu từ user được chọn lên các ô nhập liệu
            UserId = user.UserId;
            AccountName = user.AccountName;
            Email = user.Email;

            // Map chuỗi Role/Status từ DB sang index của ComboBox
            RoleIndex = (user.Role == "Admin") ? 1 : 0;
            StatusIndex = (user.Status == "khóa") ? 1 : 0;

            // Cấu hình trạng thái giao diện:
            IsStatusEnabled = true; // Cho sửa trạng thái
            IsDetailEditable = false; // Đánh dấu là đang sửa
        }

        // Hàm xử lý khi bấm nút "Làm mới / Hủy"
        [RelayCommand]
        private void Clear()
        {
            // Reset giao diện về chế độ "Thêm mới"
            FormTitle = "Thêm tài khoản mới";
            SaveBtnContent = "Thêm tài khoản";

            // Xóa sạch dữ liệu trên các ô nhập
            UserId = 0;
            AccountName = "";
            Email = "";
            RoleIndex = -1;
            StatusIndex = 0;

            // Cấu hình lại quyền nhập liệu
            IsStatusEnabled = false; // Mới tạo thì mặc định là 'Hoạt động', không cho chọn 'Khóa'
            IsDetailEditable = true; // Mở khóa các ô để nhập thông tin mới
        }


        // Hàm xử lý nút LƯU (Dùng chung cho cả Thêm mới và Cập nhật)
        // Nhận tham số là PasswordBox từ View truyền vào
        [RelayCommand]
        private async Task Save(PasswordBox passwordBox)
        {
            string password = passwordBox.Password;

            // Chuyển đổi index ComboBox thành chuỗi để lưu xuống DB
            string role = RoleIndex == 1 ? "Admin" : "Nhân viên";
            string status = StatusIndex == 1 ? "khóa" : "hoạt động";

            // 1. Validate: Kiểm tra các trường bắt buộc
            if (string.IsNullOrEmpty(AccountName) || string.IsNullOrEmpty(Email) || RoleIndex == -1)
            {
                MessageBox.Show("Vui lòng nhập đủ thông tin!");
                return;
            }

            // 2. Validate: Kiểm tra định dạng Email bằng Regex
            if (!IsValidEmail(Email))
            {
                MessageBox.Show("Email không đúng định dạng! (Ví dụ đúng: ten@gmail.com)", "Lỗi Email", 
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }
            try
            {
                // Tạo đối tượng User tạm thời từ dữ liệu nhập
                var user = new User
                {
                    UserId = UserId,
                    AccountName = AccountName,
                    Email = Email,
                    Role = role,
                    Status = status,
                    IsVerified = true // Mặc định đã xác thực (vì admin tạo)
                };

                bool isUpdatePass = false; // Cờ đánh dấu có đổi mật khẩu không

                // === TRƯỜNG HỢP 1: THÊM MỚI (UserId == 0) ===
                if (UserId == 0)
                {
                    // Thêm mới bắt buộc phải có mật khẩu
                    if (string.IsNullOrEmpty(password)) { MessageBox.Show("Cần nhập mật khẩu!"); return; }

                    // 3. Kiểm tra trùng lặp (Email hoặc Tên tài khoản đã tồn tại chưa?)
                    bool isExist = await _dbService.CheckUserExistsAsync(Email, AccountName);
                    if (isExist)
                    {
                        MessageBox.Show($"Tên tài khoản '{AccountName}' hoặc Email '{Email}' đã tồn tại trong hệ thống!\nVui lòng kiểm tra lại.", "Trùng lặp dữ liệu", 
                            MessageBoxButton.OK, MessageBoxImage.Warning);
                        return; // Dừng ngay lập tức: Không gửi mail, không tạo user
                    }

                    // 4. Gửi email thông báo tài khoản mới cho nhân viên
                    // Đây là bước quan trọng để nhân viên biết thông tin đăng nhập của họ
                    bool sent = await _mailService.SendNewAccountEmailAsync(Email, AccountName, password);
                    if (!sent)
                    {
                        MessageBox.Show("Không thể gửi email. Vui lòng kiểm tra lại Email hoặc kết nối mạng.");
                        return;
                    }

                    // 5. Mã hóa mật khẩu trước khi lưu 
                    user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(password);
                }
                // === TRƯỜNG HỢP 2: CẬP NHẬT (UserId > 0) ===
                else
                {
                    // Nếu có nhập mật khẩu mới thì mới mã hóa và cập nhật
                    if (!string.IsNullOrEmpty(password))
                    {
                        user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(password);
                        isUpdatePass = true;
                    }
                }

                // 6. Gọi Service thực thi xuống Database
                await _dbService.SaveUserAsync(user, isUpdatePass);

                // Thông báo thành công
                MessageBox.Show(UserId > 0 ? "Cập nhật xong!" : "Tạo mới thành công!");

                // Dọn dẹp giao diện sau khi lưu xong
                passwordBox.Password = "";
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
            // 1. Chặn việc tự xóa tài khoản đang đăng nhập
            if (user.UserId == AuthSession.CurrentUser?.UserId)
            {
                MessageBox.Show("Không thể tự xóa tài khoản đang đăng nhập!", "Cảnh báo", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            // 2. Hỏi xác nhận người dùng trước khi xóa (tránh bấm nhầm)
            if (MessageBox.Show($"Bạn có chắc chắn muốn xóa tài khoản '{user.AccountName}' không?",
                                "Xác nhận xóa", MessageBoxButton.YesNo, MessageBoxImage.Question) == MessageBoxResult.Yes)
            {
                try
                {
                    // 3. Gọi Service xóa an toàn (Sử dụng Stored Procedure proc_delete_user_safe)
                    // SP này sẽ kiểm tra xem user đã có booking nào chưa. Nếu có thì chặn xóa.
                    await _dbService.DeleteUserAsync(user.UserId);

                    MessageBox.Show("Đã xóa tài khoản thành công!", "Thông báo", MessageBoxButton.OK, MessageBoxImage.Information);
                    await LoadAccounts();
                }
                catch (Exception ex)
                {
                    // 4. Xử lý lỗi nghiệp vụ từ Database trả về
                    // Nếu SP trả về lỗi "USER_HAS_BOOKING_HISTORY" nghĩa là user này đã phát sinh giao dịch
                    if (ex.Message.Contains("USER_HAS_BOOKING_HISTORY") || 
                        (ex.InnerException != null && ex.InnerException.Message.Contains("USER_HAS_BOOKING_HISTORY")))
                    {
                        MessageBox.Show($"Không thể xóa tài khoản '{user.AccountName}' vì đã có lịch sử giao dịch/đơn hàng.\n\nVui lòng chuyển trạng thái sang 'Khóa' để bảo toàn dữ liệu.",
                                        "Không thể xóa", MessageBoxButton.OK, MessageBoxImage.Warning);
                    }
                    else
                    {
                        // Các lỗi hệ thống khác (mất kết nối, lỗi SQL...)
                        MessageBox.Show($"Lỗi khi xóa: {ex.Message}", "Lỗi", MessageBoxButton.OK, MessageBoxImage.Error);
                    }
                }
            }
        }
    }
}