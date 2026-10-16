using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Windows.Forms;

namespace UzbekKeyboardSetup;

/// <summary>Draws a US-shaped keyboard with what each key types alone, with Shift, with AltGr and with AltGr+Shift.</summary>
sealed class KeyboardView : Control
{
    sealed class KeyDef
    {
        public KeyDef(string code, string label, float width, bool isAltGr = false)
        {
            Code = code;
            Label = label;
            Width = width;
            IsAltGr = isAltGr;
        }

        public string Code { get; }
        public string Label { get; }
        public float Width { get; }
        public bool IsAltGr { get; }
    }

    static KeyDef K(string code, float width = 1) => new(code, null, width);
    static KeyDef M(string label, float width, bool isAltGr = false) => new(null, label, width, isAltGr);

    // Standard ANSI rows, 15 key widths each.
    static readonly KeyDef[][] Rows =
    {
        new[] { K("Backquote"), K("Digit1"), K("Digit2"), K("Digit3"), K("Digit4"), K("Digit5"), K("Digit6"), K("Digit7"), K("Digit8"), K("Digit9"), K("Digit0"), K("Minus"), K("Equal"), M("Backspace", 2) },
        new[] { M("Tab", 1.5f), K("KeyQ"), K("KeyW"), K("KeyE"), K("KeyR"), K("KeyT"), K("KeyY"), K("KeyU"), K("KeyI"), K("KeyO"), K("KeyP"), K("BracketLeft"), K("BracketRight"), K("Backslash", 1.5f) },
        new[] { M("Caps Lock", 1.75f), K("KeyA"), K("KeyS"), K("KeyD"), K("KeyF"), K("KeyG"), K("KeyH"), K("KeyJ"), K("KeyK"), K("KeyL"), K("Semicolon"), K("Quote"), M("Enter", 2.25f) },
        new[] { M("Shift", 2.25f), K("KeyZ"), K("KeyX"), K("KeyC"), K("KeyV"), K("KeyB"), K("KeyN"), K("KeyM"), K("Comma"), K("Period"), K("Slash"), M("Shift", 2.75f) },
        new[] { M("Ctrl", 1.25f), M("Win", 1.25f), M("Alt", 1.25f), M("", 6.25f), M("AltGr", 1.25f, isAltGr: true), M("Win", 1.25f), M("Menu", 1.25f), M("Ctrl", 1.25f) },
    };

    static readonly HashSet<string> UzbekLetters = new() { "ö", "Ö", "ş", "Ş", "ğ", "Ğ", "ç", "Ç", "ʼ", "ʻ" };

    readonly float scale;
    KeyboardLayout current;

    public KeyboardView(float scale)
    {
        this.scale = scale;
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
        BackColor = Theme.Window;
    }

    public KeyboardLayout Current
    {
        get => current;
        set
        {
            current = value;
            Invalidate();
        }
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        g.Clear(BackColor);
        if (current == null)
            return;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;

        float margin = 14 * scale;
        float unit = Math.Min((Width - margin * 2) / 15f, (Height - margin * 2) / 5f);
        if (unit < 10)
            return;
        float boardWidth = unit * 15, boardHeight = unit * 5;
        float left = (Width - boardWidth) / 2, top = (Height - boardHeight) / 2;
        float rim = unit * 0.22f;

        using (var casePath = Shapes.RoundRect(new RectangleF(left - rim, top - rim, boardWidth + rim * 2, boardHeight + rim * 2), unit * 0.25f))
        using (var caseBrush = new SolidBrush(Theme.Case))
            g.FillPath(caseBrush, casePath);

        using var fonts = new KeyFonts(unit);
        float gap = unit * 0.08f;
        for (int row = 0; row < Rows.Length; row++)
        {
            float x = left;
            foreach (var key in Rows[row])
            {
                var cell = new RectangleF(x + gap / 2, top + row * unit + gap / 2, key.Width * unit - gap, unit - gap);
                DrawKey(g, cell, key, unit, fonts);
                x += key.Width * unit;
            }
        }
    }

