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

        [ObservableProperty]
        private string _saveBtnContent = "Thêm vở diễn";

        // Danh sách hiển thị
        [ObservableProperty] private ObservableCollection<Show> _shows;

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

        [RelayCommand]
        private async Task LoadShows()
        {
            int genreId = SelectedFilterGenre?.GenreId ?? 0;
            var list = await _dbService.GetShowsAsync(SearchKeyword, genreId);

            // Format hiển thị chuỗi thể loại và diễn viên
            foreach (var s in list)
            {
                s.GenresDisplay = (s.Genres != null && s.Genres.Any())
                    ? string.Join(", ", s.Genres.Select(g => g.GenreName)) : "";
                s.ActorsDisplay = (s.Actors != null && s.Actors.Any())
                    ? string.Join(", ", s.Actors.Select(a => a.FullName)) : "(Chưa có)";
            }
            Shows = new ObservableCollection<Show>(list);
        }

        [RelayCommand]
        private void Edit(Show show)
        {
            if (show == null) return;
            ShowId = show.ShowId;
            Title = show.Title;
            Director = show.Director;
            Duration = show.DurationMinutes;
            PosterUrl = show.PosterImageUrl;
            Description = show.Description;

            // Đánh dấu các thể loại đã chọn
            foreach (var g in GenresList)
                g.IsSelected = show.Genres.Any(x => x.GenreId == g.Genre.GenreId);

            // Đánh dấu các diễn viên đã chọn
            foreach (var a in ActorsList)
                a.IsSelected = show.Actors.Any(x => x.ActorId == a.Actor.ActorId);
        }

        [RelayCommand]
        private void Clear()
        {
            ShowId = 0;
            Title = ""; Director = ""; Duration = 0; PosterUrl = ""; Description = "";
            foreach (var g in GenresList) g.IsSelected = false;
            foreach (var a in ActorsList) a.IsSelected = false;
        }

        [RelayCommand]
        private async Task Save()
        {
            if (string.IsNullOrEmpty(Title)) { MessageBox.Show("Nhập tiêu đề!"); return; }

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

            // Lấy danh sách ID đã chọn
            var selectedGenreIds = GenresList.Where(g => g.IsSelected).Select(g => g.Genre.GenreId).ToList();
            var selectedActorIds = ActorsList.Where(a => a.IsSelected).Select(a => a.Actor.ActorId).ToList();

            try
            {
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
    }
}