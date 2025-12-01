namespace Stagex.Api.Models
{
    public class ScanRequest
    {
        /// <summary>
        /// Không biết cái nào, có phải ticket_code không nên để luôn, nữa sửa đi nha
        /// </summary>
        public string? Barcode { get; set; }
        public string? TicketCode { get; set; }
        public string? ticket_code { get; set; }
        public string? code { get; set; }
    }
}