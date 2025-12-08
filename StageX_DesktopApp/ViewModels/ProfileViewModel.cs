using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using StageX_DesktopApp.Models;
using StageX_DesktopApp.Services;
using StageX_DesktopApp.Utilities;
using StageX_DesktopApp.Views; // Để gọi Window đổi pass
using System;
using System.Threading.Tasks;
using System.Windows;

namespace StageX_DesktopApp.ViewModels
{
    public partial class ProfileViewModel : ObservableObject
    {
        private readonly DatabaseService _dbService;

        private (string Name, string Address, string Phone, DateTime? Dob) _originalState;
        // --- CÁC BIẾN HIỂN THỊ (READ-ONLY) ---
        // Tên tài khoản và Email lấy từ bảng Users, chỉ hiển thị, không sửa ở form này
        [ObservableProperty] private string _accountName = "Loading...";
        [ObservableProperty] private string _email = "...";
        // Chữ cái đầu của tên để làm Avatar (VD: "Nguyen" -> "N")
        [ObservableProperty] private string _initial = "U";
        // --- CÁC BIẾN NHẬP LIỆU (EDITABLE) ---
        // Các thông tin này nằm trong bảng UserDetail
        [ObservableProperty] private string _fullName;
        [ObservableProperty] private string _address;
        [ObservableProperty] private string _phone;
        [ObservableProperty] private DateTime _dateOfBirth = DateTime.Now;

        public ProfileViewModel()
        {
            _dbService = new DatabaseService();
            // Tự động tải thông tin khi mở màn hình
            LoadProfileCommand.Execute(null);
        }
        // Command: Tải thông tin người dùng đang đăng nhập
        [RelayCommand]
        private async Task LoadProfile()
        {
            // Kiểm tra phiên đăng nhập
            if (AuthSession.CurrentUser == null) return;
            // Gọi DB lấy thông tin User + UserDetail (Join bảng)
            var user = await _dbService.GetUserWithDetailAsync(AuthSession.CurrentUser.UserId);
            if (user == null) return;
            // Gán thông tin cơ bản
            AccountName = user.AccountName;
            Email = user.Email;
            // Lấy chữ cái đầu tiên, viết hoa
            Initial = !string.IsNullOrEmpty(user.AccountName) ? user.AccountName[0].ToString().ToUpper() : "U";
            // Gán thông tin chi tiết
            if (user.UserDetail != null)
            {
                FullName = user.UserDetail.FullName;
                Address = user.UserDetail.Address;
                Phone = user.UserDetail.Phone;
                // Nếu ngày sinh null thì lấy ngày hiện tại
                DateOfBirth = user.UserDetail.DateOfBirth;
            }
            _originalState = (FullName, Address, Phone, DateOfBirth);
        }
        // Command: Lưu thông tin chi tiết
        [RelayCommand]
        private async Task SaveInfo()
        {
            // 1. [CHECK] Bắt buộc nhập tên và ngày sinh
            if (string.IsNullOrWhiteSpace(FullName))
            {
                MessageBox.Show("Vui lòng nhập Họ tên!", "Nhắc nhở", MessageBoxButton.OK, MessageBoxImage.Warning);
                FullName = _originalState.Name;
                return;
            }

            if (DateOfBirth.Date > DateTime.Now.Date)
            {
                MessageBox.Show("Ngày sinh không hợp lệ (không được lớn hơn hôm nay)!", "Lỗi nhập liệu", MessageBoxButton.OK, MessageBoxImage.Warning);

                // Hoàn tác về ngày sinh cũ (Nếu null thì lấy ngày hiện tại)
                DateOfBirth = _originalState.Dob ?? DateTime.Now;
                return;
            }
            // 2. [CHECK] Kiểm tra có thay đổi không? (So sánh với _originalState)
            bool isChanged = FullName != _originalState.Name ||
                             Address != _originalState.Address ||
                             Phone != _originalState.Phone ||
                             DateOfBirth.Date != _originalState.Dob?.Date;

            // Nếu không có gì thay đổi -> Dừng luôn (Không hiện thông báo gì cả)
            if (!isChanged) return;

            // 3. Có thay đổi -> Thực hiện Lưu
            try
            {
                await _dbService.SaveUserDetailAsync(AuthSession.CurrentUser.UserId, FullName, Address, Phone, DateOfBirth);

                MessageBox.Show("Cập nhật thành công!");

                // Lưu lại trạng thái mới để lần bấm tiếp theo không báo nữa
                _originalState = (FullName, Address, Phone, DateOfBirth);
            }
            catch (Exception ex)
            {
                MessageBox.Show("Lỗi: " + ex.Message);
            }
        }
        // Command: Mở cửa sổ đổi mật khẩu
        [RelayCommand]
        private void ChangePassword()
        {
            {
                // Tạo và hiển thị cửa sổ ChangePasswordView dưới dạng Dialog (Modal)
                // Người dùng phải đóng cửa sổ này mới thao tác tiếp được màn hình chính
                var win = new ChangePasswordView();
                win.ShowDialog();
            }
        }
    }
}