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
        private readonly DatabaseService _dbService;
        private readonly MailService _mailService;

        [ObservableProperty] private List<User> _accounts;

        // Form fields (Giữ nguyên biến của bạn)
        [ObservableProperty] private int _userId;
        [ObservableProperty] private string _accountName;
        [ObservableProperty] private string _email;
        [ObservableProperty] private int _roleIndex = -1;   // 0: Nhân viên, 1: Admin
        [ObservableProperty] private int _statusIndex = 0;  // 0: Hoạt động, 1: Khóa

        // Điều khiển giao diện
        [ObservableProperty] private string _formTitle = "THÊM TÀI KHOẢN MỚI";
        [ObservableProperty] private string _saveBtnContent = "Thêm tài khoản";
        [ObservableProperty] private bool _isDetailEditable = true;
        [ObservableProperty] private bool _isStatusEnabled = false;

        public AccountViewModel()
        {
            _dbService = new DatabaseService();
            _mailService = new MailService();
            LoadAccountsCommand.Execute(null);
        }

        [RelayCommand]
        private async Task LoadAccounts()
        {
            Accounts = await _dbService.GetAdminStaffUsersAsync();
        }

        [RelayCommand]
        private void Edit(User user)
        {
            if (user == null) return;
            FormTitle = "CHỈNH SỬA TÀI KHOẢN";
            UserId = user.UserId;
            AccountName = user.AccountName;
            Email = user.Email;
            RoleIndex = (user.Role == "Admin") ? 1 : 0;
            StatusIndex = (user.Status == "khóa") ? 1 : 0;

            //IsEditing = true;       // Khóa tên và email
            IsStatusEnabled = true; // Cho sửa trạng thái
            IsDetailEditable = false;      // Đánh dấu là đang sửa
            SaveBtnContent = "Lưu thay đổi";
        }

        [RelayCommand]
        private void Clear()
        {
            FormTitle = "Thêm tài khoản mới";
            UserId = 0;
            AccountName = "";
            Email = "";
            RoleIndex = -1;
            StatusIndex = 0;

            //IsEditing = false;      // Mở tên và email
            IsStatusEnabled = false; // Khóa trạng thái (mặc định hoạt động)
            IsDetailEditable = true;        // Đánh dấu là thêm mới
            SaveBtnContent = "Thêm tài khoản";
        }

        [RelayCommand]
        private async Task Save(PasswordBox passwordBox)
        {
            string password = passwordBox.Password;
            string role = RoleIndex == 1 ? "Admin" : "Nhân viên";
            string status = StatusIndex == 1 ? "khóa" : "hoạt động";

            if (string.IsNullOrEmpty(AccountName) || string.IsNullOrEmpty(Email) || RoleIndex == -1)
            {
                MessageBox.Show("Vui lòng nhập đủ thông tin!");
                return;
            }
            if (!IsValidEmail(Email))
            {
                MessageBox.Show("Email không đúng định dạng! (Ví dụ đúng: ten@gmail.com)", "Lỗi Email", MessageBoxButton.OK, MessageBoxImage.Warning);
                return; // Dừng ngay lập tức
            }
            try
            {
                var user = new User
                {
                    UserId = UserId,
                    AccountName = AccountName,
                    Email = Email,
                    Role = role,
                    Status = status,
                    IsVerified = true
                };

                bool isUpdatePass = false;

                if (UserId == 0) // === TRƯỜNG HỢP THÊM MỚI ===
                {
                    if (string.IsNullOrEmpty(password)) { MessageBox.Show("Cần nhập mật khẩu!"); return; }

                    // [BỔ SUNG] 1. Kiểm tra tài khoản/email đã tồn tại chưa
                    bool isExist = await _dbService.CheckUserExistsAsync(Email, AccountName);
                    if (isExist)
                    {
                        MessageBox.Show($"Tên tài khoản '{AccountName}' hoặc Email '{Email}' đã tồn tại trong hệ thống!\nVui lòng kiểm tra lại.", "Trùng lặp dữ liệu", MessageBoxButton.OK, MessageBoxImage.Warning);
                        return; // Dừng ngay lập tức: Không gửi mail, không tạo user
                    }

                    // [BỔ SUNG] 2. Nếu chưa tồn tại -> Gửi mail
                    bool sent = await _mailService.SendNewAccountEmailAsync(Email, AccountName, password);
                    if (!sent)
                    {
                        MessageBox.Show("Không thể gửi email. Vui lòng kiểm tra lại Email hoặc kết nối mạng.");
                        return;
                    }

                    user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(password);
                }
                else // === TRƯỜNG HỢP CẬP NHẬT ===
                {
                    if (!string.IsNullOrEmpty(password))
                    {
                        user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(password);
                        isUpdatePass = true;
                    }
                }

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
        [RelayCommand]
        private async Task Delete(User user)
        {
            if (user.UserId == AuthSession.CurrentUser?.UserId)
            {
                MessageBox.Show("Không thể tự xóa mình!");
                return;
            }

            if (MessageBox.Show($"Xóa user '{user.AccountName}'?", "Xác nhận", MessageBoxButton.YesNo) == MessageBoxResult.Yes)
            {
                await _dbService.DeleteUserAsync(user.UserId);
                await LoadAccounts();
            }
        }
    }
}