using System.Text;
using System.Text.Json.Serialization;
using CourtSide.Api.Middleware;
using CourtSide.Core.Entities.Identity;
using CourtSide.Infrastructure;
using CourtSide.Infrastructure.Seed;
using CourtSide.Services;
using CourtSide.Shared.Models;
using DotNetEnv;
using FluentValidation.AspNetCore;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;

// Load .env for local development. In Docker, configuration comes from env_file.
Env.TraversePath().Load();

var builder = WebApplication.CreateBuilder(args);

string RequireEnv(string key) =>
    Environment.GetEnvironmentVariable(key)
    ?? throw new InvalidOperationException($"Nedostaje konfiguracija u .env: {key}");

string OptionalEnv(string key, string fallback) =>
    Environment.GetEnvironmentVariable(key) is { Length: > 0 } v ? v : fallback;

var connectionString = RequireEnv("CONNECTION_STRING");

var jwt = new JwtSettings
{
    Key = RequireEnv("JWT_TOKEN_KEY"),
    Issuer = OptionalEnv("JWT_ISSUER", "CourtSide"),
    Audience = OptionalEnv("JWT_AUDIENCE", "CourtSideClients"),
    ExpiryMinutes = int.TryParse(OptionalEnv("JWT_EXPIRY_MINUTES", "120"), out var mins) ? mins : 120
};
builder.Services.AddSingleton(Options.Create(jwt));

var corsOrigins = OptionalEnv("CORS_ALLOWED_ORIGINS", "")
    .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

// ----- Persistence -----
builder.Services.AddDbContext<DatabaseContext>(options => options.UseSqlServer(connectionString));

// ----- Identity -----
builder.Services.AddIdentity<ApplicationUser, ApplicationRole>(options =>
    {
        options.Password.RequiredLength = 4;
        options.Password.RequireNonAlphanumeric = false;
        options.Password.RequireUppercase = false;
        options.Password.RequireLowercase = false;
        options.Password.RequireDigit = false;
        options.User.RequireUniqueEmail = true;
    })
    .AddEntityFrameworkStores<DatabaseContext>()
    .AddDefaultTokenProviders();

// ----- JWT authentication -----
builder.Services.AddAuthentication(options =>
    {
        // Override the cookie schemes that AddIdentity sets as default, so JWT is used everywhere.
        options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
        options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
        options.DefaultScheme = JwtBearerDefaults.AuthenticationScheme;
    })
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwt.Issuer,
            ValidAudience = jwt.Audience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.Key))
        };
    });
builder.Services.AddAuthorization();
builder.Services.AddHttpContextAccessor();

// ----- MVC + JSON (enums as strings) -----
builder.Services.AddControllers()
    .AddJsonOptions(o => o.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter()));
builder.Services.AddFluentValidationAutoValidation();

// ----- Application services (Mapster, validators, domain services) -----
builder.Services.AddCourtSideServices();

// ----- CORS -----
builder.Services.AddCors(options => options.AddPolicy("DefaultCors", policy =>
{
    if (corsOrigins.Length > 0) policy.WithOrigins(corsOrigins);
    else policy.AllowAnyOrigin();
    policy.AllowAnyHeader().AllowAnyMethod();
}));

// ----- Swagger (with JWT bearer) -----
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "CourtSide API", Version = "v1" });
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = ParameterLocation.Header,
        Description = "Unesite JWT token (bez 'Bearer' prefiksa)."
    });
    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" }
            },
            Array.Empty<string>()
        }
    });
});

var app = builder.Build();

// ----- Apply migrations + seed at startup -----
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<DatabaseContext>();
    await db.Database.MigrateAsync();
    await DatabaseSeeder.SeedAsync(scope.ServiceProvider);
}

app.UseMiddleware<ExceptionHandlingMiddleware>();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors("DefaultCors");
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

app.Run();
