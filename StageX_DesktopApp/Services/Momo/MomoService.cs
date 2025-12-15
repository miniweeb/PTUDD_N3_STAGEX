using Newtonsoft.Json.Linq;
using StageX_DesktopApp.Services.Momo;
using System;
using System.IO;
using System.Net;
using System.Threading.Tasks;
using System.Windows.Media.Imaging;
using ZXing;
using ZXing.Common;
using ZXing.Windows.Compatibility;
using System.Drawing;
using System.Drawing.Imaging;

namespace StageX_DesktopApp.Services.Momo
{
    /// <summary>
    /// Service for generating MoMo payment QR codes using the MoMo test gateway.  This class
    /// encapsulates the steps required to sign a request, create a payment, and extract the
    /// returned QR code.  It is inspired by the implementation in the CinemaGr5 project but
    /// refactored to be asynchronous and compatible with WPF.
    /// </summary>
    public class MomoService
    {
        // TODO: Replace these with your own sandbox credentials from MoMo's developer portal
        // Updated MoMo UAT credentials provided by the user.  These values
        // must match the information in the MoMo developer portal.  Using
        // incorrect credentials will prevent the payment page from loading
        // correctly when the QR code is scanned.
        private const string PARTNER_CODE = "MOMOCGNF20251214_TEST";
        private const string ACCESS_KEY = "IRXQJccoUNyM2E2x";
        private const string SECRET_KEY = "BGCAJqk7dhpO3unXBD8yNs15moSuY6HJ";

        private readonly MoMoSecurity _security = new MoMoSecurity();

        /// <summary>
        /// Create a MoMo payment request and return the QR image along with the generated identifiers.
        /// </summary>
        /// <param name="amount">Total amount to charge the customer.</param>
        /// <param name="orderInfo">A short description of the order (e.g. "Thanh toan ve STAGEX").</param>
        /// <returns>A tuple containing the QR image, orderId and requestId.</returns>
        public async Task<(BitmapImage? Image, string OrderId, string RequestId)> GeneratePaymentAsync(decimal amount, string orderInfo)
        {
            string endpoint = "https://test-payment.momo.vn/v2/gateway/api/create";
            string orderId = Guid.NewGuid().ToString("N");
            string requestId = Guid.NewGuid().ToString("N");

            // Thiết lập URL chuyển hướng và URL IPN (callback) theo yêu cầu của MoMo.
            // redirectUrl không quá quan trọng trong môi trường desktop nhưng phải khai báo.
            string redirectUrl = "https://momo.vn";
            // ipnUrl là địa chỉ server dùng để nhận thông báo trạng thái giao dịch.  Nếu để trống, MoMo sẽ không xử lý.
            // Bạn có thể sử dụng một URL từ webhook.site để test, tương tự như Hamster Cinema.
            string ipnUrl = "https://webhook.site/8095cf34-d952-448d-b231-550802c23eb5";
            string extraData = string.Empty;
            string requestType = "captureWallet";

            // Build raw hash string
            string rawHash =
                $"accessKey={ACCESS_KEY}&amount={Convert.ToInt64(amount)}&extraData={extraData}&ipnUrl={ipnUrl}&orderId={orderId}&orderInfo={orderInfo}&partnerCode={PARTNER_CODE}&redirectUrl={redirectUrl}&requestId={requestId}&requestType={requestType}";

            string signature = _security.SignSha256(rawHash, SECRET_KEY);

            // Construct JSON payload
            var message = new JObject
            {
                { "partnerCode", PARTNER_CODE },
                { "partnerName", "StageX" },
                { "storeId", "StageX01" },
                { "requestId", requestId },
                { "amount", Convert.ToInt64(amount) },
                { "orderId", orderId },
                { "orderInfo", orderInfo },
                { "redirectUrl", redirectUrl },
                { "ipnUrl", ipnUrl },
                { "lang", "vi" },
                { "extraData", extraData },
                { "requestType", requestType },
                { "signature", signature }
            };

            string response = await PaymentRequest.SendPaymentRequestAsync(endpoint, message.ToString(Newtonsoft.Json.Formatting.None));

            // Nếu API trả về JSON hợp lệ thì cố gắng phân tích và lấy mã QR từ MoMo
            if (!string.IsNullOrWhiteSpace(response) && response.TrimStart().StartsWith("{"))
            {
                try
                {
                    JObject json = JObject.Parse(response);
                    // MoMo trả về resultCode = 0 khi thành công
                    if (json["resultCode"]?.ToString() == "0")
                    {
                        // Ưu tiên dùng qrCodeUrl. Nếu không có, dùng payUrl để tự tạo QR
                        string qrUrl = json["qrCodeUrl"]?.ToString() ?? string.Empty;
                        string payUrl = json["payUrl"]?.ToString() ?? string.Empty;
                        if (string.IsNullOrEmpty(qrUrl) && !string.IsNullOrEmpty(payUrl))
                        {
                            // Lấy trực tiếp URL thanh toán để mã hóa; không gọi API bên thứ ba vì môi trường offline
                            // Sử dụng ZXing để tạo QR code offline từ payUrl
                            var localImage = GenerateLocalQrImage(payUrl);
                            return (localImage, orderId, requestId);
                        }
                        if (!string.IsNullOrEmpty(qrUrl))
                        {
                            // Thử tải ảnh QR trực tiếp từ MoMo (nếu được phép trong môi trường chạy)
                            try
                            {
                                using var webClient = new WebClient();
                                webClient.Headers.Add("User-Agent", "Mozilla/5.0");
                                byte[] data = await webClient.DownloadDataTaskAsync(qrUrl);
                                using var ms = new MemoryStream(data);
                                var bitmap = new BitmapImage();
                                bitmap.BeginInit();
                                bitmap.CacheOption = BitmapCacheOption.OnLoad;
                                bitmap.StreamSource = ms;
                                bitmap.EndInit();
                                bitmap.Freeze();
                                return (bitmap, orderId, requestId);
                            }
                            catch
                            {
                                // Nếu tải trực tiếp thất bại, tạo QR offline từ payUrl (nếu có)
                                if (!string.IsNullOrEmpty(payUrl))
                                {
                                    var localImage = GenerateLocalQrImage(payUrl);
                                    return (localImage, orderId, requestId);
                                }
                            }
                        }
                    }
                }
                catch
                {
                    // Ignored; sẽ fallback xuống dưới
                }
            }

            // Nếu đến đây nghĩa là không thể lấy QR từ API MoMo (lỗi mạng hoặc dữ liệu không hợp lệ)
            // Tạo mã QR cục bộ đơn giản với thông tin đơn hàng để có gì đó hiển thị
            var fallbackData = $"orderId={orderId};amount={amount:N0};info={orderInfo}";
            var fallbackImage = GenerateLocalQrImage(fallbackData);
            return (fallbackImage, orderId, requestId);
        }

