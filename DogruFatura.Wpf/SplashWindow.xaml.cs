using System.Diagnostics;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;

namespace DogruFatura.Wpf;

public partial class SplashWindow : Window
{
    private const double RingCenter = 60;
    private const double RingRadius = 54;
    private const int SegmentCount = 28;
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
        ProgressTrack.Data = CreateRing(100);
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
        if (percent == _percent) return;
        _percent = percent;
        PercentText.Text = $"%{percent}";
        ProgressArc.Data = CreateRing(percent);
    }

    private static StreamGeometry CreateRing(int percent)
    {
        var geometry = new StreamGeometry();
        using (var context = geometry.Open())
        {
            var segmentAngle = 2 * Math.PI / SegmentCount;
            var progressAngle = percent * 2 * Math.PI / 100;
            for (var index = 0; index < SegmentCount; index++)
            {
                var start = index * segmentAngle + .013;
                if (start >= progressAngle) break;
                var end = Math.Min(progressAngle, (index + 1) * segmentAngle - .013);
                context.BeginFigure(PointOnRing(start), false, false);
                context.ArcTo(PointOnRing(end), new Size(RingRadius, RingRadius), 0, false, SweepDirection.Clockwise, true, false);
            }
        }
        geometry.Freeze();
        return geometry;
    }

    private static Point PointOnRing(double angle) =>
        new(RingCenter + RingRadius * Math.Sin(angle), RingCenter - RingRadius * Math.Cos(angle));

    private void SetStages(int activeStage)
    {
        var pending = (Brush)FindResource("StagePending");
        var done = (Brush)FindResource("StageDone");
        var active = (Brush)FindResource("StageActive");
        StageOne.Stroke = activeStage > 0 ? done : active;
        StageTwo.Stroke = activeStage == 1 ? active : activeStage > 1 ? done : pending;
        StageThree.Stroke = activeStage == 2 ? active : activeStage > 2 ? done : pending;
        StageOneCheck.Visibility = activeStage > 0 ? Visibility.Visible : Visibility.Collapsed;
        StageTwoCheck.Visibility = activeStage > 1 ? Visibility.Visible : Visibility.Collapsed;
        StageThreeCheck.Visibility = activeStage > 2 ? Visibility.Visible : Visibility.Collapsed;
        ActiveStageDot.Visibility = activeStage == 3 ? Visibility.Collapsed : Visibility.Visible;
        Canvas.SetTop(ActiveStageDot, 7.5 + 40 * activeStage);
    }

    private void UpdateProgressText()
    {
        if (_completionStarted) return;

        var elapsed = _visibleStopwatch.ElapsedMilliseconds;
        SetProgress(StartupProgressProfile.CalculateContinuousPercent(elapsed));
        SetStages(elapsed < 1700 ? 0 : elapsed < 3400 ? 1 : 2);
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
        SetStages(3);
        await Task.Delay(80);
        Close();
    }
}