    void DrawKey(Graphics g, RectangleF cell, KeyDef key, float unit, KeyFonts fonts)
    {
        float depth = unit * 0.06f;
        float radius = unit * 0.12f;
        var face = new RectangleF(cell.X, cell.Y, cell.Width, cell.Height - depth);
        var chars = key.Code != null ? current.Get(key.Code) : null;
        var faceColor = chars == null ? Theme.KeyMod : DiffersFromUs(key.Code, chars) ? Theme.KeyChanged : Theme.Key;

        using (var shadowPath = Shapes.RoundRect(new RectangleF(cell.X, cell.Y + depth, cell.Width, cell.Height - depth), radius))
        using (var shadowBrush = new SolidBrush(Theme.KeyShadow))
            g.FillPath(shadowBrush, shadowPath);
        using (var facePath = Shapes.RoundRect(face, radius))
        {
            using (var faceBrush = new SolidBrush(faceColor))
                g.FillPath(faceBrush, facePath);
            if (key.IsAltGr)
                using (var pen = new Pen(Theme.Accent, Math.Max(1.5f, unit * 0.045f)))
                    g.DrawPath(pen, facePath);
        }

        var inner = RectangleF.Inflate(face, -unit * 0.12f, -unit * 0.09f);
        if (chars == null)
        {
            if (key.IsAltGr)
                Draw(g, key.Label, fonts.LabelBold, Theme.Accent, inner, StringAlignment.Near, StringAlignment.Far);
            else
                Draw(g, key.Label, fonts.Label, Theme.Muted, inner, StringAlignment.Near, StringAlignment.Far);
            return;
        }

        // Left half: the key alone and with Shift. A letter pair prints once, as the capital.
        if (IsCasePair(chars[0], chars[1]))
        {
            Draw(g, chars[1], Pick(chars[1], fonts.Big, fonts.BigBold), ColorFor(chars[1], Theme.Text), inner, StringAlignment.Near, StringAlignment.Near);
        }
        else
        {
            Draw(g, chars[1], Pick(chars[1], fonts.Mid, fonts.MidBold), ColorFor(chars[1], Theme.Text), inner, StringAlignment.Near, StringAlignment.Near);
            Draw(g, chars[0], Pick(chars[0], fonts.Mid, fonts.MidBold), ColorFor(chars[0], Theme.Text), inner, StringAlignment.Near, StringAlignment.Far);
        }

        // Right half: AltGr and AltGr+Shift.
        if (IsCasePair(chars[2], chars[3]))
        {
            Draw(g, chars[3], Pick(chars[3], fonts.Mid, fonts.MidBold), ColorFor(chars[3], Theme.AltGrText), inner, StringAlignment.Far, StringAlignment.Far);
        }
        else
        {
            Draw(g, chars[3], Pick(chars[3], fonts.Small, fonts.SmallBold), ColorFor(chars[3], Theme.AltGrText), inner, StringAlignment.Far, StringAlignment.Near);
            Draw(g, chars[2], Pick(chars[2], fonts.Small, fonts.SmallBold), ColorFor(chars[2], Theme.AltGrText), inner, StringAlignment.Far, StringAlignment.Far);
        }
    }

    static bool DiffersFromUs(string code, string[] chars)
    {
        var us = Catalog.Us.Get(code);
        return chars[0] != us[0] || chars[1] != us[1];
    }

    static bool IsCasePair(string lower, string upper) =>
        lower != null && upper != null && lower.Length == 1 && lower != upper
        && char.IsLetter(lower[0]) && upper == lower.ToUpperInvariant();

    static Font Pick(string text, Font regular, Font bold) => text != null && UzbekLetters.Contains(text) ? bold : regular;

    static Color ColorFor(string text, Color normal) => text != null && UzbekLetters.Contains(text) ? Theme.Accent : normal;

    static void Draw(Graphics g, string text, Font font, Color color, RectangleF area, StringAlignment horizontal, StringAlignment vertical)
    {
        if (string.IsNullOrEmpty(text))
            return;
        using var brush = new SolidBrush(color);
        using var format = new StringFormat(StringFormat.GenericTypographic)
        {
            Alignment = horizontal,
            LineAlignment = vertical,
            FormatFlags = StringFormatFlags.NoWrap | StringFormatFlags.NoClip,
        };
        g.DrawString(text, font, brush, area, format);
    }

    sealed class KeyFonts : IDisposable
    {
        public KeyFonts(float unit)
        {
            Big = new Font("Segoe UI", unit * 0.34f, GraphicsUnit.Pixel);
            BigBold = new Font("Segoe UI", unit * 0.36f, FontStyle.Bold, GraphicsUnit.Pixel);
            Mid = new Font("Segoe UI", unit * 0.25f, GraphicsUnit.Pixel);
            MidBold = new Font("Segoe UI", unit * 0.27f, FontStyle.Bold, GraphicsUnit.Pixel);
            Small = new Font("Segoe UI", unit * 0.21f, GraphicsUnit.Pixel);
            // Large enough that the thin ʼ and ʻ marks stay readable.
            SmallBold = new Font("Segoe UI", unit * 0.32f, FontStyle.Bold, GraphicsUnit.Pixel);
            Label = new Font("Segoe UI", unit * 0.17f, GraphicsUnit.Pixel);
            LabelBold = new Font("Segoe UI Semibold", unit * 0.19f, GraphicsUnit.Pixel);
        }

