using Microsoft.EntityFrameworkCore;
using StageX_DesktopApp.Data;
using StageX_DesktopApp.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace StageX_DesktopApp.Services
{
    public class DatabaseService
    {
        // =================================================================================
        // #REGION: USER & AUTHENTICATION (QUẢN LÝ TÀI KHOẢN & ĐĂNG NHẬP)
        // =================================================================================
        #region User & Auth

        /// <summary>
        /// Tìm User theo Email hoặc Tên đăng nhập để xử lý đăng nhập.
        /// (Giữ nguyên LINQ vì đơn giản và cần trả về Object User đầy đủ để check pass)
        /// </summary>
        public async Task<User?> GetUserByIdentifierAsync(string identifier)
        {
            using (var context = new AppDbContext())
            {
                return await context.Users
                    .FirstOrDefaultAsync(u => u.Email == identifier || u.AccountName == identifier);
            }
        }

        /// <summary>
        /// Lấy danh sách nhân viên và admin (Sử dụng SP có sẵn trong DB)
        /// </summary>
        public async Task<List<User>> GetAdminStaffUsersAsync()
        {
            using (var context = new AppDbContext())
            {
                // Gọi SP: proc_get_admin_staff_users
                return await context.Users
                    .FromSqlRaw("CALL proc_get_admin_staff_users()")
                    .ToListAsync();
            }
        }

        /// <summary>
        /// Kiểm tra trùng lặp Email hoặc Tên tài khoản (Sử dụng SP)
        /// </summary>
        public async Task<bool> CheckUserExistsAsync(string email, string accountName)
        {
            using (var context = new AppDbContext())
            {
                // Có thể dùng LINQ hoặc SP. Dùng SP proc_check_user_exists cho tối ưu
                // Tuy nhiên hàm SP này trả về Count, cần execute scalar. 
                // Để đơn giản và an toàn với EF Core, đoạn check này dùng LINQ vẫn rất nhanh.
                return await context.Users.AnyAsync(u => u.Email == email || u.AccountName == accountName);
            }
        }

        /// <summary>
        /// Lưu thông tin User (Thêm mới hoặc Cập nhật)
        /// </summary>
        public async Task SaveUserAsync(User user, bool isUpdatePassword)
        {
            using (var context = new AppDbContext())
            {
                if (user.UserId > 0)
                {
                    // Cập nhật
                    var dbUser = await context.Users.FindAsync(user.UserId);
                    if (dbUser != null)
                    {
                        dbUser.AccountName = user.AccountName;
                        dbUser.Email = user.Email;
                        dbUser.Role = user.Role;
                        dbUser.Status = user.Status;
                        if (isUpdatePassword) dbUser.PasswordHash = user.PasswordHash;
                        // Gọi SP update nếu muốn: proc_update_staff_user
                    }
                }
                else
                {
                    // Thêm mới
                    context.Users.Add(user);
                    // Hoặc gọi SP: proc_create_user
                }
                await context.SaveChangesAsync();
            }
        }

        /// <summary>
        /// Xóa User (Sử dụng SP xóa nhân viên)
        /// </summary>
        public async Task DeleteUserAsync(int userId)
        {
            using (var context = new AppDbContext())
            {
                // Gọi SP: proc_delete_staff
                await context.Database.ExecuteSqlInterpolatedAsync($"CALL proc_delete_staff({userId})");
            }
        }

        /// <summary>
        /// Đổi mật khẩu (Sử dụng SP)
        /// </summary>
        public async Task ChangePasswordAsync(int userId, string newHash)
        {
            using (var context = new AppDbContext())
            {
                // Gọi SP: proc_update_user_password
                await context.Database.ExecuteSqlInterpolatedAsync($"CALL proc_update_user_password({userId}, {newHash})");
            }
        }

        #endregion

        // =================================================================================
        // #REGION: PROFILE MANAGEMENT (HỒ SƠ CÁ NHÂN)
        // =================================================================================
        #region Profile

        public async Task<User?> GetUserWithDetailAsync(int userId)
        {
            using (var context = new AppDbContext())
            {
                // Dùng Include để lấy thông tin chi tiết bảng user_detail
                return await context.Users
                    .Include(u => u.UserDetail)
                    .FirstOrDefaultAsync(u => u.UserId == userId);
            }
        }

        public async Task SaveUserDetailAsync(int userId, string fullName, string address, string phone, DateTime? dob)
        {
            using (var context = new AppDbContext())
            {
                // Gọi SP Upsert (Thêm hoặc Cập nhật): proc_upsert_user_detail
                // Lưu ý xử lý tham số NULL nếu cần
                string sDob = dob.HasValue ? $"'{dob.Value:yyyy-MM-dd}'" : "NULL";
                string sAddr = string.IsNullOrEmpty(address) ? "NULL" : $"'{address}'";
                string sPhone = string.IsNullOrEmpty(phone) ? "NULL" : $"'{phone}'";

                // Sử dụng ExecuteSqlRaw để dễ truyền chuỗi NULL
                await context.Database.ExecuteSqlRawAsync(
                    $"CALL proc_upsert_user_detail({userId}, '{fullName}', {sDob}, {sAddr}, {sPhone})");
            }
        }

        #endregion

        // =================================================================================
        // #REGION: ACTOR MANAGEMENT (QUẢN LÝ DIỄN VIÊN)
        // =================================================================================
        #region Actor Management

        /// <summary>
        /// Lấy danh sách diễn viên, hỗ trợ tìm kiếm (Chuyển sang dùng SP mới)
        /// </summary>
        public async Task<List<Actor>> GetActorsAsync(string keyword = "")
        {
            using (var context = new AppDbContext())
            {
                // Gọi SP mới tạo: proc_get_actors
                string search = keyword ?? "";
                return await context.Actors
                    .FromSqlInterpolated($"CALL proc_get_actors({search})")
                    .ToListAsync();
            }
        }

        /// <summary>
        /// Lấy danh sách diễn viên đang hoạt động (cho ComboBox)
        /// </summary>
        public async Task<List<Actor>> GetActiveActorsAsync()
        {
            using (var context = new AppDbContext())
            {
                // Logic đơn giản, giữ LINQ hoặc viết SP proc_get_active_actors
                return await context.Actors
                    .Where(a => a.Status == "Hoạt động")
                    .OrderBy(a => a.FullName)
                    .AsNoTracking()
                    .ToListAsync();
            }
        }

        /// <summary>
        /// Lưu diễn viên (Sử dụng SP Upsert mới)
        /// </summary>
        public async Task SaveActorAsync(Actor actor)
        {
            using (var context = new AppDbContext())
            {
                // Gọi SP mới tạo: proc_save_actor
                await context.Database.ExecuteSqlInterpolatedAsync($@"
                    CALL proc_save_actor(
                        {actor.ActorId}, 
                        {actor.FullName}, 
                        {actor.NickName}, 
                        {actor.DateOfBirth}, 
                        {actor.Gender}, 
                        {actor.Email}, 
                        {actor.Phone}, 
                        {actor.Status}
                    )");
            }
        }

        /// <summary>
        /// Xóa diễn viên (Sử dụng SP có sẵn)
        /// </summary>
        public async Task DeleteActorAsync(int actorId)
        {
            using (var context = new AppDbContext())
            {
                // Gọi SP: proc_delete_actor
                await context.Database.ExecuteSqlInterpolatedAsync($"CALL proc_delete_actor({actorId})");
            }
        }

        #endregion

        // =================================================================================
        // #REGION: SHOW & GENRE (QUẢN LÝ VỞ DIỄN & THỂ LOẠI)
        // =================================================================================
        #region Show & Genre

        // --- GENRE (THỂ LOẠI) ---

        public async Task<List<Genre>> GetGenresAsync()
        {
            using (var context = new AppDbContext())
            {
                // Gọi SP có sẵn: proc_get_all_genres
                return await context.Genres
                    .FromSqlRaw("CALL proc_get_all_genres()")
                    .ToListAsync();
            }
        }

        public async Task SaveGenreAsync(Genre genre)
        {
            using (var context = new AppDbContext())
            {
                // Gọi SP mới tạo: proc_save_genre
                await context.Database.ExecuteSqlInterpolatedAsync(
                    $"CALL proc_save_genre({genre.GenreId}, {genre.GenreName})");
            }
        }

        public async Task DeleteGenreAsync(int id)
        {
            using (var context = new AppDbContext())
            {
                // Gọi SP có sẵn: proc_delete_genre
                await context.Database.ExecuteSqlInterpolatedAsync($"CALL proc_delete_genre({id})");
            }
        }

        // --- SHOW (VỞ DIỄN) ---

        /// <summary>
        /// Lấy danh sách vở diễn (Logic phức tạp nhiều Include -> Giữ LINQ)
        /// </summary>
        public async Task<List<Show>> GetShowsAsync(string keyword, int genreId)
        {
            using (var context = new AppDbContext())
            {
                var query = context.Shows
                    .Include(s => s.Genres)
                    .Include(s => s.Actors)
                    .OrderByDescending(s => s.ShowId)
                    .AsQueryable();

                if (!string.IsNullOrEmpty(keyword))
                    query = query.Where(s => s.Title.Contains(keyword));

                if (genreId > 0)
                    query = query.Where(s => s.Genres.Any(g => g.GenreId == genreId));

                return await query.ToListAsync();
            }
        }

        /// <summary>
        /// Lấy danh sách vở diễn đơn giản (cho ComboBox)
        /// </summary>
        public async Task<List<Show>> GetShowsSimpleAsync()
        {
            using (var context = new AppDbContext())
            {
                return await context.Shows.OrderBy(s => s.Title).AsNoTracking().ToListAsync();
            }
        }

        /// <summary>
        /// Lưu vở diễn (Logic Many-to-Many phức tạp -> Giữ LINQ/EF Core)
        /// </summary>
        public async Task SaveShowAsync(Show show, List<int> genreIds, List<int> actorIds)
        {
            using (var context = new AppDbContext())
            {
                Show dbShow;
                if (show.ShowId > 0)
                {
                    dbShow = await context.Shows
                        .Include(s => s.Genres)
                        .Include(s => s.Actors)
                        .FirstOrDefaultAsync(s => s.ShowId == show.ShowId);

                    if (dbShow != null)
                    {
                        dbShow.Title = show.Title;
                        dbShow.Director = show.Director;
                        dbShow.DurationMinutes = show.DurationMinutes;
                        dbShow.PosterImageUrl = show.PosterImageUrl;
                        dbShow.Description = show.Description;
                        // Status được trigger tự động update
                    }
                    else return;
                }
                else
                {
                    dbShow = show;
                    context.Shows.Add(dbShow);
                }

                // Cập nhật quan hệ nhiều-nhiều
                dbShow.Genres.Clear();
                dbShow.Actors.Clear();

                if (genreIds.Any())
                {
                    var genres = await context.Genres.Where(g => genreIds.Contains(g.GenreId)).ToListAsync();
                    foreach (var g in genres) dbShow.Genres.Add(g);
                }
                if (actorIds.Any())
                {
                    var actors = await context.Actors.Where(a => actorIds.Contains(a.ActorId)).ToListAsync();
                    foreach (var a in actors) dbShow.Actors.Add(a);
                }

                await context.SaveChangesAsync();
                // Gọi SP cập nhật trạng thái show sau khi lưu
                await context.Database.ExecuteSqlRawAsync("CALL proc_update_show_statuses()");
            }
        }

        public async Task<bool> HasPerformancesAsync(int showId)
        {
            using (var context = new AppDbContext())
            {
                // Gọi SP: proc_count_performances_by_show
                // Hoặc giữ LINQ vì đơn giản
                return await context.Performances.AnyAsync(p => p.ShowId == showId);
            }
        }

        public async Task DeleteShowAsync(int showId)
        {
            using (var context = new AppDbContext())
            {
                // Gọi SP: proc_delete_show
                await context.Database.ExecuteSqlInterpolatedAsync($"CALL proc_delete_show({showId})");
            }
        }

        #endregion

        // =================================================================================
        // #REGION: THEATER & SEAT (QUẢN LÝ RẠP & GHẾ)
        // =================================================================================
        #region Theater & Seat

        public async Task<List<Theater>> GetTheatersAsync()
        {
            using (var context = new AppDbContext())
            {
                // Gọi SP: proc_get_all_theaters
                return await context.Theaters
                    .FromSqlRaw("CALL proc_get_all_theaters()")
                    .ToListAsync();
            }
        }

        public async Task<List<Theater>> GetTheatersWithStatusAsync()
        {
            using (var context = new AppDbContext())
            {
                // Cần load kèm Performances để check CanDelete -> Giữ EF Core Include
                var theaters = await context.Theaters
                    .Include(t => t.Performances)
                    .OrderBy(t => t.TheaterId)
                    .AsNoTracking()
                    .ToListAsync();

                foreach (var t in theaters)
                {
                    t.CanDelete = (t.Performances == null || !t.Performances.Any());
                    t.CanEdit = true;
                }
                return theaters;
            }
        }

        // --- SEAT CATEGORY ---

        public async Task<List<SeatCategory>> GetSeatCategoriesAsync()
        {
            using (var context = new AppDbContext())
            {
                // Gọi SP: proc_get_all_seat_categories
                return await context.SeatCategories
                    .FromSqlRaw("CALL proc_get_all_seat_categories()")
                    .ToListAsync();
            }
        }

        public async Task SaveSeatCategoryAsync(SeatCategory cat)
        {
            using (var context = new AppDbContext())
            {
                if (cat.CategoryId > 0)
                {
                    // Gọi SP: proc_update_seat_category
                    await context.Database.ExecuteSqlInterpolatedAsync(
                        $"CALL proc_update_seat_category({cat.CategoryId}, {cat.CategoryName}, {cat.BasePrice}, {cat.ColorClass})");
                }
                else
                {
                    if (string.IsNullOrEmpty(cat.ColorClass)) cat.ColorClass = "E74C3C";
                    // Gọi SP: proc_create_seat_category
                    await context.Database.ExecuteSqlInterpolatedAsync(
                        $"CALL proc_create_seat_category({cat.CategoryName}, {cat.BasePrice}, {cat.ColorClass})");
                }
            }
        }

        public async Task DeleteSeatCategoryAsync(int id)
        {
            using (var context = new AppDbContext())
            {
                // Gọi SP: proc_delete_seat_category
                await context.Database.ExecuteSqlInterpolatedAsync($"CALL proc_delete_seat_category({id})");
            }
        }

        public async Task<bool> IsSeatCategoryInUseAsync(int categoryId)
        {
            using (var context = new AppDbContext())
            {
                // Logic đơn giản, giữ LINQ
                return await context.Seats.AnyAsync(s => s.CategoryId == categoryId);
            }
        }

        // --- THEATER & SEATS ---

        public async Task<List<Seat>> GetSeatsByTheaterAsync(int theaterId)
        {
            using (var context = new AppDbContext())
            {
                // SP proc_get_seats_for_theater đã tồn tại và join sẵn category
                // Tuy nhiên Model Seat cần map đúng. Nếu SP trả về cột khác Model -> Lỗi.
                // Ở đây giữ LINQ Include cho an toàn với Model Seat hiện tại.
                return await context.Seats
                    .Where(s => s.TheaterId == theaterId)
                    .Include(s => s.SeatCategory)
                    .OrderBy(s => s.RowChar).ThenBy(s => s.SeatNumber)
                    .ToListAsync();
            }
        }

        /// <summary>
        /// Tạo Rạp mới kèm danh sách ghế (Dùng SP proc_create_theater)
        /// </summary>
        public async Task SaveNewTheaterAsync(Theater theater, List<Seat> seats)
        {
            using (var context = new AppDbContext())
            {
                // Bước 1: Lưu thông tin Rạp trước để lấy TheaterId
                theater.Status = "Đã hoạt động";
                context.Theaters.Add(theater);
                await context.SaveChangesAsync(); // Sau lệnh này, theater.TheaterId sẽ có giá trị

                // Bước 2: Lưu danh sách ghế đã chỉnh sửa (Xóa lối đi, gán màu...)
                foreach (var s in seats)
                {
                    s.SeatId = 0; // Reset ID để thêm mới
                    s.TheaterId = theater.TheaterId; // Gán vào rạp vừa tạo

                    // Map ID hạng ghế nếu có
                    if (s.SeatCategory != null)
                    {
                        s.CategoryId = s.SeatCategory.CategoryId;
                    }

                    s.SeatCategory = null; // Ngắt tham chiếu object để tránh lỗi EF
                    context.Seats.Add(s);
                }

                // Cập nhật lại tổng số ghế thực tế cho Rạp
                theater.TotalSeats = seats.Count;
                context.Theaters.Update(theater);

                await context.SaveChangesAsync();
            }
        }

        public async Task DeleteTheaterAsync(int theaterId)
        {
            using (var context = new AppDbContext())
            {
                // Gọi SP: proc_delete_theater (Trong DB đã có logic xóa ghế trước)
                await context.Database.ExecuteSqlInterpolatedAsync($"CALL proc_delete_theater({theaterId})");
            }
        }

        public async Task UpdateTheaterStructureAsync(Theater theater, List<Seat> newSeats)
        {
            using (var context = new AppDbContext())
            {
                // Logic cập nhật cấu trúc phức tạp (xóa cũ thêm mới)
                // Giữ nguyên logic EF Core Transaction để đảm bảo an toàn
                var dbTheater = await context.Theaters.FindAsync(theater.TheaterId);
                if (dbTheater != null)
                {
                    dbTheater.Name = theater.Name;
                    dbTheater.TotalSeats = newSeats.Count;
                }

                // Gọi SP xóa ghế cũ: proc_delete_seats_by_theater
                await context.Database.ExecuteSqlInterpolatedAsync($"CALL proc_delete_seats_by_theater({theater.TheaterId})");

                // Thêm ghế mới (Bulk insert bằng EF)
                foreach (var s in newSeats)
                {
                    s.SeatId = 0;
                    s.TheaterId = theater.TheaterId;
                    if (s.SeatCategory != null) s.CategoryId = s.SeatCategory.CategoryId;
                    s.SeatCategory = null;
                    context.Seats.Add(s);
                }
                await context.SaveChangesAsync();
            }
        }

        #endregion

        // =================================================================================
        // #REGION: PERFORMANCE (QUẢN LÝ SUẤT DIỄN)
        // =================================================================================
        #region Performance

        public async Task<List<Performance>> GetPerformancesAsync(string showName, int theaterId, DateTime? date)
        {
            using (var context = new AppDbContext())
            {
                // Cập nhật trạng thái trước khi lấy
                await context.Database.ExecuteSqlRawAsync("CALL proc_update_statuses()");

                var query = context.Performances
                    .Include(p => p.Show)
                    .Include(p => p.Theater)
                    .OrderByDescending(p => p.PerformanceDate)
                    .AsNoTracking()
                    .AsQueryable();

                if (!string.IsNullOrWhiteSpace(showName))
                    query = query.Where(p => p.Show.Title.Contains(showName));
                if (theaterId > 0)
                    query = query.Where(p => p.TheaterId == theaterId);
                if (date.HasValue)
                    query = query.Where(p => p.PerformanceDate.Date == date.Value.Date);

                var list = await query.ToListAsync();

                // Check Booking
                foreach (var p in list)
                {
                    p.HasBookings = await context.Bookings.AnyAsync(b => b.PerformanceId == p.PerformanceId);
                    p.ShowTitle = p.Show?.Title;
                    p.TheaterName = p.Theater?.Name;
                }
                return list;
            }
        }

        public async Task SavePerformanceAsync(Performance perf)
        {
            using (var context = new AppDbContext())
            {
                // Gọi SP: proc_create_performance (Nếu là thêm mới)
                // Tuy nhiên hàm này cần xử lý cả Update. Để đơn giản giữ EF Core cho Update
                // hoặc viết thêm SP proc_update_performance

                if (perf.PerformanceId == 0)
                {
                    // Thêm mới bằng SP
                    string sDate = $"'{perf.PerformanceDate:yyyy-MM-dd}'";
                    string sStart = $"'{perf.StartTime}'";
                    // Tính EndTime
                    var show = await context.Shows.FindAsync(perf.ShowId);
                    TimeSpan endTime = perf.StartTime.Add(TimeSpan.FromMinutes(show?.DurationMinutes ?? 0));
                    string sEnd = $"'{endTime}'";

                    await context.Database.ExecuteSqlRawAsync(
                        $"CALL proc_create_performance({perf.ShowId}, {perf.TheaterId}, {sDate}, {sStart}, {sEnd}, {perf.Price})");
                }
                else
                {
                    // Cập nhật bằng EF
                    context.Performances.Update(perf);
                    await context.SaveChangesAsync();
                }
            }
        }

        public async Task DeletePerformanceAsync(int id)
        {
            using (var context = new AppDbContext())
            {
                // Xóa bằng EF
                var p = new Performance { PerformanceId = id };
                context.Performances.Remove(p);
                await context.SaveChangesAsync();
            }
        }

        #endregion

        // =================================================================================
        // #REGION: BOOKING & SALES (QUẢN LÝ ĐƠN HÀNG & BÁN VÉ)
        // =================================================================================
        #region Booking & Sales

        public async Task<List<Booking>> GetBookingsAsync()
        {
            using (var context = new AppDbContext())
            {
                // Query phức tạp lấy dữ liệu lồng nhau -> BẮT BUỘC giữ LINQ Include
                return await context.Bookings
                    .Include(b => b.User).ThenInclude(u => u.UserDetail)
                    .Include(b => b.Performance).ThenInclude(p => p.Show)
                    .Include(b => b.Performance).ThenInclude(p => p.Theater)
                    .Include(b => b.Tickets).ThenInclude(t => t.Seat).ThenInclude(s => s.SeatCategory)
                    .Include(b => b.CreatedByUser).ThenInclude(u => u.UserDetail)
                    .OrderByDescending(b => b.CreatedAt)
                    .AsNoTracking()
                    .ToListAsync();
            }
        }

        // --- SELL TICKET HELPERS (Sử dụng SP tối đa) ---

        public async Task<List<ShowInfo>> GetActiveShowsAsync()
        {
            using (var context = new AppDbContext())
            {
                // Gọi SP: proc_active_shows
                return await context.ShowInfos.FromSqlRaw("CALL proc_active_shows()").ToListAsync();
            }
        }

        public async Task<List<PerformanceInfo>> GetPerformancesByShowAsync(int showId)
        {
            using (var context = new AppDbContext())
            {
                // Gọi SP: proc_performances_by_show
                return await context.PerformanceInfos
                    .FromSqlInterpolated($"CALL proc_performances_by_show({showId})")
                    .ToListAsync();
            }
        }

        public async Task<List<PeakPerformanceInfo>> GetTopPerformancesAsync()
        {
            using (var context = new AppDbContext())
            {
                // Gọi SP: proc_top3_nearest_performances_extended
                return await context.PeakPerformanceInfos
                    .FromSqlRaw("CALL proc_top3_nearest_performances_extended()")
                    .ToListAsync();
            }
        }

        public async Task<List<SeatStatus>> GetSeatsWithStatusAsync(int perfId)
        {
            using (var context = new AppDbContext())
            {
                // Gọi SP: proc_seats_with_status
                return await context.SeatStatuses
                    .FromSqlInterpolated($"CALL proc_seats_with_status({perfId})")
                    .ToListAsync();
            }
        }

        public async Task<int> CreateBookingPOSAsync(int? customerId, int perfId, decimal total, int staffId)
        {
            using (var context = new AppDbContext())
            {
                // Gọi SP: proc_create_booking_pos
                var results = await context.CreateBookingResults
                    .FromSqlInterpolated($"CALL proc_create_booking_pos({customerId}, {perfId}, {total}, {staffId})")
                    .ToListAsync();
                return results.FirstOrDefault()?.booking_id ?? 0;
            }
        }

        public async Task CreatePaymentAndTicketsAsync(int bookingId, decimal total, string method, List<int> seatIds)
        {
            using (var context = new AppDbContext())
            {
                // 1. Tạo Payment (Gọi SP: proc_create_payment)
                // Lưu ý: Chuỗi trong SQL cần nằm trong dấu nháy đơn
                string sqlPayment = $"CALL proc_create_payment({bookingId}, {total}, 'Thành công', 'POS', '{method}')";
                await context.Database.ExecuteSqlRawAsync(sqlPayment);

                // 2. Tạo Tickets (Gọi SP: proc_create_ticket cho từng ghế)
                foreach (var seatId in seatIds)
                {
                    await context.Database.ExecuteSqlInterpolatedAsync(
                        $"CALL proc_create_ticket({bookingId}, {seatId})");
                }
            }
        }

        #endregion

        // =================================================================================
        // #REGION: DASHBOARD (THỐNG KÊ BÁO CÁO)
        // =================================================================================
        #region Dashboard

        public async Task<DashboardSummary> GetDashboardSummaryAsync()
        {
            using (var context = new AppDbContext())
            {
                // Gọi SP: proc_dashboard_summary
                var result = await context.DashboardSummaries
                    .FromSqlRaw("CALL proc_dashboard_summary()")
                    .ToListAsync();
                return result.FirstOrDefault() ?? new DashboardSummary();
            }
        }

        public async Task<List<RevenueMonthly>> GetRevenueMonthlyAsync()
        {
            using (var context = new AppDbContext())
            {
                // Gọi SP: proc_revenue_monthly
                return await context.RevenueMonthlies
                    .FromSqlRaw("CALL proc_revenue_monthly()")
                    .ToListAsync();
            }
        }

        public async Task<List<ChartDataModel>> GetOccupancyDataAsync(string filter)
        {
            using (var context = new AppDbContext())
            {
                string sql = filter switch
                {
                    "month" => "CALL proc_chart_last_4_weeks()",
                    "year" => "CALL proc_sold_tickets_yearly()",
                    _ => "CALL proc_chart_last_7_days()"
                };
                return await context.ChartDatas.FromSqlRaw(sql).ToListAsync();
            }
        }

        public async Task<List<TopShow>> GetTopShowsAsync(DateTime? start = null, DateTime? end = null)
        {
            using (var context = new AppDbContext())
            {
                // Gọi SP: proc_top5_shows_by_date_range
                string sStart = start.HasValue ? $"'{start.Value:yyyy-MM-dd HH:mm:ss}'" : "NULL";
                string sEnd = end.HasValue ? $"'{end.Value:yyyy-MM-dd HH:mm:ss}'" : "NULL";

                return await context.TopShows
                    .FromSqlRaw($"CALL proc_top5_shows_by_date_range({sStart}, {sEnd})")
                    .ToListAsync();
            }
        }
        public async Task<bool> CheckPerformanceOverlapAsync(int theaterId, DateTime date, TimeSpan newStart, TimeSpan newEnd, int excludePerfId = 0)
        {
            using (var context = new AppDbContext())
            {
                // Logic trùng lịch: (StartA < EndB) AND (EndA > StartB)
                // Chỉ kiểm tra các suất chưa kết thúc và chưa hủy
                return await context.Performances.AnyAsync(p =>
                    p.TheaterId == theaterId &&
                    p.PerformanceDate.Date == date.Date &&
                    p.PerformanceId != excludePerfId && // Bỏ qua chính nó (khi đang sửa)
                    (p.Status == "Đang mở bán" || p.Status == "Đang diễn") && // Chỉ check suất active
                    (newStart < p.EndTime && newEnd > p.StartTime) // Công thức giao nhau thời gian
                );
            }
        }
        #endregion
    }
}