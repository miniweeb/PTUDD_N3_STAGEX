using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using StageX_DesktopApp.Models;
using StageX_DesktopApp.Services;
using StageX_DesktopApp.Utilities;
using StageX_DesktopApp.Views;
using System.Windows;

namespace StageX_DesktopApp.ViewModels
{
    public partial class MainViewModel : ObservableObject
    {
        // ======= FIELDS + PROPERTIES THƯỜNG (KHÔNG DÙNG [ObservableProperty]) =======

        private object _currentView;
        public object CurrentView
        {
            get => _currentView;
            set => SetProperty(ref _currentView, value);
        }

        private string _windowTitle;
        public string WindowTitle
        {
            get => _windowTitle;
            set => SetProperty(ref _windowTitle, value);
        }

        private Visibility _adminVisibility = Visibility.Collapsed;
        public Visibility AdminVisibility
        {
            get => _adminVisibility;
            set => SetProperty(ref _adminVisibility, value);
        }

        private Visibility _staffVisibility = Visibility.Collapsed;
        public Visibility StaffVisibility
        {
            get => _staffVisibility;
            set => SetProperty(ref _staffVisibility, value);
        }

        private string _selectedMenu;
        public string SelectedMenu
        {
            get => _selectedMenu;
            set => SetProperty(ref _selectedMenu, value);
        }

        // ================== CONSTRUCTOR ==================

        public MainViewModel()
        {
            LoadUserInfo();
        }

        private void LoadUserInfo()
        {
            var user = AuthSession.CurrentUser;
            if (user == null)
            {
                WindowTitle = "StageX";
                return;
            }

            WindowTitle = $"StageX - Đã đăng nhập: {user.AccountName} ({user.Role})";

            if (user.Role == "Admin")
            {
                AdminVisibility = Visibility.Visible;
                StaffVisibility = Visibility.Collapsed;
                NavigateDashboard();      // mặc định vào Dashboard
            }
            else
            {
                AdminVisibility = Visibility.Collapsed;
                StaffVisibility = Visibility.Visible;
                NavigateSellTicket();     // mặc định vào Bán vé
            }
        }

        private void NavigateTo(object view, string menuName)
        {
            CurrentView = view;
            SelectedMenu = menuName;
            SoundManager.PlayClick();
        }

        // ================== COMMAND ĐIỀU HƯỚNG ==================

        [RelayCommand]
        private void NavigateDashboard() => NavigateTo(new DashboardView(), "Dashboard");

        [RelayCommand]
        private void NavigatePerformance() => NavigateTo(new PerformanceView(), "Performance");

        [RelayCommand]
        private void NavigateShow() => NavigateTo(new ShowManagementView(), "Show");

        [RelayCommand]
        private void NavigateTheater() => NavigateTo(new TheaterSeatView(), "Theater");

        [RelayCommand]
        private void NavigateActor() => NavigateTo(new ActorManagementView(), "Actor");

        [RelayCommand]
        private void NavigateGenre() => NavigateTo(new GenreManagementView(), "Genre");

        [RelayCommand]
        private void NavigateAccount() => NavigateTo(new AccountView(), "Account");

        [RelayCommand]
        private void NavigateSellTicket() => NavigateTo(new SellTicketView(), "SellTicket");

        [RelayCommand]
        private void NavigateBooking() => NavigateTo(new BookingManagementView(), "Booking");

        // Màn hình “Quản lý vé”
        [RelayCommand]
        private void NavigateTicketScan() => NavigateTo(new TicketScanView(), "TicketScan");

        [RelayCommand]
        private void NavigateProfile() => NavigateTo(new ProfileView(), "Profile");

        [RelayCommand]
        private void Logout()
        {
            SoundManager.PlayLogout();
            AuthSession.Logout();

            var loginWindow = new LoginView();
            loginWindow.Show();

            foreach (Window window in Application.Current.Windows)
            {
                if (window is MainWindow)
                {
                    window.Close();
                    break;
                }
            }
        }
    }
}