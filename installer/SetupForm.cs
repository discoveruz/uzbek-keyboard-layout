using System;
using System.Drawing;
using System.Linq;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace UzbekKeyboardSetup;

sealed class SetupForm : Form
{
    readonly float scale;
    readonly Label heading;
    readonly Label intro;
    readonly Button[] languageButtons;
    readonly OptionCard[] cards;
    readonly KeyboardView keyboard;
    readonly LegendView legend;
    readonly Label status;
    readonly LinkLabel removeLink;
    readonly Button installButton;
    readonly TableLayoutPanel root;
    Strings text = Strings.Uzbek;
    KeyboardLayout selected;
    bool busy;

    // The last status message, kept as a function of the language so it can be re-translated.
    Func<Strings, string> statusMessage;
    Color statusColor;

    public SetupForm()
    {
        using (var g = CreateGraphics())
            scale = g.DpiX / 96f;

        AutoScaleMode = AutoScaleMode.None;
        Font = new Font("Segoe UI", 9.75f);
        BackColor = Theme.Window;
        ForeColor = Theme.Text;
        StartPosition = FormStartPosition.CenterScreen;
        ClientSize = new Size(S(1080), S(700));
        MinimumSize = new Size(S(860), S(620));
        Icon = AppIcon.Create();

        heading = new Label { Font = new Font("Segoe UI Semibold", 18f), AutoSize = true, Margin = new Padding(0) };
        intro = new Label { AutoSize = true, ForeColor = Theme.Muted, Margin = new Padding(0, S(4), 0, 0) };
        var headingText = new FlowLayoutPanel { FlowDirection = FlowDirection.TopDown, WrapContents = false, AutoSize = true, Dock = DockStyle.Fill, Margin = new Padding(0) };
        headingText.Controls.Add(heading);
        headingText.Controls.Add(intro);

        var languageSwitch = new FlowLayoutPanel { AutoSize = true, WrapContents = false, Anchor = AnchorStyles.Top | AnchorStyles.Right, Margin = new Padding(S(16), S(4), 0, 0) };
        languageButtons = Strings.All.Select(language =>
        {
            var button = new Button
            {
                Text = language.LanguageName,
                Tag = language,
                AutoSize = true,
                FlatStyle = FlatStyle.Flat,
                Font = new Font("Segoe UI", 9f),
                Padding = new Padding(S(6), 0, S(6), 0),
                Margin = new Padding(0),
                Cursor = Cursors.Hand,
            };
            button.Click += (_, _) => SetLanguage(language);
            languageSwitch.Controls.Add(button);
            return button;
        }).ToArray();

        var header = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 2, RowCount = 1, AutoSize = true, Margin = new Padding(0, 0, 0, S(14)) };
        header.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        header.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        header.Controls.Add(headingText, 0, 0);
        header.Controls.Add(languageSwitch, 1, 0);

