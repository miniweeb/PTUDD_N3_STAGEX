using Newtonsoft.Json;
using RestSharp;
using System;
using System.IO;
using System.Threading.Tasks;
using System.Windows.Media.Imaging;

namespace StageX_DesktopApp.Services
{
    public class VietQRService
    {
        // --- CẤU HÌNH TÀI KHOẢN NHẬN TIỀN ---
        // Bạn hãy thay đổi các thông số này cho đúng với tài khoản thực tế
        private const string ACCOUNT_NO = "9923192231";       // Số tài khoản
        private const string ACCOUNT_NAME = "LE THI MY TRANG";   // Tên chủ tài khoản (Không dấu)
        private const int ACQ_ID = 970436;                    // Mã Bin ngân hàng (VD: 970436 là Vietcombank, 970422 là MBBank)
        private const string TEMPLATE = "compact2";           // Mẫu QR (compact, compact2, qr_only, print)

        public async Task<BitmapImage> GenerateQrCodeAsync(decimal amount, string content)
        {
            var client = new RestClient("https://api.vietqr.io/v2/generate");
            var request = new RestRequest("", Method.Post);
            request.AddHeader("Content-Type", "application/json");

            // Tạo body request
            var body = new
            {
                accountNo = ACCOUNT_NO,
                accountName = ACCOUNT_NAME,
                acqId = ACQ_ID,
                amount = amount,
                addInfo = content,
                format = "text",
                template = TEMPLATE
            };

            request.AddJsonBody(body);

            try
            {
                var response = await client.ExecuteAsync(request);

                if (response.IsSuccessful && !string.IsNullOrEmpty(response.Content))
                {
                    // Deserialize JSON trả về
                    var apiResponse = JsonConvert.DeserializeObject<VietQRResponse>(response.Content);

                    // Kiểm tra mã lỗi từ VietQR ("00" là thành công)
                    if (apiResponse != null && apiResponse.code == "00" && apiResponse.data != null)
                    {
                        string base64Data = apiResponse.data.qrDataURL;

                        // Xử lý chuỗi base64 (xóa phần header "data:image/png;base64," nếu có)
                        if (base64Data.Contains(","))
                        {
                            base64Data = base64Data.Split(',')[1];
                        }

                        // Chuyển đổi Base64 thành BitmapImage
                        byte[] imageBytes = Convert.FromBase64String(base64Data);
                        using (var ms = new MemoryStream(imageBytes))
                        {
                            var bitmap = new BitmapImage();
                            bitmap.BeginInit();
                            bitmap.CacheOption = BitmapCacheOption.OnLoad;
                            bitmap.StreamSource = ms;
                            bitmap.EndInit();

                            // Freeze để ảnh có thể được truy cập từ UI thread khác (quan trọng trong Async)
                            bitmap.Freeze();
                            return bitmap;
                        }
                    }
                }
            }
            catch (Exception)
            {
                // Log lỗi nếu cần thiết (ví dụ: mất mạng, API lỗi)
                return null;
            }

            return null;
        }
    }

    // --- CÁC CLASS DỮ LIỆU JSON ---
    public class VietQRResponse
    {
        public string code { get; set; }
        public string desc { get; set; }
        public VietQRData data { get; set; }
    }

    public class VietQRData
    {
        public string qrCode { get; set; }
        public string qrDataURL { get; set; } // Đây là chuỗi Base64 hình ảnh
    }
}