        /// <summary>
        /// Tạo hình ảnh QR code cục bộ từ một chuỗi dữ liệu sử dụng thư viện ZXing.  Hàm này
        /// không phụ thuộc vào kết nối Internet và sẽ luôn cố gắng tạo QR code hợp lệ.
        /// </summary>
        /// <param name="content">Nội dung cần mã hoá trong QR code.</param>
        /// <returns>Ảnh QR dưới dạng BitmapImage hoặc null nếu tạo không thành công.</returns>
        private static BitmapImage? GenerateLocalQrImage(string content)
        {
            try
            {
                // Sử dụng ZXing để tạo mã QR. BarcodeWriter sẽ trả về đối tượng Bitmap của System.Drawing.
                var writer = new BarcodeWriter
                {
                    Format = BarcodeFormat.QR_CODE,
                    Options = new EncodingOptions
                    {
                        Height = 250,
                        Width = 250,
                        Margin = 1
                    }
                };
                using (Bitmap bitmap = writer.Write(content))
                {
                    using (var ms = new MemoryStream())
                    {
                        bitmap.Save(ms, ImageFormat.Png);
                        ms.Position = 0;
                        var image = new BitmapImage();
                        image.BeginInit();
                        image.CacheOption = BitmapCacheOption.OnLoad;
                        image.StreamSource = ms;
                        image.EndInit();
                        image.Freeze();
                        return image;
                    }
                }
            }
            catch
            {
                return null;
            }
        }

        /// <summary>
        /// Query the payment status for an order.  Returns true when MoMo reports success.
        /// </summary>
        /// <param name="orderId">The order ID used in the create request.</param>
        /// <param name="requestId">A new request ID for the query.</param>
        public async Task<bool> QueryPaymentAsync(string orderId, string requestId)
        {
            string endpoint = "https://test-payment.momo.vn/v2/gateway/api/query";
            string rawHash = $"accessKey={ACCESS_KEY}&orderId={orderId}&partnerCode={PARTNER_CODE}&requestId={requestId}";
            string signature = _security.SignSha256(rawHash, SECRET_KEY);
            var message = new JObject
            {
                { "partnerCode", PARTNER_CODE },
                { "requestId", requestId },
                { "orderId", orderId },
                { "signature", signature },
                { "lang", "vi" }
            };
            string response = await PaymentRequest.SendPaymentRequestAsync(endpoint, message.ToString(Newtonsoft.Json.Formatting.None));
            if (string.IsNullOrWhiteSpace(response) || !response.TrimStart().StartsWith("{")) return false;
            try
            {
                var json = JObject.Parse(response);
                return json["resultCode"]?.ToString() == "0";
            }
            catch
            {
                return false;
            }
        }
    }
}