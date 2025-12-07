using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using StageX_DesktopApp.Models;
using StageX_DesktopApp.Services;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using System.Windows;

namespace StageX_DesktopApp.ViewModels
{
    public partial class ActorViewModel : ObservableObject
    {
        private readonly DatabaseService _dbService;

        // Danh sách diễn viên hiển thị trên DataGrid
        [ObservableProperty] private List<Actor> _actors;

        // Từ khóa tìm kiếm (Tên, Nghệ danh...)
        [ObservableProperty] private string _searchKeyword;

        // --- CÁC BIẾN BINDING CHO FORM NHẬP LIỆU ---
        [ObservableProperty] private int _id;
        [ObservableProperty] private string _fullName;
        [ObservableProperty] private string _nickName;
        [ObservableProperty] private string _email;
        [ObservableProperty] private string _phone;     
        [ObservableProperty] private DateTime? _dateOfBirth;
        // Index cho ComboBox trạng thái (0: Hoạt động, 1: Ngừng hoạt động)
        [ObservableProperty] private int _statusIndex = 0;
        // Index cho ComboBox giới tính (0: Nam, 1: Nữ, 2: Khác)
        [ObservableProperty] private int _genderIndex = 0;
        [ObservableProperty] private string _saveButtonContent = "Lưu Diễn viên";

        public ActorViewModel()
        {
            _dbService = new DatabaseService();
            LoadActorsCommand.Execute(null); // Tải dữ liệu khi khởi tạo
        }

        // Command: Tìm kiếm diễn viên theo từ khóa (SearchKeyword)
        [RelayCommand]
        private async Task LoadActors()
        {
            Actors = await _dbService.GetActorsAsync(SearchKeyword);
        }

        // Command: Đổ dữ liệu diễn viên được chọn lên Form để chỉnh sửa
        [RelayCommand]
        private void Edit(Actor actor)
        {
            if (actor == null) return;
            Id = actor.ActorId;
            FullName = actor.FullName;
            NickName = actor.NickName;
            DateOfBirth = actor.DateOfBirth;

            // Map chuỗi trạng thái từ DB sang index ComboBox
            StatusIndex = (actor.Status == "Ngừng hoạt động") ? 1 : 0;

            // Map chuỗi giới tính sang index ComboBox
            GenderIndex = actor.Gender switch
            {
                "Nữ" => 1,
                "Khác" => 2,
                _ => 0
            };
            SaveButtonContent = "Cập nhật";
        }

        // Command: Xóa form, đưa về trạng thái thêm mới
        [RelayCommand]
        private void Clear()
        {
            Id = 0; // ID = 0 đánh dấu là thêm mới
            FullName = "";
            NickName = ""; DateOfBirth = null;
            StatusIndex = 0; GenderIndex = 0;
            SaveButtonContent = "Lưu Diễn viên";
        }

        // Command: Lưu diễn viên (Xử lý cả Thêm mới và Cập nhật)
        [RelayCommand]
        private async Task Save()
        {
            // Validate dữ liệu cơ bản
            if (string.IsNullOrWhiteSpace(FullName))
            {
                MessageBox.Show("Vui lòng nhập tên!");
                return;
            }

            // Chuyển đổi Index từ ComboBox thành chuỗi để lưu xuống DB
            string genderStr = GenderIndex switch { 1 => "Nữ", 2 => "Khác", _ => "Nam" };
            string statusStr = StatusIndex == 1 ? "Ngừng hoạt động" : "Hoạt động";
            var actor = new Actor
            {
                ActorId = Id,
                FullName = FullName,
                NickName = NickName,
                DateOfBirth = DateOfBirth,
                Gender = genderStr,
                Email = Email,
                Phone = Phone,
                Status = statusStr
            };

            try
            {
                // Gọi Service thực hiện Upsert (Insert hoặc Update)
                await _dbService.SaveActorAsync(actor);

                MessageBox.Show(Id > 0 ? "Cập nhật thành công!" : "Thêm thành công!");

                Clear();
                await LoadActors(); // Tải lại danh sách
            }
            catch (Exception ex)
            {
                MessageBox.Show("Lỗi lưu: " + ex.Message);
            }
        }

        // Command: Xóa diễn viên
        [RelayCommand]
        private async Task Delete(Actor actor)
        {
            if (actor == null) return;
            if (MessageBox.Show($"Xóa diễn viên '{actor.FullName}'?", "Xác nhận", MessageBoxButton.YesNo) == MessageBoxResult.Yes)
            {
                try
                {
                    // Gọi Service xóa. Nếu diễn viên đang tham gia vở diễn nào đó,
                    // DB sẽ báo lỗi ràng buộc khóa ngoại (Foreign Key Constraint)
                    await _dbService.DeleteActorAsync(actor.ActorId);
                    await LoadActors();
                    MessageBox.Show("Đã xóa tài khoản thành công!", "Thông báo", MessageBoxButton.OK, MessageBoxImage.Information);
                }
                catch
                {
                    // Bắt lỗi từ DB trả về để thông báo cho người dùng
                    MessageBox.Show("Không thể xóa (Diễn viên đang tham gia vở diễn)!");
                }
            }
        }
    }
}