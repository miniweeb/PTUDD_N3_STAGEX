using Microsoft.ML;
using Microsoft.ML.Data;
using Microsoft.ML.Transforms.TimeSeries;
using System;
using System.Collections.Generic;
using System.Linq;

namespace StageX_DesktopApp.Services
{
    // Input model cho ML
    public class RevenueInput
    {
        public DateTime Date { get; set; }
        public float TotalRevenue { get; set; }
    }

    // Output model
    public class RevenueForecast
    {
        public float[] ForecastedRevenue { get; set; }
        public float[] LowerBoundRevenue { get; set; }
        public float[] UpperBoundRevenue { get; set; }
    }

    public class RevenueForecastingService
    {
        public RevenueForecast Predict(List<RevenueInput> historyData, int horizon)
        {
            if (historyData == null || historyData.Count < 6) return null; // Cần tối thiểu dữ liệu

            var mlContext = new MLContext();
            var dataView = mlContext.Data.LoadFromEnumerable(historyData);

            // Pipeline dự báo (SSA)
            var forecastingPipeline = mlContext.Forecasting.ForecastBySsa(
                outputColumnName: nameof(RevenueForecast.ForecastedRevenue),
                inputColumnName: nameof(RevenueInput.TotalRevenue),
                windowSize: 3,
                seriesLength: historyData.Count,
                trainSize: historyData.Count,
                horizon: horizon,
                confidenceLevel: 0.95f,
                confidenceLowerBoundColumn: nameof(RevenueForecast.LowerBoundRevenue),
                confidenceUpperBoundColumn: nameof(RevenueForecast.UpperBoundRevenue));

            var model = forecastingPipeline.Fit(dataView);
            var forecastingEngine = model.CreateTimeSeriesEngine<RevenueInput, RevenueForecast>(mlContext);

            return forecastingEngine.Predict();
        }
    }
}