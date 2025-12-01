using Microsoft.EntityFrameworkCore;
using StageX_DesktopApp.Models;
using System.Collections.Generic;

namespace StageX_DesktopApp.Data
{
    public class AppDbContext : DbContext
    {
        public DbSet<User> Users { get; set; }
        public DbSet<UserDetail> UserDetails { get; set; }
        public DbSet<Actor> Actors { get; set; }
        public DbSet<Show> Shows { get; set; }
        public DbSet<Genre> Genres { get; set; }
        public DbSet<Theater> Theaters { get; set; }
        public DbSet<Seat> Seats { get; set; }
        public DbSet<SeatCategory> SeatCategories { get; set; }
        public DbSet<Performance> Performances { get; set; }
        public DbSet<Booking> Bookings { get; set; }
        public DbSet<Ticket> Tickets { get; set; }
        public DbSet<Payment> Payments { get; set; }

        // --- 2. KHAI BÁO CÁC MODEL HỨNG DỮ LIỆU TỪ STORED PROCEDURE ---
        public DbSet<DashboardSummary> DashboardSummaries { get; set; }
        public DbSet<RevenueMonthly> RevenueMonthlies { get; set; }
        public DbSet<TicketSold> TicketSolds { get; set; }
        public DbSet<TopShow> TopShows { get; set; }
        public DbSet<RatingDistribution> RatingDistributions { get; set; }

        // Model cho trang bán vé
        public DbSet<ShowInfo> ShowInfos { get; set; }
        public DbSet<PerformanceInfo> PerformanceInfos { get; set; }
        public DbSet<AvailableSeat> AvailableSeats { get; set; }
        public DbSet<CreateBookingResult> CreateBookingResults { get; set; }
        public DbSet<SeatStatus> SeatStatuses { get; set; }
        public DbSet<PeakPerformanceInfo> PeakPerformanceInfos { get; set; }
        public DbSet<ChartDataModel> ChartDatas { get; set; }

        // --- 3. CẤU HÌNH KẾT NỐI ---
        protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
        {
            string connectionString = "Server=localhost;Database=stagex_db;User=root;Password=;";
            optionsBuilder.UseMySql(connectionString, ServerVersion.AutoDetect(connectionString));
        }

        // --- 4. CẤU HÌNH MAPPING ---
        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            // Map bảng Actor
            modelBuilder.Entity<Actor>().ToTable("actors");

            // Map bảng User
            modelBuilder.Entity<User>().ToTable("users");
            modelBuilder.Entity<UserDetail>(entity =>
            {
                entity.ToTable("user_detail");
                entity.HasKey(e => e.UserId);
            });

            // Các quan hệ (Relationships)
            modelBuilder.Entity<User>()
                .HasOne(u => u.UserDetail)
                .WithOne(ud => ud.User)
                .HasForeignKey<UserDetail>(ud => ud.UserId);

            modelBuilder.Entity<Show>()
                .HasMany(s => s.Genres)
                .WithMany(g => g.Shows)
                .UsingEntity<Dictionary<string, object>>(
                    "show_genres",
                    j => j.HasOne<Genre>().WithMany().HasForeignKey("genre_id"),
                    j => j.HasOne<Show>().WithMany().HasForeignKey("show_id")
                );

            modelBuilder.Entity<Show>()
                .HasMany(s => s.Actors)
                .WithMany(a => a.Shows)
                .UsingEntity<Dictionary<string, object>>(
                    "show_actors",
                    j => j.HasOne<Actor>().WithMany().HasForeignKey("actor_id"),
                    j => j.HasOne<Show>().WithMany().HasForeignKey("show_id")
                );

            modelBuilder.Entity<Seat>().HasOne(s => s.Theater).WithMany().HasForeignKey(s => s.TheaterId);
            modelBuilder.Entity<Seat>().HasOne(s => s.SeatCategory).WithMany().HasForeignKey(s => s.CategoryId);

            modelBuilder.Entity<Performance>().HasOne(p => p.Show).WithMany().HasForeignKey(p => p.ShowId);
            modelBuilder.Entity<Performance>().HasOne(p => p.Theater).WithMany(t => t.Performances).HasForeignKey(p => p.TheaterId);

            modelBuilder.Entity<Booking>().HasMany(b => b.Payments).WithOne(p => p.Booking).HasForeignKey(p => p.BookingId);
            modelBuilder.Entity<Booking>().HasMany(b => b.Tickets).WithOne(t => t.Booking).HasForeignKey(t => t.BookingId);
            modelBuilder.Entity<Booking>().HasOne(b => b.Performance).WithMany().HasForeignKey(b => b.PerformanceId);
            modelBuilder.Entity<Booking>().HasOne(b => b.CreatedByUser).WithMany().HasForeignKey(b => b.CreatedBy).OnDelete(DeleteBehavior.SetNull);

            modelBuilder.Entity<Ticket>().HasOne(t => t.Seat).WithMany().HasForeignKey(t => t.SeatId);

            modelBuilder.Entity<SeatStatus>().HasNoKey().ToView(null);

            // --- ĐỊNH NGHĨA KEYLESS ENTITY (Cho Stored Procedure) ---
            modelBuilder.Entity<DashboardSummary>().HasNoKey();
            modelBuilder.Entity<RevenueMonthly>().HasNoKey();
            modelBuilder.Entity<TicketSold>().HasNoKey();
            modelBuilder.Entity<TopShow>().HasNoKey();
            modelBuilder.Entity<RatingDistribution>().HasNoKey();
            modelBuilder.Entity<ShowInfo>().HasNoKey();
            modelBuilder.Entity<PerformanceInfo>().HasNoKey();
            modelBuilder.Entity<AvailableSeat>().HasNoKey();
            modelBuilder.Entity<CreateBookingResult>().HasNoKey();
            modelBuilder.Entity<SeatStatus>().HasNoKey();
            modelBuilder.Entity<PeakPerformanceInfo>().HasNoKey();
            modelBuilder.Entity<ChartDataModel>().HasNoKey();
        }
    }
}