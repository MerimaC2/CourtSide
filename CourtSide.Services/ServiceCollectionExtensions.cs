using CourtSide.Services.Auth;
using CourtSide.Services.Payments;
using CourtSide.Services.Recommender;
using CourtSide.Services.Reports;
using CourtSide.Services.Services;
using CourtSide.Services.Validation;
using CourtSide.Shared.Services;
using FluentValidation;
using Mapster;
using MapsterMapper;
using Microsoft.Extensions.DependencyInjection;

namespace CourtSide.Services;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddCourtSideServices(this IServiceCollection services)
    {
        // Mapster: use global config; IMapper resolves via DI (ServiceMapper).
        var config = TypeAdapterConfig.GlobalSettings;
        config.Scan(typeof(ServiceCollectionExtensions).Assembly); // apply IRegister mappings
        services.AddSingleton(config);
        services.AddScoped<IMapper, ServiceMapper>();

        // FluentValidation
        services.AddValidatorsFromAssemblyContaining<CourtUpsertDtoValidator>();

        // Cross-cutting
        services.AddScoped<ICurrentUser, CurrentUser>();
        services.AddScoped<ITokenService, TokenService>();
        services.AddScoped<IAuthService, AuthService>();
        services.AddScoped<IProfileService, ProfileService>();
        services.AddScoped<ITokenRevocationService, TokenRevocationService>();

        // Domain services
        services.AddScoped<ICountryService, CountryService>();
        services.AddScoped<ICityService, CityService>();
        services.AddScoped<ISportService, SportService>();
        services.AddScoped<ISportCenterService, SportCenterService>();
        services.AddScoped<ICourtService, CourtService>();
        services.AddScoped<INotificationService, NotificationService>();
        services.AddScoped<INewsService, NewsService>();
        services.AddScoped<ICourtReviewService, CourtReviewService>();
        services.AddScoped<IAvailabilityService, AvailabilityService>();
        services.AddScoped<IReservationService, ReservationService>();
        services.AddScoped<IPaymentService, PaymentService>();
        services.AddScoped<IReportService, ReportService>();

        // Closes out reservations whose slot has elapsed (Confirmed -> Completed).
        services.AddHostedService<ReservationCompletionService>();

        // Recommender: singleton model cache, scoped query service, background re-trainer.
        services.AddSingleton<IRecommenderModel, RecommenderModel>();
        services.AddScoped<IRecommenderService, RecommenderService>();
        services.AddHostedService<RecommenderTrainingService>();

        return services;
    }
}
