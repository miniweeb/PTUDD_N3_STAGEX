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

        // Danh sách hiển thị
        [ObservableProperty] private List<SeatCategory> _categories;

        // Các biến Binding Form
        [ObservableProperty] private int _categoryId;
        [ObservableProperty] private string _categoryName;
        [ObservableProperty] private string _basePriceStr;

        [ObservableProperty] private string _saveBtnContent = "Thêm";
        [ObservableProperty] private bool _isEditing = false;

        public SeatCategoryViewModel()
        {
            _dbService = new DatabaseService();
            LoadCategoriesCommand.Execute(null);
            WeakReferenceMessenger.Default.RegisterAll(this);
        }

        // Định nghĩa message để reload các màn hình khác
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

        // Command: Đổ dữ liệu lên form để sửa khi click nút "Sửa"
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

        // Command: Hủy thao tác sửa, reset form về thêm mới
        [RelayCommand]
        private void Cancel()
        {
            CategoryId = 0;
            CategoryName = "";
            BasePriceStr = "";
            SaveBtnContent = "Thêm";
            IsEditing = false;
        }

        // Command: Lưu hạng ghế (Xử lý cả Thêm và Sửa)
        [RelayCommand]
        private async Task Save()
        {
            // 1. Validate dữ liệu
            if (string.IsNullOrWhiteSpace(CategoryName))
            {
                MessageBox.Show("Vui lòng nhập tên hạng ghế!"); return;
            }

            if (!decimal.TryParse(BasePriceStr, out decimal price)) price = 0;

            // Kiểm tra trùng tên
            var currentCats = await _dbService.GetSeatCategoriesAsync();
            if (currentCats.Any(c => c.CategoryName.Equals(CategoryName.Trim(), StringComparison.OrdinalIgnoreCase) && c.CategoryId != CategoryId))
            {
                MessageBox.Show("Tên hạng ghế đã tồn tại!"); return;
            }

            try
            {
                var cat = new SeatCategory
                {
                    CategoryId = CategoryId,
                    CategoryName = CategoryName,
                    BasePrice = price
                };

                // --- LOGIC CHỌN MÀU ---
                if (CategoryId == 0) // Chỉ sinh màu mới khi Thêm mới
                {
                    // Lấy danh sách các màu đang dùng để tránh trùng
                    var usedColors = currentCats
                                     .Where(c => !string.IsNullOrEmpty(c.ColorClass))
                                     .Select(c => c.ColorClass)
                                     .ToList();

                    // Thêm các màu "Cấm kỵ" (Màu xám của ghế trống/ghế đã bán) vào danh sách tránh
                    // Ví dụ: #505050 (Xám đậm), #D3D3D3 (Xám nhạt), #000000 (Đen), #FFFFFF (Trắng)
                    usedColors.AddRange(new[] { "505050", "808080", "A9A9A9", "D3D3D3", "000000", "FFFFFF" });

                    // Sinh màu mới
                    cat.ColorClass = GenerateSmartColor(usedColors);
                }
                else // Khi sửa, giữ nguyên màu cũ
                {
                    var oldCat = currentCats.FirstOrDefault(c => c.CategoryId == CategoryId);
                    cat.ColorClass = oldCat?.ColorClass ?? GenerateSmartColor(new List<string>());
                }
                // ----------------------------------

                await _dbService.SaveSeatCategoryAsync(cat);

                MessageBox.Show(CategoryId > 0 ? "Cập nhật thành công!" : "Thêm mới thành công!");
                Cancel();

                // Gửi tin nhắn cập nhật và tải lại bảng
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
            if (MessageBox.Show($"Xóa hạng ghế '{cat.CategoryName}'?", "Xác nhận", MessageBoxButton.YesNo) == MessageBoxResult.Yes)
            {
                try
                {
                    await _dbService.DeleteSeatCategoryAsync(cat.CategoryId);
                    await LoadCategories();
                    WeakReferenceMessenger.Default.Send(new SeatCategoryChangedMessage("Deleted"));
                }
                catch
                {
                    MessageBox.Show("Không thể xóa (Đang được sử dụng).");
                }
            }
        }

        //--------PHẦN LOGIC THUẬT TOÁN MÀU SẮC------------
        // Hàm sinh màu Hex ngẫu nhiên, tránh màu xám và tránh trùng lặp
        private string GenerateSmartColor(List<string> excludedColors)
        {
            Random rand = new Random();
            int attempts = 0;

            while (attempts < 100) // Thử tối đa 100 lần
            {
                attempts++;

                // 1. Sinh ngẫu nhiên RGB
                byte r = (byte)rand.Next(0, 256);
                byte g = (byte)rand.Next(0, 256);
                byte b = (byte)rand.Next(0, 256);

                // 2. Kiểm tra bộ lọc "Chống Xám / Quá tối / Quá sáng"
                if (IsColorBad(r, g, b)) continue;

                // 3. Chuyển sang chuỗi Hex
                string newHex = $"{r:X2}{g:X2}{b:X2}";

                // 4. Kiểm tra độ trùng lặp với các màu đã có
                if (!IsColorTooClose(newHex, excludedColors))
                {
                    return newHex; // Màu tốt -> Trả về ngay
                }
            }

            // Nếu không tìm được (rất hiếm), trả về màu đỏ mặc định
            return "E74C3C";
        }

        // Kiểm tra xem màu có bị "xấu" (xám, tối, sáng quá) không
        private bool IsColorBad(byte r, byte g, byte b)
        {
            // Tính độ chênh lệch (Delta) giữa thành phần lớn nhất và nhỏ nhất
            // Nếu R, G, B gần bằng nhau => Màu xám hoặc trắng/đen
            int max = Math.Max(r, Math.Max(g, b));
            int min = Math.Min(r, Math.Min(g, b));

            if ((max - min) < 40) return true; // Loại bỏ màu xám/nhạt

            // Tính độ sáng trung bình (Brightness)
            double brightness = (r * 0.299 + g * 0.587 + b * 0.114);

            // Loại bỏ quá tối (<50) hoặc quá sáng (>220) để chữ hiển thị rõ
            if (brightness < 50 || brightness > 220) return true;

            return false;
        }

        // Kiểm tra xem màu mới có quá giống các màu cũ không
        private bool IsColorTooClose(string newHex, List<string> existingHexes)
        {
            foreach (var existing in existingHexes)
            {
                if (string.IsNullOrEmpty(existing)) continue;

                // Chuẩn hóa chuỗi hex (bỏ dấu # nếu có)
                string hex1 = newHex.Trim('#');
                string hex2 = existing.Trim('#');

                if (hex1.Length != 6 || hex2.Length != 6) continue;

                // Tính khoảng cách màu
                double distance = GetColorDistance(hex1, hex2);

                // Nếu khoảng cách < 60 (ngưỡng giống nhau), coi như bị trùng
                if (distance < 60) return true;
            }
            return false;
        }

        // Tính khoảng cách Euclid giữa 2 màu Hex
        private double GetColorDistance(string hex1, string hex2)
        {
            try
            {
                // Parse thủ công từ Hex sang R, G, B (tránh lỗi thiếu thư viện)
                byte r1 = Convert.ToByte(hex1.Substring(0, 2), 16);
                byte g1 = Convert.ToByte(hex1.Substring(2, 2), 16);
                byte b1 = Convert.ToByte(hex1.Substring(4, 2), 16);

                byte r2 = Convert.ToByte(hex2.Substring(0, 2), 16);
                byte g2 = Convert.ToByte(hex2.Substring(2, 2), 16);
                byte b2 = Convert.ToByte(hex2.Substring(4, 2), 16);

                // Công thức khoảng cách
                return Math.Sqrt(Math.Pow(r1 - r2, 2) + Math.Pow(g1 - g2, 2) + Math.Pow(b1 - b2, 2));
            }
            catch
            {
                return 0; // Nếu lỗi parse thì coi như trùng nhau để an toàn
            }
        }
    }
}