using System.Windows;
using System.Windows.Controls;
using StageX_DesktopApp.ViewModels;

namespace StageX_DesktopApp.Views
{
    public partial class AccountView : UserControl
    {
        public AccountView()
        {
            InitializeComponent();
        }
        // Xử lý sự kiện Click của nút Lưu
        private void SaveButton_Click(object sender, RoutedEventArgs e)
        {
            // 1. Lấy ViewModel từ DataContext của UserControl
            if (this.DataContext is AccountViewModel vm)
            {
                // 2. Gọi lệnh Save trong ViewModel
                // Truyền trực tiếp control 'PasswordBox' vào làm tham số
                vm.SaveCommand.Execute(this.PasswordBox);
            }
        }
    }
}