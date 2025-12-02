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
    // Kế thừa ObservableObject để hỗ trợ thông báo thay đổi dữ liệu (INotifyPropertyChanged)
    public partial class LoginViewModel : ObservableObject
    {
        private readonly DatabaseService _dbService;// Service để gọi xuống Database

        // --- CÁC BIẾN BINDING RA GIAO DIỆN ---
        [ObservableProperty]
        private string _identifier = "";
        [ObservableProperty]
        private string _errorMessage;// Thông báo lỗi hiển thị màu đỏ
        // Biến trạng thái Loading. Khi = true thì đang xử lý, nút bấm sẽ bị khóa
        [ObservableProperty]
        [NotifyPropertyChangedFor(nameof(IsNotLoading))]// Khi IsLoading đổi, IsNotLoading cũng đổi theo
        private bool _isLoading;

        public bool IsNotLoading => !IsLoading; // Biến phụ để binding IsEnabled cho nút

        public LoginViewModel()
        {
            _dbService = new DatabaseService();// Khởi tạo service DB
        }

        // Command: Hàm được gọi khi nhấn nút "Đăng nhập"
        // async Task: Xử lý bất đồng bộ để không treo giao diện
        // parameter: Chính là PasswordBox được truyền từ View
        [RelayCommand]
        private async Task Login(object parameter)
        {
            // Ép kiểu tham số về PasswordBox để lấy mật khẩu
            var passwordBox = parameter as PasswordBox;
            string password = passwordBox?.Password;

            // 1. Validate: Kiểm tra nhập tên đăng nhập
            if (string.IsNullOrWhiteSpace(Identifier))
            {
                ErrorMessage = "Vui lòng nhập Email hoặc Tên đăng nhập!";
                return;
            }

            // 2. Validate: Kiểm tra nhập mật khẩu
            if (string.IsNullOrEmpty(password))
            {
                ErrorMessage = "Vui lòng nhập Mật khẩu!";
                return;
            }
            // Bắt đầu xử lý -> Bật trạng thái Loading (Khóa nút bấm)
            IsLoading = true;
            ErrorMessage = "Đang kiểm tra...";
            try
            {
                // 3. Gọi Database tìm User theo tên hoặc email
                var user = await _dbService.GetUserByIdentifierAsync(Identifier);

                // 4. Kiểm tra xem User có tồn tại không
                if (user == null)
                {
                    ErrorMessage = "Tài khoản không tồn tại.";
                    SoundManager.PlayError();
                    IsLoading = false;
                    return;
                }

                // 5. Kiểm tra User có bị khóa không
                if (user.Status != null && user.Status.Equals("khóa", StringComparison.OrdinalIgnoreCase))
                {
                    ErrorMessage = "Tài khoản đã bị khóa";
                    passwordBox?.Clear();
                    SoundManager.PlayError();
                    IsLoading = false;
                    return;
                }

                // 6. Kiểm tra mật khẩu bằng thư viện mã hóa BCrypt
                // password: Mật khẩu người dùng nhập (Text thường)
                // user.PasswordHash: Chuỗi mã hóa trong Database
                bool isPasswordCorrect = BCrypt.Net.BCrypt.Verify(password, user.PasswordHash);
                if (!isPasswordCorrect)
                {
                    ErrorMessage = "Mật khẩu không đúng.";
                    passwordBox?.Clear();
                    SoundManager.PlayError(); 
                    IsLoading = false;
                    return;
                }

                // 7. Đăng nhập thành công
                AuthSession.Login(user);
                SoundManager.PlaySuccess();
                passwordBox?.Clear();
                // 8. Chuyển hướng sang màn hình chính (MainWindow)
                MainWindow mainWindow = new MainWindow();
                mainWindow.Show();

                // 9. Đóng cửa sổ Login hiện tại
                foreach (Window window in Application.Current.Windows)
                {
                    if (window is LoginView)
                    {
                        window.Close();
                        break;
                    }
                }
            }
            // Xử lý lỗi ngoại lệ (VD: Mất mạng, lỗi server SQL)
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi kết nối CSDL (Hãy chắc chắn XAMPP đang chạy): {ex.Message}");
                ErrorMessage = "Lỗi kết nối CSDL.";
            }
            finally
            {
                // Luôn tắt loading dù thành công hay thất bại
                IsLoading = false;
            }
        }
    }
}

