using System;
using System.Globalization;
using System.Windows.Data;

namespace StageX_DesktopApp.Utilities
{
    // Implements IMultiValueConverter để xử lý MultiBinding
    public class MultiValueConverter : IMultiValueConverter
    {
        // Convert: Nhận vào một mảng các giá trị (values) từ nhiều nguồn binding
        public object Convert(object[] values, Type targetType, object parameter, CultureInfo culture)
        {
            // Trả về bản sao của mảng values.
            // ViewModel sẽ nhận được object[] chứa các control hoặc dữ liệu được binding.
            return values.Clone(); // Trả về mảng object
        }
        // ConvertBack: Không hỗ trợ chiều ngược lại
        public object[] ConvertBack(object value, Type[] targetTypes, object parameter, CultureInfo culture) => null;
    }
}