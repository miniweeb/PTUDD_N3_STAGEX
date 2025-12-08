using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Org.BouncyCastle.Utilities;
using StageX_DesktopApp.Models;
using StageX_DesktopApp.Services;
using System;
using System.Collections.ObjectModel;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;

namespace StageX_DesktopApp.ViewModels
{
    // Wrapper để hỗ trợ chọn nhiều trong ListBox
    public partial class SelectableGenre : ObservableObject
    {
        public Genre Genre { get; set; }
        [ObservableProperty] private bool _isSelected;
        public string Name => Genre.GenreName;
    }

    public partial class SelectableActor : ObservableObject
    {
        public Actor Actor { get; set; }
        [ObservableProperty] private bool _isSelected;
        public string Name => Actor.FullName;
    }

    public partial class ShowViewModel : ObservableObject
    {
        private readonly DatabaseService _dbService;

        // Danh sách hiển thị
        [ObservableProperty] private ObservableCollection<Show> _shows;
        [ObservableProperty] private string _saveBtnContent = "Thêm";

        // Dữ liệu cho các ListBox chọn nhiều
        [ObservableProperty] private ObservableCollection<SelectableGenre> _genresList;
        [ObservableProperty] private ObservableCollection<SelectableActor> _actorsList;

        // Dữ liệu cho Filter
        [ObservableProperty] private ObservableCollection<Genre> _filterGenres;
        [ObservableProperty] private Genre _selectedFilterGenre;
        [ObservableProperty] private string _searchKeyword;

        // Form Fields
        [ObservableProperty] private int _showId;
        [ObservableProperty] private string _title;
        [ObservableProperty] private string _director;
        [ObservableProperty] private int _duration;
        [ObservableProperty] private string _posterUrl;
        [ObservableProperty] private string _description;

        public ShowViewModel()
        {
            _dbService = new DatabaseService();
            LoadInitDataCommand.Execute(null);
        }

        // Command: Tải dữ liệu nguồn (Thể loại, Diễn viên) và thiết lập bộ lọc
        [RelayCommand]
        private async Task LoadInitData()
        {
            // 1. Tải danh sách thể loại và diễn viên gốc
            var genres = await _dbService.GetGenresAsync();
            var actors = await _dbService.GetActiveActorsAsync();

            // 2. Chuyển sang dạng Selectable cho Form
            GenresList = new ObservableCollection<SelectableGenre>(genres.Select(g => new SelectableGenre { Genre = g }));
            ActorsList = new ObservableCollection<SelectableActor>(actors.Select(a => new SelectableActor { Actor = a }));

            // 3. Tạo dữ liệu cho Filter (thêm mục "Tất cả")
            var filters = genres.ToList();
            filters.Insert(0, new Genre { GenreId = 0, GenreName = "-- Tất cả --" });
            FilterGenres = new ObservableCollection<Genre>(filters);
            SelectedFilterGenre = FilterGenres[0];

            // 4. Tải danh sách vở diễn
            await LoadShows();
        }

        // Tải danh sách vở diễn (có hỗ trợ tìm kiếm)
        [RelayCommand]
        private async Task LoadShows()
        {
            // Lấy ID thể loại cần lọc (nếu null thì coi như là 0 - Tất cả)
            int genreId = SelectedFilterGenre?.GenreId ?? 0;
            var list = await _dbService.GetShowsAsync(SearchKeyword, genreId);

            // Xử lý hiển thị chuỗi danh sách (Format String) cho cột Thể loại và Diễn viên
            foreach (var s in list)
            {
                // Nối tên các thể loại thành chuỗi: "Hài, Kịch, Tâm lý"
                s.GenresDisplay = (s.Genres != null && s.Genres.Any())
                    ? string.Join(", ", s.Genres.Select(g => g.GenreName)) : "";

                // Nối tên các diễn viên thành chuỗi
                s.ActorsDisplay = (s.Actors != null && s.Actors.Any())
                    ? string.Join(", ", s.Actors.Select(a => a.FullName)) : "(Chưa có)";
            }
            // Gán vào biến _shows để giao diện cập nhật
            Shows = new ObservableCollection<Show>(list);
        }

