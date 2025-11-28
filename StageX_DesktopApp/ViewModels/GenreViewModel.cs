using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using StageX_DesktopApp.Models;
using StageX_DesktopApp.Services;
using System;
using System.Collections.ObjectModel;
using System.Threading.Tasks;
using System.Windows;

namespace StageX_DesktopApp.ViewModels
{
    public partial class GenreViewModel : ObservableObject
    {
        private readonly DatabaseService _dbService;

        [ObservableProperty] private ObservableCollection<Genre> _genres;

        // --- CÁC BIẾN DÙNG CHUNG CHO FORM ---
        [ObservableProperty] private int _currentId = 0; // 0 = Thêm mới, >0 = Cập nhật
        [ObservableProperty] private string _currentName;

        // Điều khiển giao diện nút bấm
        [ObservableProperty] private string _saveButtonContent = "Thêm";
        [ObservableProperty] private bool _isEditing = false; // Để hiện nút Hủy

        public GenreViewModel()
        {
            _dbService = new DatabaseService();
            LoadGenres();
        }

        [RelayCommand]
        private async Task LoadGenres()
        {
            var list = await _dbService.GetGenresAsync();
            Genres = new ObservableCollection<Genre>(list);
        }

        // Hàm xử lý chính cho nút Lưu (Tự động hiểu là Thêm hay Sửa)
        [RelayCommand]
        private async Task SaveData()
        {
            if (string.IsNullOrWhiteSpace(CurrentName))
            {
                MessageBox.Show("Tên thể loại không được để trống!");
                return;
            }
            string newName = CurrentName.Trim();
            bool isDuplicate = Genres.Any(g =>
        g.GenreName.Equals(newName, StringComparison.OrdinalIgnoreCase) &&
        g.GenreId != CurrentId);

            if (isDuplicate)
            {
                MessageBox.Show($"Thể loại '{newName}' đã tồn tại! Vui lòng chọn tên khác.",
                                "Lỗi trùng lặp",
                                MessageBoxButton.OK,
                                MessageBoxImage.Warning);
                return; // Dừng lại, không lưu
            }
            try
            {
                // Tạo object (ID = 0 nếu thêm mới, ID > 0 nếu sửa)
                var genre = new Genre { GenreId = CurrentId, GenreName = CurrentName.Trim() };

                // Gọi Service (Service sẽ tự check ID để Insert hoặc Update)
                await _dbService.SaveGenreAsync(genre);

                if (CurrentId == 0) MessageBox.Show("Thêm mới thành công!");
                else MessageBox.Show("Cập nhật thành công!");

                ResetForm();     // Reset về trạng thái thêm mới
                await LoadGenres(); // Tải lại danh sách
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi: {ex.Message}");
            }
        }

        // Khi bấm nút "Sửa" trên bảng
        [RelayCommand]
        private void Edit(Genre genre)
        {
            if (genre == null) return;

            // Đổ dữ liệu lên Form
            CurrentId = genre.GenreId;
            CurrentName = genre.GenreName;

            // Đổi trạng thái giao diện
            SaveButtonContent = "Cập nhật";
            IsEditing = true; // Hiện nút Hủy
        }

        // Khi bấm nút "Hủy"
        [RelayCommand]
        private void Cancel()
        {
            ResetForm();
        }

        // Hàm đưa Form về trạng thái ban đầu
        private void ResetForm()
        {
            CurrentId = 0;
            CurrentName = "";
            SaveButtonContent = "Thêm";
            IsEditing = false; // Ẩn nút Hủy
        }

        [RelayCommand]
        private async Task Delete(Genre genre)
        {
            if (MessageBox.Show($"Xóa thể loại '{genre.GenreName}'?", "Xác nhận", MessageBoxButton.YesNo, MessageBoxImage.Warning) == MessageBoxResult.Yes)
            {
                try
                {
                    await _dbService.DeleteGenreAsync(genre.GenreId);
                    await LoadGenres();
                    // Nếu đang sửa đúng cái vừa xóa thì reset form luôn
                    if (CurrentId == genre.GenreId) ResetForm();
                }
                catch
                {
                    MessageBox.Show("Không thể xóa (Đang được sử dụng).");
                }
            }
        }
    }
}