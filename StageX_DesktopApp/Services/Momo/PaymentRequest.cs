using System;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;

namespace StageX_DesktopApp.Services.Momo
{
    /// <summary>
    /// Provides a helper for sending HTTP POST requests to the MoMo API.  This class wraps
    /// <see cref="HttpClient"/> to send a JSON payload and return the raw response as a string.
    /// </summary>
    public static class PaymentRequest
    {
        private static readonly HttpClient _client = new HttpClient();

        /// <summary>
        /// Send a JSON payload via POST to the specified endpoint and return the response body.
        /// </summary>
        /// <param name="endpoint">The absolute URL of the MoMo endpoint.</param>
        /// <param name="json">The JSON body to send.</param>
        /// <returns>The response body as a string.</returns>
        public static async Task<string> SendPaymentRequestAsync(string endpoint, string json)
        {
            using (var request = new HttpRequestMessage(HttpMethod.Post, endpoint))
            {
                request.Content = new StringContent(json, Encoding.UTF8, "application/json");
                try
                {
                    using (var response = await _client.SendAsync(request))
                    {
                        string content = await response.Content.ReadAsStringAsync();
                        return content;
                    }
                }
                catch (Exception ex)
                {
                    // In case of network errors return the exception message so the caller can handle it
                    return ex.Message;
                }
            }
        }
    }
}