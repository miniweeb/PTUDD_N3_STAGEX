using System;
using System.Security.Cryptography;
using System.Text;

namespace StageX_DesktopApp.Services.Momo
{
    /// <summary>
    /// Utility class for signing messages with HMAC‑SHA256 for MoMo requests.
    /// This class is a simplified copy of the helper used in the CinemaGr5 project.
    /// </summary>
    public class MoMoSecurity
    {
        /// <summary>
        /// Compute an HMAC‑SHA256 signature for the specified message using the provided secret key.
        /// The resulting hash is returned as a lowercase hexadecimal string.
        /// </summary>
        /// <param name="message">The concatenated raw hash string to sign.</param>
        /// <param name="key">Your MoMo secret key.</param>
        /// <returns>The HMAC‑SHA256 signature in lowercase hexadecimal.</returns>
        public string SignSha256(string message, string key)
        {
            byte[] keyBytes = Encoding.UTF8.GetBytes(key);
            byte[] messageBytes = Encoding.UTF8.GetBytes(message);
            using (var hmac = new HMACSHA256(keyBytes))
            {
                byte[] hash = hmac.ComputeHash(messageBytes);
                return BitConverter.ToString(hash).Replace("-", string.Empty).ToLowerInvariant();
            }
        }
    }
}