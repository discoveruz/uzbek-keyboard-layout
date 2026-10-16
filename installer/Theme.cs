using System;
using System.Drawing;
using System.Drawing.Drawing2D;

namespace UzbekKeyboardSetup;

static class Theme
{
    // Azure from the Uzbek flag, deepened for contrast on white.
    public static readonly Color Accent = Color.FromArgb(0x0A, 0x7C, 0x99);
    public static readonly Color AccentSoft = Color.FromArgb(0xE4, 0xF3, 0xF7);
    public static readonly Color AccentDisabled = Color.FromArgb(0xA6, 0xC6, 0xCF);
    public static readonly Color Window = Color.FromArgb(0xF2, 0xF5, 0xF7);
    public static readonly Color Surface = Color.White;
    public static readonly Color Text = Color.FromArgb(0x14, 0x23, 0x2B);
    public static readonly Color Muted = Color.FromArgb(0x5B, 0x6E, 0x79);
    public static readonly Color Line = Color.FromArgb(0xD2, 0xDD, 0xE3);
    public static readonly Color Ok = Color.FromArgb(0x16, 0x80, 0x3A);
    public static readonly Color OkSoft = Color.FromArgb(0xE0, 0xF2, 0xE5);
    public static readonly Color Bad = Color.FromArgb(0xBF, 0x26, 0x30);

    public static readonly Color Case = Color.FromArgb(0x26, 0x34, 0x3C);
    public static readonly Color Key = Color.FromArgb(0xFA, 0xFC, 0xFD);
    public static readonly Color KeyChanged = Color.FromArgb(0xD6, 0xEE, 0xF5);
    public static readonly Color KeyMod = Color.FromArgb(0xC9, 0xD4, 0xDA);
    public static readonly Color KeyShadow = Color.FromArgb(0x8E, 0xA1, 0xAB);
    public static readonly Color AltGrText = Color.FromArgb(0x55, 0x6B, 0x77);
}

static class Shapes
{
    public static GraphicsPath RoundRect(RectangleF r, float radius)
    {
        var path = new GraphicsPath();
        float d = Math.Min(radius * 2, Math.Min(r.Width, r.Height));
        if (d <= 0)
        {
            path.AddRectangle(r);
            return path;
        }
        path.AddArc(r.X, r.Y, d, d, 180, 90);
        path.AddArc(r.Right - d, r.Y, d, d, 270, 90);
        path.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
        path.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
        path.CloseFigure();
        return path;
    }
}

static class AppIcon
{
    /// <summary>A keycap with Ö on it, drawn at run time for the window and taskbar.</summary>
    public static Icon Create()
    {
        using var bitmap = new Bitmap(64, 64);
        using (var g = Graphics.FromImage(bitmap))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAliasGridFit;
            using var shadow = Shapes.RoundRect(new RectangleF(4, 8, 56, 52), 12);
            using var face = Shapes.RoundRect(new RectangleF(4, 4, 56, 52), 12);
            using var shadowBrush = new SolidBrush(Color.FromArgb(0x06, 0x55, 0x6A));
            using var faceBrush = new SolidBrush(Theme.Accent);
            g.FillPath(shadowBrush, shadow);
            g.FillPath(faceBrush, face);
            using var font = new Font("Segoe UI Semibold", 30, GraphicsUnit.Pixel);
            using var format = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center };
            g.DrawString("Ö", font, Brushes.White, new RectangleF(4, 6, 56, 50), format);
        }
        return Icon.FromHandle(bitmap.GetHicon());
    }
}
