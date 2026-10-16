using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Linq;
using System.Windows.Forms;

namespace UzbekKeyboardSetup;

static class Program
{
    [STAThread]
    static void Main(string[] args)
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);

        // Developer aid: saves the README pictures instead of opening the window.
        if (args.Length == 2 && args[0] == "--render-images")
        {
            RenderImages(args[1]);
            return;
        }

        Application.Run(new SetupForm());
    }

    static void RenderImages(string folder)
    {
        Directory.CreateDirectory(folder);
        using var form = new SetupForm { StartPosition = FormStartPosition.Manual, Location = new Point(-20000, -20000), ShowInTaskbar = false };
        form.Show();
        form.ShowAsNotInstalled();

        // The whole window, in each language, with Direct selected.
        var direct = Catalog.All.First(layout => layout.Kbd == "uzlt26d");
        foreach (var language in Strings.All)
        {
            form.SetLanguage(language);
            form.ShowLayout(direct);
            Application.DoEvents();
            using var bitmap = new Bitmap(form.Width, form.Height);
            form.DrawToBitmap(bitmap, new Rectangle(Point.Empty, form.Size));
            bitmap.Save(Path.Combine(folder, $"installer-{(language == Strings.Uzbek ? "uz" : "en")}.png"), ImageFormat.Png);
        }

        // Just the keyboard, for each layout.
        form.SetLanguage(Strings.English);
        foreach (var layout in Catalog.All)
        {
            form.ShowLayout(layout);
            Application.DoEvents();
            string slug = Strings.English.Title(layout).ToLowerInvariant().Replace(' ', '-');
            form.SaveKeyboardImage(Path.Combine(folder, $"layout-{slug}.png"));
        }
    }
}
