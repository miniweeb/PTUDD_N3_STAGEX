using System;
using System.Globalization;
using System.Windows.Data;

// QUAN TRỌNG: Namespace phải khớp với khai báo xmlns:util trong App.xaml
namespace StageX_DesktopApp.Utilities
{
    // Class phải là PUBLIC
    public class InvertBoolConverter : IValueConverter
    {
        // Chuyển đổi: True -> False, False -> True
        public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
        {
            // Chuyển từ ViewModel -> View
            if (value is bool booleanValue)
            {
                return !booleanValue;
            }
            return false;
        }
        // Chuyển từ View -> ViewModel
        public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
        {
            if (value is bool booleanValue)
            {
                return !booleanValue;
            }
            return false;
        }
    }
}