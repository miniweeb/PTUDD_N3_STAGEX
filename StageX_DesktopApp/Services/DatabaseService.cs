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
        // ... (Giữ nguyên hàm GetUserByIdentifierAsync cũ) ...
        public async Task<User?> GetUserByIdentifierAsync(string identifier)
        {
            using (var context = new AppDbContext())
            {
                return await context.Users
                    .FirstOrDefaultAsync(u => u.Email == identifier || u.AccountName == identifier);
            }
        }

        // --- PHẦN MỚI CHO ACTOR (DIỄN VIÊN) ---

        public async Task<List<Actor>> GetActorsAsync(string keyword = "")
        {
            using (var context = new AppDbContext())
            {
                var query = context.Actors.AsQueryable();
                if (!string.IsNullOrEmpty(keyword))
                {
                    query = query.Where(a => a.FullName.Contains(keyword) || a.NickName.Contains(keyword));
                }
                return await query.OrderByDescending(a => a.ActorId).ToListAsync();
            }
        }

        public async Task SaveActorAsync(Actor actor)
        {
            using (var context = new AppDbContext())
            {
                if (actor.ActorId > 0)
                {
                    context.Actors.Update(actor); // Cập nhật
                }
                else
                {
                    context.Actors.Add(actor); // Thêm mới
                }
                await context.SaveChangesAsync();
            }
        }

        public async Task DeleteActorAsync(int actorId)
        {
            using (var context = new AppDbContext())
            {
                // Tạo object giả chỉ chứa ID để xóa cho nhanh
                var actor = new Actor { ActorId = actorId };
                context.Actors.Remove(actor);
                await context.SaveChangesAsync();
            }
        }

        // --- PHẦN MỚI CHO ACCOUNT (TÀI KHOẢN) ---
        public async Task<bool> CheckUserExistsAsync(string email, string accountName)
        {
            using (var context = new AppDbContext())
            {
                // Kiểm tra xem có user nào trùng Email HOẶC AccountName không
                return await context.Users.AnyAsync(u => u.Email == email || u.AccountName == accountName);
            }
        }
        public async Task<List<User>> GetAdminStaffUsersAsync()
        {
            using (var context = new AppDbContext())
            {
                // Gọi Stored Procedure cũ của bạn
                return await context.Users
                    .FromSqlRaw("CALL proc_get_admin_staff_users()")
                    .ToListAsync();
            }
        }

        public async Task SaveUserAsync(User user, bool isUpdatePassword)
        {
            using (var context = new AppDbContext())
            {
                if (user.UserId > 0)
                {
                    var dbUser = await context.Users.FindAsync(user.UserId);
                    if (dbUser != null)
                    {
                        dbUser.AccountName = user.AccountName;
                        dbUser.Email = user.Email;
                        dbUser.Role = user.Role;
                        dbUser.Status = user.Status;

                        // Chỉ cập nhật pass nếu có thay đổi
                        if (isUpdatePassword)
                            dbUser.PasswordHash = user.PasswordHash;
                    }
                }
                else
                {
                    context.Users.Add(user);
                }
                await context.SaveChangesAsync();
            }
        }

        public async Task DeleteUserAsync(int userId)
        {
            using (var context = new AppDbContext())
            {
                var user = new User { UserId = userId };
                context.Users.Remove(user);
                await context.SaveChangesAsync();
            }
        }
        // ... (Các hàm cũ giữ nguyên) ...

        // --- [PROFILE] QUẢN LÝ HỒ SƠ ---
        public async Task<User?> GetUserWithDetailAsync(int userId)
        {
            using (var context = new AppDbContext())
            {
                return await context.Users
                    .Include(u => u.UserDetail)
                    .FirstOrDefaultAsync(u => u.UserId == userId);
            }
        }

        public async Task SaveUserDetailAsync(int userId, string fullName, string address, string phone, DateTime? dob)
        {
            using (var context = new AppDbContext())
            {
                var detail = await context.UserDetails.FindAsync(userId);
                if (detail == null)
                {
                    detail = new UserDetail { UserId = userId };
                    context.UserDetails.Add(detail);
                }
                detail.FullName = fullName;
                detail.Address = address;
                detail.Phone = phone;
                detail.DateOfBirth = dob;
                await context.SaveChangesAsync();
            }
        }
        public async Task<bool> HasPerformancesAsync(int showId)
        {
            using (var context = new AppDbContext())
            {
                // Kiểm tra trong bảng Performances xem có record nào chứa ShowId này không
                return await context.Performances.AnyAsync(p => p.ShowId == showId);
            }
        }

        // [THÊM MỚI] Xóa vở diễn
        public async Task DeleteShowAsync(int showId)
        {
            using (var context = new AppDbContext())
            {
                // Gọi Stored Procedure xóa vở diễn (đã có trong file SQL: proc_delete_show)
                await context.Database.ExecuteSqlInterpolatedAsync($"CALL proc_delete_show({showId})");
            }
        }

        // --- [SHOW] QUẢN LÝ VỞ DIỄN ---
        public async Task<List<Genre>> GetGenresAsync()
        {
            using (var context = new AppDbContext())
            {
                return await context.Genres.OrderBy(g => g.GenreName).AsNoTracking().ToListAsync();
            }
        }

        public async Task<List<Actor>> GetActiveActorsAsync()
        {
            using (var context = new AppDbContext())
            {
                return await context.Actors
                    .Where(a => a.Status == "Hoạt động")
                    .OrderBy(a => a.FullName)
                    .AsNoTracking()
                    .ToListAsync();
            }
        }

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

        // Hàm lưu Vở diễn (Xử lý Logic Many-to-Many phức tạp)
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

                    // Cập nhật thông tin cơ bản
                    dbShow.Title = show.Title;
                    dbShow.Director = show.Director;
                    dbShow.DurationMinutes = show.DurationMinutes;
                    dbShow.PosterImageUrl = show.PosterImageUrl;
                    dbShow.Description = show.Description;
                }
                else
                {
                    dbShow = show;
                    context.Shows.Add(dbShow);
                }

                // Xử lý quan hệ Nhiều-Nhiều (Logic cũ của bạn)
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
            }
        }

        // --- [PERFORMANCE] QUẢN LÝ SUẤT DIỄN ---
        public async Task<List<Theater>> GetTheatersAsync()
        {
            using (var context = new AppDbContext())
            {
                return await context.Theaters.OrderBy(t => t.Name).AsNoTracking().ToListAsync();
            }
        }

        public async Task<List<Show>> GetShowsSimpleAsync()
        {
            using (var context = new AppDbContext())
            {
                return await context.Shows.OrderBy(s => s.Title).AsNoTracking().ToListAsync();
            }
        }

        public async Task<List<Performance>> GetPerformancesAsync(string showName, int theaterId, DateTime? date)
        {
            using (var context = new AppDbContext())
            {
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

                // [THÊM MỚI]: Kiểm tra Booking cho từng suất diễn
                // (Cách tối ưu hơn là dùng GroupJoin hoặc Select, nhưng cách này an toàn và dễ hiểu với cấu trúc hiện tại)
                foreach (var p in list)
                {
                    // Kiểm tra trong bảng Bookings xem có đơn nào dính tới PerformanceId này không
                    p.HasBookings = await context.Bookings.AnyAsync(b => b.PerformanceId == p.PerformanceId);

                    // Map tên hiển thị
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
                if (perf.PerformanceId > 0)
                {
                    context.Performances.Update(perf);
                }
                else
                {
                    context.Performances.Add(perf);
                }

                // Tính giờ kết thúc dựa trên thời lượng vở diễn
                var show = await context.Shows.FindAsync(perf.ShowId);
                if (show != null)
                {
                    perf.EndTime = perf.StartTime.Add(TimeSpan.FromMinutes(show.DurationMinutes));
                }

                await context.SaveChangesAsync();
            }
        }

        public async Task DeletePerformanceAsync(int id)
        {
            using (var context = new AppDbContext())
            {
                var p = new Performance { PerformanceId = id };
                context.Performances.Remove(p);
                await context.SaveChangesAsync();
            }
        }
        // ... (Code cũ) ...

        // --- [GENRE] QUẢN LÝ THỂ LOẠI ---
        public async Task SaveGenreAsync(Genre genre)
        {
            using (var context = new AppDbContext())
            {
                if (genre.GenreId > 0)
                {
                    var dbGenre = await context.Genres.FindAsync(genre.GenreId);
                    if (dbGenre != null) dbGenre.GenreName = genre.GenreName;
                }
                else
                {
                    context.Genres.Add(genre);
                }
                await context.SaveChangesAsync();
            }
        }

        public async Task DeleteGenreAsync(int id)
        {
            using (var context = new AppDbContext())
            {
                var g = new Genre { GenreId = id };
                context.Genres.Remove(g);
                await context.SaveChangesAsync();
            }
        }

        // --- [THEATER & SEAT & CATEGORY] QUẢN LÝ RẠP & GHẾ ---

        // Lấy danh sách Rạp kèm thông tin có thể xóa hay không
        public async Task<List<Theater>> GetTheatersWithStatusAsync()
        {
            using (var context = new AppDbContext())
            {
                var theaters = await context.Theaters
                    .Include(t => t.Performances)
                    .OrderBy(t => t.TheaterId)
                    .AsNoTracking()
                    .ToListAsync();

                foreach (var t in theaters)
                {
                    // Logic: Chỉ xóa được nếu chưa có suất diễn nào
                    t.CanDelete = (t.Performances == null || !t.Performances.Any());
                    // Logic: Đã có suất diễn thì chỉ Xem, không Sửa cấu trúc
                    t.CanEdit = true;
                }
                return theaters;
            }
        }

        // Lấy danh sách Hạng ghế
        public async Task<List<SeatCategory>> GetSeatCategoriesAsync()
        {
            using (var context = new AppDbContext())
            {
                return await context.SeatCategories.OrderBy(c => c.CategoryId).AsNoTracking().ToListAsync();
            }
        }
        // Lưu Rạp Mới kèm danh sách Ghế (Transaction)
        public async Task SaveNewTheaterAsync(Theater theater, List<Seat> seats)
        {
            using (var context = new AppDbContext())
            {
                context.Theaters.Add(theater);
                await context.SaveChangesAsync(); // Lấy ID rạp

                foreach (var s in seats)
                {
                    s.TheaterId = theater.TheaterId;
                    s.SeatCategory = null; // Reset để tránh EF add lại category
                    context.Seats.Add(s);
                }
                await context.SaveChangesAsync();
            }
        }
        public async Task SaveSeatCategoryAsync(SeatCategory cat)
        {
            using (var context = new AppDbContext())
            {
                if (cat.CategoryId > 0)
                {
                    var dbCat = await context.SeatCategories.FindAsync(cat.CategoryId);
                    if (dbCat != null)
                    {
                        dbCat.CategoryName = cat.CategoryName;
                        dbCat.BasePrice = cat.BasePrice;
                    }
                }
                else
                {
                    // Logic random màu (giữ nguyên hoặc chuyển sang ViewModel cũng được)
                    if (string.IsNullOrEmpty(cat.ColorClass)) cat.ColorClass = "E74C3C";
                    context.SeatCategories.Add(cat);
                }
                await context.SaveChangesAsync();
            }
        }

        public async Task DeleteSeatCategoryAsync(int id)
        {
            using (var context = new AppDbContext())
            {
                var c = new SeatCategory { CategoryId = id };
                context.SeatCategories.Remove(c);
                await context.SaveChangesAsync();
            }
        }

        // Lấy danh sách Ghế của một rạp
        public async Task<List<Seat>> GetSeatsByTheaterAsync(int theaterId)
        {
            using (var context = new AppDbContext())
            {
                // Load ghế kèm hạng ghế để lấy màu
                return await context.Seats
                    .Where(s => s.TheaterId == theaterId)
                    .Include(s => s.SeatCategory)
                    .OrderBy(s => s.RowChar).ThenBy(s => s.SeatNumber)
                    .ToListAsync();
            }
        }


        // Cập nhật tên Rạp
        public async Task UpdateTheaterNameAsync(int id, string name)
        {
            using (var context = new AppDbContext())
            {
                var t = await context.Theaters.FindAsync(id);
                if (t != null) { t.Name = name; await context.SaveChangesAsync(); }
            }
        }

        // Cập nhật danh sách ghế (Gán hạng)
        public async Task UpdateSeatsCategoryAsync(List<Seat> seatsToUpdate)
        {
            using (var context = new AppDbContext())
            {
                // Cách "Cũ nhưng xịn": Sử dụng cơ chế Batch Update của Entity Framework
                foreach (var s in seatsToUpdate)
                {
                    if (s.SeatId > 0)
                    {
                        // Tạo một object giả chỉ chứa ID và thông tin cần sửa
                        var dbSeat = new Seat { SeatId = s.SeatId, CategoryId = s.CategoryId };

                        // Attach vào context để nó biết đây là dữ liệu có sẵn
                        context.Seats.Attach(dbSeat);

                        // Chỉ đánh dấu trường CategoryId là đã thay đổi -> EF chỉ sinh SQL update cột này
                        context.Entry(dbSeat).Property(x => x.CategoryId).IsModified = true;
                    }
                }

                // SaveChangesAsync sẽ tự động tối ưu và gửi lệnh xuống DB một lần
                await context.SaveChangesAsync();
            }
        }
        public async Task DeleteTheaterAsync(int theaterId)
        {
            using (var context = new AppDbContext())
            {
                // Xóa ghế trước rồi xóa rạp (Gọi SP)
                await context.Database.ExecuteSqlInterpolatedAsync($"CALL proc_delete_seats_by_theater({theaterId})");
                await context.Database.ExecuteSqlInterpolatedAsync($"CALL proc_delete_theater({theaterId})");
            }
        }

        // ... (Code cũ) ...

        // --- [DASHBOARD] BẢNG ĐIỀU KHIỂN ---

        public async Task<DashboardSummary> GetDashboardSummaryAsync()
        {
            using (var context = new AppDbContext())
            {
                var result = await context.DashboardSummaries.FromSqlRaw("CALL proc_dashboard_summary()").ToListAsync();
                return result.FirstOrDefault() ?? new DashboardSummary();
            }
        }

        public async Task<List<RevenueMonthly>> GetRevenueMonthlyAsync()
        {
            using (var context = new AppDbContext())
            {
                return await context.RevenueMonthlies.FromSqlRaw("CALL proc_revenue_monthly()").ToListAsync();
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

        // [HÀM BỊ THIẾU - NGUYÊN NHÂN LỖI]
        public async Task<List<TopShow>> GetTopShowsAsync()
        {
            using (var context = new AppDbContext())
            {
                return await context.TopShows
                    .FromSqlRaw("CALL proc_top5_shows_by_tickets()")
                    .ToListAsync();
            }
        }

        // [HÀM BỔ SUNG CHO FILTER NGÀY]
        public async Task<List<TopShow>> GetTopShowsByDateRangeAsync(DateTime? start, DateTime? end)
        {
            using (var context = new AppDbContext())
            {
                string sStart = start.HasValue ? $"'{start.Value:yyyy-MM-dd HH:mm:ss}'" : "NULL";
                string sEnd = end.HasValue ? $"'{end.Value:yyyy-MM-dd HH:mm:ss}'" : "NULL";

                return await context.TopShows
                    .FromSqlRaw($"CALL proc_top5_shows_by_date_range({sStart}, {sEnd})")
                    .ToListAsync();
            }
        }

        // --- [BOOKING] QUẢN LÝ ĐƠN HÀNG ---

        public async Task<List<Booking>> GetBookingsAsync()
        {
            using (var context = new AppDbContext())
            {
                // Logic Include phức tạp của bạn
                return await context.Bookings
                    .Include(b => b.User).ThenInclude(u => u.UserDetail)
                    .Include(b => b.Performance).ThenInclude(p => p.Show)
                    .Include(b => b.Performance).ThenInclude(p => p.Theater)
                    .Include(b => b.Tickets).ThenInclude(t => t.Seat)
                    // [CẬP NHẬT] Load thêm SeatCategory để tính giá vé
                    .Include(b => b.Tickets) .ThenInclude(t => t.Seat) .ThenInclude(s => s.SeatCategory)
                    .Include(b => b.CreatedByUser).ThenInclude(u => u.UserDetail)
                    .OrderByDescending(b => b.CreatedAt)
                    .AsNoTracking()
                    .ToListAsync();
            }
        }

        // --- [AUTH] ĐỔI MẬT KHẨU ---
        public async Task ChangePasswordAsync(int userId, string newHash)
        {
            using (var context = new AppDbContext())
            {
                var user = await context.Users.FindAsync(userId);
                if (user != null)
                {
                    user.PasswordHash = newHash;
                    await context.SaveChangesAsync();
                }
            }
        }

        // --- [SELL TICKET] BÁN VÉ ---
        public async Task<List<ShowInfo>> GetActiveShowsAsync()
        {
            using (var context = new AppDbContext())
            {
                return await context.ShowInfos.FromSqlRaw("CALL proc_active_shows()").ToListAsync();
            }
        }

        public async Task<List<PerformanceInfo>> GetPerformancesByShowAsync(int showId)
        {
            using (var context = new AppDbContext())
            {
                return await context.PerformanceInfos
                    .FromSqlInterpolated($"CALL proc_performances_by_show({showId})")
                    .ToListAsync();
            }
        }

        public async Task<List<PeakPerformanceInfo>> GetTopPerformancesAsync()
        {
            using (var context = new AppDbContext())
            {
                return await context.PeakPerformanceInfos
                    .FromSqlRaw("CALL proc_top3_nearest_performances_extended()")
                    .ToListAsync();
            }
        }

        public async Task<List<SeatStatus>> GetSeatsWithStatusAsync(int perfId)
        {
            using (var context = new AppDbContext())
            {
                return await context.SeatStatuses
                    .FromSqlInterpolated($"CALL proc_seats_with_status({perfId})")
                    .ToListAsync();
            }
        }

        // Hàm tạo đơn hàng (POS)
        public async Task<int> CreateBookingPOSAsync(int? customerId, int perfId, decimal total, int staffId)
        {
            using (var context = new AppDbContext())
            {
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
                // Tạo Payment
                await context.Database.ExecuteSqlInterpolatedAsync(
                    $"CALL proc_create_payment({bookingId}, {total}, {"Thành công"}, {""}, {method})");

                // Tạo Tickets
                foreach (var seatId in seatIds)
                {
                    string code = Guid.NewGuid().ToString().Substring(0, 8).ToUpper();
                    await context.Database.ExecuteSqlInterpolatedAsync(
                        $"CALL proc_create_ticket({bookingId}, {seatId}, {code})");
                }
            }
        }
    }
}