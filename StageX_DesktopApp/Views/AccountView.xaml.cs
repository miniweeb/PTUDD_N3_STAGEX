using System.Windows;
using System.Windows.Controls;
using StageX_DesktopApp.ViewModels;

namespace StageX_DesktopApp.Views
{
    /// <summary>
    /// Interaction logic for AccountView.xaml
    /// </summary>
    public partial class AccountView : UserControl
    {
        public AccountView()
        {
            InitializeComponent();
            // Mọi logic gửi mail, lưu DB đã nằm bên AccountViewModel
        }
        private void SaveButton_Click(object sender, RoutedEventArgs e)
        {
            // 1. Lấy ViewModel từ DataContext của UserControl
            if (this.DataContext is AccountViewModel vm)
            {
                // 2. Gọi lệnh Save và truyền trực tiếp điều khiển PasswordBox vào
                // 'this.PasswordBox' là tên bạn đã đặt bên file XAML
                vm.SaveCommand.Execute(this.PasswordBox);
            }
        }
    }
}