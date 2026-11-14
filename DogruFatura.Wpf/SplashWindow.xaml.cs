using System.Diagnostics;
using System.Windows;
using System.Windows.Media;
using System.Windows.Threading;

namespace DogruFatura.Wpf;

public partial class SplashWindow : Window
{
    private const double RingCenter = 68;
    private const double RingRadius = 59;
    private readonly Stopwatch _visibleStopwatch = new();
    private DispatcherTimer? _percentTimer;
    private bool _completionStarted;
    private int _percent;

    public SplashWindow()
    {
        InitializeComponent();
        Loaded += SplashWindow_Loaded;
        Closed += (_, _) => _percentTimer?.Stop();
    }

    private void SplashWindow_Loaded(object sender, RoutedEventArgs e)
    {
        VersionText.Text = AppVersionInfo.DisplayVersion;
        SetProgress(0);
        _visibleStopwatch.Start();
        _percentTimer = new DispatcherTimer(
            TimeSpan.FromMilliseconds(StartupProgressProfile.FrameDelayMs),
            DispatcherPriority.Render,
            (_, _) => UpdateProgressText(),
            Dispatcher);
        _percentTimer.Start();
    }

    private void SetProgress(int percent)
    {
        _percent = percent;
        PercentText.Text = $"%{percent}";
        CompletedRing.Visibility = percent == 100 ? Visibility.Visible : Visibility.Collapsed;
        if (percent is 0 or 100)
        {
            ProgressArc.Data = null;
            return;
        }

        var angle = percent * 2 * Math.PI / 100;
        var end = new Point(RingCenter + RingRadius * Math.Sin(angle), RingCenter - RingRadius * Math.Cos(angle));
        var geometry = new StreamGeometry();
        using (var context = geometry.Open())
        {
            context.BeginFigure(new Point(RingCenter, RingCenter - RingRadius), false, false);
            context.ArcTo(end, new Size(RingRadius, RingRadius), 0, percent > 50, SweepDirection.Clockwise, true, false);
        }
        geometry.Freeze();
        ProgressArc.Data = geometry;
    }

    private void UpdateProgressText()
    {
        if (_completionStarted) return;

        var elapsed = _visibleStopwatch.ElapsedMilliseconds;
        SetProgress(StartupProgressProfile.CalculateContinuousPercent(elapsed));
        StageText.Text = elapsed switch
        {
            < 1700 => "Bileşenler hazırlanıyor...",
            < 3400 => "Veriler ve hesaplama kuralları hazırlanıyor...",
            < StartupProgressProfile.CruiseDurationMs => "Arayüz ve belgeler hazırlanıyor...",
            _ => "Son kontroller tamamlanıyor..."
        };
    }

    internal async Task CompleteAndCloseAsync()
    {
        if (_completionStarted) return;
        _completionStarted = true;
        _percentTimer?.Stop();

        StageText.Text = "Hazır. Program açılıyor...";
        var currentPercent = _percent;
        var completion = Stopwatch.StartNew();
        while (completion.ElapsedMilliseconds < StartupProgressProfile.CompletionDurationMs)
        {
            var ratio = completion.ElapsedMilliseconds / (double)StartupProgressProfile.CompletionDurationMs;
            var percent = currentPercent + (int)Math.Floor((100 - currentPercent) * (1 - Math.Pow(1 - ratio, 3)));
            SetProgress(Math.Min(99, percent));
            await Task.Delay(StartupProgressProfile.FrameDelayMs);
        }

        SetProgress(100);
        await Task.Delay(80);
        Close();
    }
}
