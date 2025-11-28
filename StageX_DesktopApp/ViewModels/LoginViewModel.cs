using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using StageX_DesktopApp.Models;
using StageX_DesktopApp.Services;
using StageX_DesktopApp.Utilities;
using StageX_DesktopApp.Views; // Để mở MainWindow
using System;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;

namespace StageX_DesktopApp.ViewModels
{
    public partial class LoginViewModel : ObservableObject
    {
        private readonly DatabaseService _dbService;

        // Các biến Binding ra giao diện
        [ObservableProperty]
        private string _identifier = "admin@example.com"; // Giá trị mặc định như code cũ


        [ObservableProperty]
        private string _errorMessage;

        [ObservableProperty] // Dùng để disable nút khi đang xử lý
        [NotifyPropertyChangedFor(nameof(IsNotLoading))]
        private bool _isLoading;

        public bool IsNotLoading => !IsLoading; // Biến phụ để binding IsEnabled cho nút

        public LoginViewModel()
        {
            _dbService = new DatabaseService();
        }

        // Command: Xử lý khi bấm nút Đăng nhập
        // Tham số: PasswordBox (được truyền từ View vào để bảo mật)
        [RelayCommand]
        private async Task Login(object parameter)
        {
            var passwordBox = parameter as PasswordBox;
            string password = passwordBox?.Password;

            // Bắt đầu xử lý
            IsLoading = true;
            ErrorMessage = "Đang kiểm tra..."; // Logic cũ

            try
            {
                // 1. Gọi Service tìm User
                var user = await _dbService.GetUserByIdentifierAsync(Identifier);

                // 2. Kiểm tra User tồn tại
                if (user == null)
                {
                    ErrorMessage = "Tài khoản không tồn tại.";
                    // Ghi chú: SoundManager.PlayError(); (Nếu bạn có file này thì bỏ comment ra)
                    IsLoading = false;
                    return;
                }

                // 3. Kiểm tra trạng thái khóa
                if (user.Status != null && user.Status.Equals("khóa", StringComparison.OrdinalIgnoreCase))
                {
                    ErrorMessage = "Tài khoản đã bị khóa";
                    IsLoading = false;
                    return;
                }

                // 4. Kiểm tra mật khẩu (BCrypt)
                bool isPasswordCorrect = BCrypt.Net.BCrypt.Verify(password, user.PasswordHash);
                if (!isPasswordCorrect)
                {
                    ErrorMessage = "Mật khẩu không đúng.";
                    SoundManager.PlayError(); 
                    IsLoading = false;
                    return;
                }

                // 5. Kiểm tra quyền (Role)
                if (user.Role != "Nhân viên" && user.Role != "Admin")
                {
                    SoundManager.PlayError();
                    ErrorMessage = "Bạn không có quyền truy cập.";
                    IsLoading = false;
                    return;
                }

                // 6. Đăng nhập thành công
                AuthSession.Login(user);
                SoundManager.PlaySuccess();

                // Mở MainWindow và đóng Login
                // Trong MVVM thuần túy thường dùng NavigationService, nhưng đây là cách đơn giản nhất để giữ code cũ
                MainWindow mainWindow = new MainWindow();
                mainWindow.Show();

                // Đóng cửa sổ Login hiện tại
                foreach (Window window in Application.Current.Windows)
                {
                    if (window is LoginView)
                    {
                        window.Close();
                        break;
                    }
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi kết nối CSDL (Hãy chắc chắn XAMPP đang chạy): {ex.Message}");
                ErrorMessage = "Lỗi kết nối CSDL.";
            }
            finally
            {
                IsLoading = false;
            }
        }
    }
}