        public Font Big { get; }
        public Font BigBold { get; }
        public Font Mid { get; }
        public Font MidBold { get; }
        public Font Small { get; }
        public Font SmallBold { get; }
        public Font Label { get; }
        public Font LabelBold { get; }

        public void Dispose()
        {
            Big.Dispose(); BigBold.Dispose(); Mid.Dispose(); MidBold.Dispose();
            Small.Dispose(); SmallBold.Dispose(); Label.Dispose(); LabelBold.Dispose();
        }
    }
}

/// <summary>Explains the four corners of a key and the colors used on the keyboard.</summary>
sealed class LegendView : Control
{
    readonly float scale;
    readonly Font cornerFont = new("Segoe UI", 7.5f);
    readonly Font letterFont = new("Segoe UI", 12f, FontStyle.Bold);
    Strings text = Strings.Uzbek;

    public LegendView(float scale)
    {
        this.scale = scale;
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
        BackColor = Theme.Window;
    }

    public Strings Language
    {
        get => text;
        set
        {
            text = value;
            Invalidate();
        }
    }

    int S(float px) => (int)Math.Round(px * scale);

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        g.Clear(BackColor);
        g.SmoothingMode = SmoothingMode.AntiAlias;

        // Sample key with its four corners named.
        var key = new Rectangle(0, (Height - S(54)) / 2, S(118), S(54));
        using (var path = Shapes.RoundRect(key, S(7)))
        {
            using var fill = new SolidBrush(Theme.Surface);
            using var pen = new Pen(Theme.Line);
            g.FillPath(fill, path);
            g.DrawPath(pen, path);
        }
        var inner = Rectangle.Inflate(key, -S(7), -S(5));
        TextRenderer.DrawText(g, text.LegendShift, cornerFont, inner, Theme.Text, TextFormatFlags.Left | TextFormatFlags.Top | TextFormatFlags.NoPadding);
        TextRenderer.DrawText(g, text.LegendAltGrShift, cornerFont, inner, Theme.AltGrText, TextFormatFlags.Right | TextFormatFlags.Top | TextFormatFlags.NoPadding);
        TextRenderer.DrawText(g, text.LegendKey, cornerFont, inner, Theme.Text, TextFormatFlags.Left | TextFormatFlags.Bottom | TextFormatFlags.NoPadding);
        TextRenderer.DrawText(g, text.LegendAltGr, cornerFont, inner, Theme.AltGrText, TextFormatFlags.Right | TextFormatFlags.Bottom | TextFormatFlags.NoPadding);

        int x = key.Right + S(24);
        int mid = Height / 2;

        // Uzbek letters are drawn in the accent color.
        var letterSize = TextRenderer.MeasureText(g, "ö", letterFont, Size.Empty, TextFormatFlags.NoPadding);
        TextRenderer.DrawText(g, "ö", letterFont, new Point(x, mid - letterSize.Height / 2), Theme.Accent, TextFormatFlags.NoPadding);
        x += letterSize.Width + S(8);
        x = Item(g, x, mid, text.LegendUzbekLetter) + S(28);

        // Tinted keys type something different from a US keyboard.
        using (var swatch = Shapes.RoundRect(new Rectangle(x, mid - S(9), S(18), S(18)), S(4)))
        using (var fill = new SolidBrush(Theme.KeyChanged))
        using (var pen = new Pen(Theme.KeyShadow))
        {
            g.FillPath(fill, swatch);
            g.DrawPath(pen, swatch);
        }
        x = Item(g, x + S(26), mid, text.LegendChanged) + S(28);

        // AltGr is the right Alt key.
        using (var swatch = Shapes.RoundRect(new Rectangle(x, mid - S(9), S(18), S(18)), S(4)))
        using (var pen = new Pen(Theme.Accent, S(2)))
            g.DrawPath(pen, swatch);
        Item(g, x + S(26), mid, text.LegendAltGrKey);
    }

    int Item(Graphics g, int x, int mid, string text)
    {
        var size = TextRenderer.MeasureText(g, text, Font, Size.Empty, TextFormatFlags.NoPadding);
        TextRenderer.DrawText(g, text, Font, new Point(x, mid - size.Height / 2), Theme.Muted, TextFormatFlags.NoPadding);
        return x + size.Width;
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            cornerFont.Dispose();
            letterFont.Dispose();
        }
        base.Dispose(disposing);
    }
}
