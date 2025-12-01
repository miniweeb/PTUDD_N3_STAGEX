using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using CommunityToolkit.Mvvm.Messaging;
using StageX_DesktopApp.Models;
using StageX_DesktopApp.Services;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;

namespace StageX_DesktopApp.ViewModels
{
    public partial class SeatCategoryViewModel : ObservableObject
    {
        private readonly DatabaseService _dbService;

        [ObservableProperty] private List<SeatCategory> _categories;

        [ObservableProperty] private int _categoryId;
        [ObservableProperty] private string _categoryName;
        [ObservableProperty] private string _basePriceStr;
        [ObservableProperty] private string _saveBtnContent = "Thêm";
        [ObservableProperty] private bool _isEditing = false;

        // Bảng màu cố định (15 màu)
        private readonly string[] _safeColors = {
            "E74C3C", "8E44AD", "3498DB", "1ABC9C", "27AE60",
            "F1C40F", "E67E22", "D35400", "C0392B", "9B59B6",
            "2980B9", "16A085", "F39C12", "7F8C8D", "2C3E50"
        };

        public SeatCategoryViewModel()
        {
            _dbService = new DatabaseService();
            LoadCategoriesCommand.Execute(null);
            WeakReferenceMessenger.Default.RegisterAll(this);
        }

        public class SeatCategoryChangedMessage
        {
            public string Value { get; }
            public SeatCategoryChangedMessage(string value) => Value = value;
        }

        [RelayCommand]
        private async Task LoadCategories()
        {
            Categories = await _dbService.GetSeatCategoriesAsync();
        }

        [RelayCommand]
        private void Edit(SeatCategory cat)
        {
            if (cat == null) return;
            CategoryId = cat.CategoryId;
            CategoryName = cat.CategoryName;
            BasePriceStr = cat.BasePrice.ToString("F0");
            SaveBtnContent = "Lưu";
            IsEditing = true;
        }

        [RelayCommand]
        private void Cancel()
        {
            CategoryId = 0;
            CategoryName = "";
            BasePriceStr = "";
            SaveBtnContent = "Thêm";
            IsEditing = false;
        }

        [RelayCommand]
        private async Task Save()
        {
            if (string.IsNullOrWhiteSpace(CategoryName) || CategoryName.Contains("Tên hạng"))
            {
                MessageBox.Show("Vui lòng nhập tên hạng ghế hợp lệ!", "Lỗi nhập liệu", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            decimal.TryParse(BasePriceStr, out decimal price);

            // [FIX 1]: Lấy danh sách mới nhất từ DB để kiểm tra trùng tên
            var currentCats = await _dbService.GetSeatCategoriesAsync();

            if (currentCats.Any(c => c.CategoryName.Trim().Equals(CategoryName.Trim(), StringComparison.OrdinalIgnoreCase) && c.CategoryId != CategoryId))
            {
                MessageBox.Show($"Tên hạng ghế '{CategoryName}' đã tồn tại!", "Trùng dữ liệu", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            try
            {
                var cat = new SeatCategory
                {
                    CategoryId = CategoryId,
                    CategoryName = CategoryName,
                    BasePrice = price
                };

                // [FIX 2]: Xử lý màu sắc CHÍNH XÁC HƠN
                if (CategoryId == 0) // Thêm mới
                {
                    // Lấy tất cả các màu đang được sử dụng trong DB (Trim + Upper để so sánh chuẩn)
                    var usedColors = currentCats
                                     .Where(c => !string.IsNullOrEmpty(c.ColorClass))
                                     .Select(c => c.ColorClass.Trim().ToUpper())
                                     .ToList();

                    // Lọc ra các màu trong bảng mẫu CHƯA bị dùng
                    var availableColors = _safeColors
                                          .Where(safeColor => !usedColors.Contains(safeColor.ToUpper()))
                                          .ToList();

                    if (availableColors.Count == 0)
                    {
                        MessageBox.Show("Đã dùng hết 15 màu hiển thị! Không thể thêm hạng ghế mới.", "Hết màu", MessageBoxButton.OK, MessageBoxImage.Error);
                        return;
                    }

                    // Chọn ngẫu nhiên 1 màu trong số màu CÒN TRỐNG
                    cat.ColorClass = availableColors[new Random().Next(availableColors.Count)];
                }
                else // Cập nhật
                {
                    var oldCat = currentCats.FirstOrDefault(c => c.CategoryId == CategoryId);
                    cat.ColorClass = oldCat?.ColorClass ?? _safeColors[0];
                }

                await _dbService.SaveSeatCategoryAsync(cat);

                MessageBox.Show(CategoryId > 0 ? "Cập nhật thành công!" : "Thêm mới thành công!");
                Cancel();

                WeakReferenceMessenger.Default.Send(new SeatCategoryChangedMessage("Updated"));
                await LoadCategories();
            }
            catch (Exception ex)
            {
                MessageBox.Show("Lỗi: " + ex.Message);
            }
        }

        [RelayCommand]
        private async Task Delete(SeatCategory cat)
        {
            if (cat == null) return;
            if (MessageBox.Show($"Xóa hạng ghế '{cat.CategoryName}'?", "Xác nhận xóa", MessageBoxButton.YesNo, MessageBoxImage.Warning) == MessageBoxResult.Yes)
            {
                try
                {
                    await _dbService.DeleteSeatCategoryAsync(cat.CategoryId);
                    await LoadCategories();
                    WeakReferenceMessenger.Default.Send(new SeatCategoryChangedMessage("Deleted"));
                }
                catch
                {
                    MessageBox.Show("Không thể xóa hạng ghế này (Đang được sử dụng).");
                }
            }
        }
    }
}