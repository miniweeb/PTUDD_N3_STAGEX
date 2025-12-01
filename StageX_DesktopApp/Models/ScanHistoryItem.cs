using System;

namespace StageX_DesktopApp.Models
{
    public class ScanHistoryItem
    {
        public DateTime Timestamp { get; set; }
        public string TicketCode { get; set; } = string.Empty;
        public string Message { get; set; } = string.Empty;
    }
}