        // --- LOGIC ĐỔ DỮ LIỆU ĐỂ SỬA ---
        [RelayCommand]
        private void Edit(Show show)
        {
            if (show == null) return;

            // Gán thông tin cơ bản lên các ô nhập liệu
            ShowId = show.ShowId;
            Title = show.Title;
            Director = show.Director;
            Duration = show.DurationMinutes;
            PosterUrl = show.PosterImageUrl;
            Description = show.Description;

            // Đổi nút lưu thành "Cập nhật" để người dùng biết đang sửa
            SaveBtnContent = "Cập nhật";

            // Xử lý CheckBox Thể loại: Duyệt qua list CheckBox, nếu ID khớp với show đang sửa thì tick chọn (IsSelected = true)
            foreach (var g in GenresList)
                g.IsSelected = show.Genres.Any(x => x.GenreId == g.Genre.GenreId);
            // Xử lý CheckBox Diễn viên: Tương tự như trên
            foreach (var a in ActorsList)
                a.IsSelected = show.Actors.Any(x => x.ActorId == a.Actor.ActorId);
        }

        // Command: Xóa trắng form để chuẩn bị Thêm mới
        [RelayCommand]
        private void Clear()
        {
            ShowId = 0;
            Title = ""; Director = ""; Duration = 0; PosterUrl = ""; Description = "";
            foreach (var g in GenresList) g.IsSelected = false;
            foreach (var a in ActorsList) a.IsSelected = false; 
            SaveBtnContent = "Thêm";
        }

        // Command: Lưu dữ liệu (Xử lý cả Thêm mới và Cập nhật)
        [RelayCommand]
        private async Task Save()
        {
            // 1. Validation: Kiểm tra dữ liệu đầu vào
            if (string.IsNullOrWhiteSpace(Title) ||
        string.IsNullOrWhiteSpace(Director) ||
        string.IsNullOrWhiteSpace(PosterUrl) ||
        string.IsNullOrWhiteSpace(Description) ||
        Duration <= 0)
            {
                MessageBox.Show("Vui lòng nhập đầy đủ thông tin",
                                "Thiếu thông tin", MessageBoxButton.OK, MessageBoxImage.Warning);
                return; // Dừng lại, không chạy tiếp
            }

            // 2. Tạo đối tượng Model từ dữ liệu nhập
            var show = new Show
            {
                ShowId = ShowId,
                Title = Title,
                Director = Director,
                DurationMinutes = Duration,
                PosterImageUrl = PosterUrl,
                Description = Description,
                Status = "Sắp chiếu" // Mặc định
            };

            // 3. Lấy danh sách ID của các Thể loại và Diễn viên được tick chọn
            var selectedGenreIds = GenresList.Where(g => g.IsSelected).Select(g => g.Genre.GenreId).ToList();
            var selectedActorIds = ActorsList.Where(a => a.IsSelected).Select(a => a.Actor.ActorId).ToList();

            try
            {
                // 4. Gọi Service để lưu (Hàm này sẽ xử lý transaction lưu bảng Show và các bảng trung gian)
                await _dbService.SaveShowAsync(show, selectedGenreIds, selectedActorIds);
                MessageBox.Show(ShowId > 0 ? "Cập nhật thành công!" : "Thêm mới thành công!");
                Clear();
                await LoadShows();
            }
            catch (Exception ex)
            {
                MessageBox.Show("Lỗi: " + ex.Message);
            }
        }

        // Command: Xóa vở diễn
        [RelayCommand]
        private async Task Delete(Show show)
        {
            if (show == null) return;

            // 1. Hỏi xác nhận người dùng trước
            var result = MessageBox.Show($"Bạn có chắc chắn muốn xóa vở diễn '{show.Title}' không?",
                                         "Xác nhận xóa",
                                         MessageBoxButton.YesNo,
                                         MessageBoxImage.Warning);

            if (result == MessageBoxResult.Yes)
            {
                try
                {
                    // 2. Kiểm tra điều kiện: Có suất diễn chưa?
                    bool hasPerformances = await _dbService.HasPerformancesAsync(show.ShowId);

                    if (hasPerformances)
                    {
                        MessageBox.Show($"Không thể xóa vở diễn '{show.Title}' vì đã có suất diễn được tạo.\nHãy xóa các suất diễn trước.",
                                        "Không thể xóa",
                                        MessageBoxButton.OK,
                                        MessageBoxImage.Error);
                        return; // Dừng lại, không xóa
                    }

                    // 3. Nếu thỏa điều kiện -> Gọi Service xóa
                    await _dbService.DeleteShowAsync(show.ShowId);

                    MessageBox.Show("Đã xóa vở diễn thành công!");

                    // 4. Reset form nếu đang sửa chính vở vừa xóa
                    if (ShowId == show.ShowId)
                    {
                        Clear();
                    }

                    // 5. Tải lại danh sách
                    await LoadShows();
                }
                catch (Exception ex)
                {
                    MessageBox.Show("Lỗi khi xóa: " + ex.Message);
                }
            }
        }
    }
}