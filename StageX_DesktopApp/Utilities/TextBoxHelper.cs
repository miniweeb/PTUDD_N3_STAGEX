using System.Text.RegularExpressions;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;

namespace StageX_DesktopApp.Utilities
{
    public static class TextBoxHelper
    {
        public static readonly DependencyProperty IsNumericProperty =
            DependencyProperty.RegisterAttached("IsNumeric", typeof(bool), typeof(TextBoxHelper),
                new UIPropertyMetadata(false, OnIsNumericChanged));

        public static bool GetIsNumeric(DependencyObject obj) => (bool)obj.GetValue(IsNumericProperty);
        public static void SetIsNumeric(DependencyObject obj, bool value) => obj.SetValue(IsNumericProperty, value);

        private static void OnIsNumericChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
        {
            if (d is TextBox textBox)
            {
                // Hủy đăng ký cũ để tránh trùng lặp
                textBox.PreviewTextInput -= BlockNonDigitCharacters;
                textBox.PreviewKeyDown -= BlockSpaceKey;
                DataObject.RemovePastingHandler(textBox, OnPaste);

                if ((bool)e.NewValue)
                {
                    // Tắt bộ gõ (IME) để ngăn nhập chữ tiếng Việt
                    InputMethod.SetIsInputMethodEnabled(textBox, false);

                    textBox.PreviewTextInput += BlockNonDigitCharacters;
                    textBox.PreviewKeyDown += BlockSpaceKey;
                    DataObject.AddPastingHandler(textBox, OnPaste);
                }
            }
        }

        // Logic chính: Chặn ký tự không phải số VÀ chặn số 0 ở đầu
        private static void BlockNonDigitCharacters(object sender, TextCompositionEventArgs e)
        {
            var textBox = sender as TextBox;

            // 1. Chặn nếu không phải số (Regex)
            if (new Regex("[^0-9]").IsMatch(e.Text))
            {
                e.Handled = true;
                return;
            }
        }

        // Chặn phím Space
        private static void BlockSpaceKey(object sender, KeyEventArgs e)
        {
            if (e.Key == Key.Space) e.Handled = true;
        }

        // Chặn Paste chữ hoặc chuỗi bắt đầu bằng 0
        private static void OnPaste(object sender, DataObjectPastingEventArgs e)
        {
            if (e.DataObject.GetDataPresent(typeof(string)))
            {
                string text = (string)e.DataObject.GetData(typeof(string));

                // Regex check: Có ký tự không phải số HOẶC bắt đầu bằng số 0
                if (new Regex("[^0-9]").IsMatch(text) || text.StartsWith("0"))
                {
                    e.CancelCommand();
                }
            }
            else
            {
                e.CancelCommand();
            }
        }
    }
}