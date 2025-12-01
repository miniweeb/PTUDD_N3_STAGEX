using System.Windows;
using System.Text;
using StageX_DesktopApp.Views; // Thêm dòng này

namespace StageX_DesktopApp
{
    public partial class App : Application
    {
        public App()
        {
            // [2] QUAN TRỌNG: Dòng này nạp bảng mã 1252 cho .NET 9
            // Phải đặt ngay dòng đầu tiên của Constructor
            System.Text.Encoding.RegisterProvider(System.Text.CodePagesEncodingProvider.Instance);
        }
        protected override void OnStartup(StartupEventArgs e)

        {
            base.OnStartup(e);

            // Mở LoginView mới
            var loginWindow = new LoginView();
            loginWindow.Show();
        }
    }
}