        var cardRow = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = Catalog.All.Length, RowCount = 1, Margin = new Padding(0, 0, 0, S(12)) };
        cardRow.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        cards = new OptionCard[Catalog.All.Length];
        for (int i = 0; i < cards.Length; i++)
        {
            cardRow.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100f / cards.Length));
            var card = new OptionCard(Catalog.All[i], scale)
            {
                Dock = DockStyle.Fill,
                Margin = new Padding(i == 0 ? 0 : S(6), 0, i == cards.Length - 1 ? 0 : S(6), 0),
            };
            card.Click += (_, _) => Choose(card.Choice);
            cardRow.Controls.Add(card, i, 0);
            cards[i] = card;
        }

        keyboard = new KeyboardView(scale) { Dock = DockStyle.Fill, Margin = new Padding(0) };
        legend = new LegendView(scale) { Dock = DockStyle.Fill, Margin = new Padding(0, S(6), 0, S(6)) };

        status = new Label { Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleLeft, ForeColor = Theme.Muted, AutoEllipsis = true, Margin = new Padding(0) };
        removeLink = new LinkLabel
        {
            AutoSize = true,
            Anchor = AnchorStyles.Right,
            LinkColor = Theme.Bad,
            ActiveLinkColor = Theme.Bad,
            LinkBehavior = LinkBehavior.HoverUnderline,
            Margin = new Padding(S(12), 0, S(18), 0),
            Visible = false,
        };
        removeLink.LinkClicked += async (_, _) => await RemoveAsync();
        installButton = new Button
        {
            Size = new Size(S(210), S(44)),
            Anchor = AnchorStyles.Right,
            FlatStyle = FlatStyle.Flat,
            BackColor = Theme.Accent,
            ForeColor = Color.White,
            Font = new Font("Segoe UI Semibold", 10.5f),
            Cursor = Cursors.Hand,
            Margin = new Padding(0),
        };
        installButton.FlatAppearance.BorderSize = 0;
        installButton.Click += async (_, _) => await InstallAsync();

        var footer = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 3, RowCount = 1, Margin = new Padding(0) };
        footer.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        footer.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        footer.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        footer.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        footer.Controls.Add(status, 0, 0);
        footer.Controls.Add(removeLink, 1, 0);
        footer.Controls.Add(installButton, 2, 0);

        root = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 5, Padding = new Padding(S(24), S(20), S(24), S(18)) };
        root.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, S(116)));
        root.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, S(72)));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, S(48)));
        root.Controls.Add(header, 0, 0);
        root.Controls.Add(cardRow, 0, 1);
        root.Controls.Add(keyboard, 0, 2);
        root.Controls.Add(legend, 0, 3);
        root.Controls.Add(footer, 0, 4);
        Controls.Add(root);

        Resize += (_, _) => FitIntro();

        RefreshInstalled();
        selected = Catalog.All[0];
        SetLanguage(Strings.Uzbek);
        Choose(selected);
    }

    int S(float px) => (int)Math.Round(px * scale);

    void FitIntro()
    {
        int switchWidth = languageButtons.Sum(b => b.Width) + S(16);
        intro.MaximumSize = new Size(Math.Max(S(200), root.ClientSize.Width - root.Padding.Horizontal - switchWidth), 0);
    }

    /// <summary>Shows a layout as if its card had been clicked.</summary>
    public void ShowLayout(KeyboardLayout layout) => Choose(layout);

    /// <summary>For README pictures: shows every layout as not installed, whatever this PC has.</summary>
    public void ShowAsNotInstalled()
    {
        foreach (var card in cards)
            card.ProductCode = null;
        UpdateActions();
    }

    public void SaveKeyboardImage(string path)
    {
        using var bitmap = new Bitmap(keyboard.Width, keyboard.Height);
        keyboard.DrawToBitmap(bitmap, new Rectangle(Point.Empty, keyboard.Size));
        bitmap.Save(path, System.Drawing.Imaging.ImageFormat.Png);
    }

    public void SetLanguage(Strings language)
    {
        text = language;
        Text = language.WindowTitle;
        heading.Text = language.Heading;
        intro.Text = language.Intro;
        foreach (var button in languageButtons)
        {
            bool on = button.Tag == language;
            button.BackColor = on ? Theme.Accent : Theme.Surface;
            button.ForeColor = on ? Color.White : Theme.Text;
            button.FlatAppearance.BorderColor = on ? Theme.Accent : Theme.Line;
        }
        foreach (var card in cards)
            card.SetText(language.Title(card.Choice), language.Summary(card.Choice), language.Badge);
        legend.Language = language;
        keyboard.AccessibleName = language.Title(selected);
        FitIntro();
        UpdateActions(statusMessage, statusColor);
    }

    void Choose(KeyboardLayout layout)
    {
        if (busy)
            return;
        selected = layout;
        foreach (var card in cards)
            card.Selected = card.Choice == layout;
        keyboard.Current = layout;
        keyboard.AccessibleName = text.Title(layout);
        UpdateActions();
    }

    void RefreshInstalled()
    {
        foreach (var card in cards)
            card.ProductCode = Setup.FindInstalledProductCode(card.Choice);
    }

    OptionCard SelectedCard => cards.First(c => c.Choice == selected);

    void UpdateActions(Func<Strings, string> message = null, Color? color = null)
    {
        bool installed = SelectedCard.Installed;
        bool hasPackage = Setup.HasPackage(selected);
        bool supported = Setup.Machine != MachineKind.Arm64;
        string title = text.Title(selected);

        installButton.Text = installed ? text.InstalledButton : text.InstallButton(title);
        installButton.Enabled = !busy && !installed && hasPackage && supported;
        installButton.BackColor = installButton.Enabled ? Theme.Accent : Theme.AccentDisabled;
        removeLink.Text = text.RemoveLink(title);
        removeLink.Visible = installed && !busy;
        foreach (var card in cards)
            card.Enabled = !busy;

        if (message == null)
        {
            var layout = selected;
            message = !supported ? t => t.ArmUnsupported
                : !hasPackage ? t => t.NotIncluded(t.Title(layout))
                : installed ? t => t.IsInstalled(layout.ProductName)
                : t => t.AfterInstallHint;
            color = !supported || !hasPackage ? Theme.Bad : installed ? Theme.Ok : Theme.Muted;
        }
        statusMessage = message;
        statusColor = color ?? Theme.Muted;
        status.Text = message(text);
        status.ForeColor = statusColor;
    }

    async Task InstallAsync()
    {
        if (busy)
            return;
        var layout = selected;
        await RunAsync(t => t.Installing(t.Title(layout)),
            () => Setup.InstallAsync(layout),
            result => result.ExitCode switch
            {
                0 => (t => t.InstalledNow(layout.ProductName), Theme.Ok),
                1641 or 3010 => (t => t.InstalledRestart(layout.ProductName), Theme.Ok),
                1602 => (t => t.InstallCancelled, Theme.Muted),
                1618 => (t => t.AnotherInstall, Theme.Bad),
                _ => (t => t.InstallerError(result.ExitCode, result.LogPath), Theme.Bad),
            });
    }

    async Task RemoveAsync()
    {
        if (busy || !SelectedCard.Installed)
            return;
        var layout = selected;
        string productCode = SelectedCard.ProductCode;
        await RunAsync(t => t.Removing(t.Title(layout)),
            () => Setup.RemoveAsync(layout, productCode),
            result => result.ExitCode switch
            {
                0 or 1641 or 3010 => (t => t.Removed(layout.ProductName), Theme.Ok),
                1602 => (t => t.RemoveCancelled, Theme.Muted),
                1618 => (t => t.AnotherInstall, Theme.Bad),
                _ => (t => t.InstallerError(result.ExitCode, result.LogPath), Theme.Bad),
            });
    }

    async Task RunAsync(Func<Strings, string> progress, Func<Task<MsiResult>> action,
        Func<MsiResult, (Func<Strings, string> Message, Color Color)> describe)
    {
        busy = true;
        UseWaitCursor = true;
        UpdateActions(progress);
        (Func<Strings, string> Message, Color Color) outcome;
        try
        {
            outcome = describe(await action());
        }
        catch (Exception ex)
        {
            outcome = (t => t.CouldNotRun(ex.Message), Theme.Bad);
        }
        busy = false;
        UseWaitCursor = false;
        RefreshInstalled();
        UpdateActions(outcome.Message, outcome.Color);
    }

    protected override bool ProcessCmdKey(ref Message msg, Keys keyData)
    {
        if ((keyData == Keys.Left || keyData == Keys.Right) && ActiveControl is OptionCard card && !busy)
        {
            int next = Array.IndexOf(cards, card) + (keyData == Keys.Right ? 1 : -1);
            if (next >= 0 && next < cards.Length)
            {
                cards[next].Focus();
                Choose(cards[next].Choice);
            }
            return true;
        }
        return base.ProcessCmdKey(ref msg, keyData);
    }
}
