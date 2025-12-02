using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Windows.Media; 

namespace StageX_DesktopApp.Models
{
    [Table("seat_categories")]
    public class SeatCategory
    {
        [Key]
        [Column("category_id")]
        public int CategoryId { get; set; }

        [Column("category_name")]
        public string CategoryName { get; set; }

        [Column("base_price")]
        public decimal BasePrice { get; set; }

        [Column("color_class")]
        public string ColorClass { get; set; } // Ví dụ: "c0d6efd"

        /// Tự động chuyển ColorClass (string) thành màu (Brush)
        [NotMapped]
        public SolidColorBrush DisplayColor
        {
            get
            {
                string colorHex = ColorClass;
                if (string.IsNullOrEmpty(colorHex))
                    return Brushes.LightGray;

                // Xóa chữ 'c' ở đầu nếu có (từ CSDL PHP cũ)
                if (colorHex.StartsWith("c"))
                {
                    colorHex = colorHex.Substring(1);
                }

                try
                {
                    // Chuyển #c0d6efd thành màu
                    return (SolidColorBrush)new BrushConverter().ConvertFrom("#" + colorHex);
                }
                catch
                {
                    return Brushes.LightGray; // Trả về màu xám nếu lỗi
                }
            }
        }
    }
}