using Microsoft.EntityFrameworkCore;
using Stagex.Api.Models;

namespace Stagex.Api.Data
{
    public class AppDbContext : DbContext
    {
        public DbSet<Ticket> Tickets { get; set; } = null!;

        public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
        {
        }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);
            modelBuilder.Entity<Ticket>(entity =>
            {
                entity.ToTable("tickets");
                entity.HasKey(t => t.TicketId);
                entity.Property(t => t.TicketId).HasColumnName("ticket_id");
                entity.Property(t => t.BookingId).HasColumnName("booking_id");
                entity.Property(t => t.SeatId).HasColumnName("seat_id");
                entity.Property(t => t.TicketCode).HasColumnName("ticket_code");
                entity.Property(t => t.Status).HasColumnName("status");
                entity.Property(t => t.CreatedAt).HasColumnName("created_at");
                entity.Property(t => t.UpdatedAt).HasColumnName("updated_at");
            });
        }
    }
}