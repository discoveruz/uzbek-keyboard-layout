using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace UzbekKeyboardSetup;

/// <summary>One selectable layout: a radio dot, its name, a one-line summary and an "Installed" badge.</summary>
sealed class OptionCard : Control
{
    readonly float scale;
    readonly Font titleFont = new("Segoe UI Semibold", 12.5f);
    readonly Font badgeFont = new("Segoe UI Semibold", 8.25f);
    bool selected;
    string productCode;
    string title = "", summary = "", badge = "";

    public OptionCard(KeyboardLayout choice, float scale)
    {
        Choice = choice;
        this.scale = scale;
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint
            | ControlStyles.ResizeRedraw | ControlStyles.Selectable, true);
        TabStop = true;
        Cursor = Cursors.Hand;
        BackColor = Theme.Window;
        AccessibleRole = AccessibleRole.RadioButton;
    }

    public KeyboardLayout Choice { get; }

    public void SetText(string title, string summary, string badge)
    {
        this.title = title;
        this.summary = summary;
        this.badge = badge;
        AccessibleName = title;
        AccessibleDescription = summary;
        Invalidate();
    }

    public bool Selected
    {
        get => selected;
        set
        {
            if (selected == value)
                return;
            selected = value;
            Invalidate();
        }
    }

    /// <summary>Set when this layout is installed; used to remove it.</summary>
    public string ProductCode
    {
        get => productCode;
        set
        {
            productCode = value;
            Invalidate();
        }
    }

    public bool Installed => productCode != null;

    int S(float px) => (int)Math.Round(px * scale);

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        g.Clear(BackColor);
        g.SmoothingMode = SmoothingMode.AntiAlias;

        float border = selected ? 2 * scale : 1;
        var box = new RectangleF(border / 2, border / 2, Width - border - 1, Height - border - 1);
        using (var path = Shapes.RoundRect(box, S(10)))
        using (var fill = new SolidBrush(selected ? Theme.AccentSoft : Theme.Surface))
        using (var pen = new Pen(selected ? Theme.Accent : Theme.Line, border))
        {
            g.FillPath(fill, path);
            g.DrawPath(pen, path);
        }

        // Radio dot
        var dot = new RectangleF(S(16), S(16), S(18), S(18));
        using (var pen = new Pen(selected ? Theme.Accent : Theme.Muted, 1.6f * scale))
            g.DrawEllipse(pen, dot);
        if (selected)
            using (var fill = new SolidBrush(Theme.Accent))
                g.FillEllipse(fill, RectangleF.Inflate(dot, -S(4.5f), -S(4.5f)));

        int textLeft = S(44);
        TextRenderer.DrawText(g, title, titleFont, new Point(textLeft, S(11)), selected ? Theme.Accent : Theme.Text, TextFormatFlags.NoPadding);

        if (Installed)
        {
            var size = TextRenderer.MeasureText(g, badge, badgeFont, Size.Empty, TextFormatFlags.NoPadding);
            var pill = new Rectangle(Width - S(14) - size.Width - S(18), S(13), size.Width + S(18), S(22));
            using (var path = Shapes.RoundRect(pill, pill.Height / 2f))
            using (var fill = new SolidBrush(Theme.OkSoft))
                g.FillPath(fill, path);
            TextRenderer.DrawText(g, badge, badgeFont, pill, Theme.Ok, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding);
        }

        var summaryBox = new Rectangle(textLeft, S(42), Width - textLeft - S(14), Height - S(48));
        TextRenderer.DrawText(g, summary, Font, summaryBox, Theme.Muted,
            TextFormatFlags.WordBreak | TextFormatFlags.NoPrefix | TextFormatFlags.EndEllipsis | TextFormatFlags.NoPadding);

        if (Focused && ShowFocusCues)
        {
            using var pen = new Pen(Theme.Accent) { DashStyle = DashStyle.Dot };
            g.DrawRectangle(pen, S(5), S(5), Width - S(11), Height - S(11));
        }
    }

    protected override void OnMouseDown(MouseEventArgs e)
    {
        Focus();
        base.OnMouseDown(e);
    }

    protected override void OnKeyDown(KeyEventArgs e)
    {
        if (e.KeyCode == Keys.Space || e.KeyCode == Keys.Enter)
        {
            OnClick(EventArgs.Empty);
            e.Handled = true;
        }
        base.OnKeyDown(e);
    }

    protected override void OnGotFocus(EventArgs e)
    {
        Invalidate();
        base.OnGotFocus(e);
    }

    protected override void OnLostFocus(EventArgs e)
    {
        Invalidate();
        base.OnLostFocus(e);
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            titleFont.Dispose();
            badgeFont.Dispose();
        }
        base.Dispose(disposing);
    }
}
