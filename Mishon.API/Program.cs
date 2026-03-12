using System.Text;
using System.Text.Json;
using AspNetCoreRateLimit;
using FluentValidation;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.FileProviders;
using Microsoft.IdentityModel.Tokens;
using Mishon.API.Hubs;
using Microsoft.OpenApi.Models;
using Mishon.API.Middleware;
using Mishon.API.Realtime;
using Mishon.Application.DTOs;
using Mishon.Application.Interfaces;
using Mishon.Infrastructure.Data;
using Mishon.Infrastructure.Repositories;
using Mishon.Infrastructure.Services;

var builder = WebApplication.CreateBuilder(args);

// ==========================================
// CONFIGURATION
// ==========================================

// Добавление сервисов
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
        options.JsonSerializerOptions.DefaultIgnoreCondition = System.Text.Json.Serialization.JsonIgnoreCondition.WhenWritingNull;
    });
builder.Services.AddSignalR();

// Swagger с JWT поддержкой
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "Mishon API",
        Version = "v1",
        Description = "Social Network API"
    });

    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Description = "JWT Authorization header using the Bearer scheme. Enter 'Bearer' [space] and then your token.",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.ApiKey,
        Scheme = "Bearer"
    });

    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

// ==========================================
// DATABASE
// ==========================================

builder.Services.AddDbContext<MishonDbContext>(options =>
    options.UseNpgsql(
        builder.Configuration.GetConnectionString("DefaultConnection")
    ));

// ==========================================
// JWT AUTHENTICATION
// ==========================================

var jwtKey = Environment.GetEnvironmentVariable("JWT_KEY")
    ?? builder.Configuration["Jwt:Key"]
    ?? throw new Exception("JWT Key not configured. Set JWT_KEY environment variable or add to User Secrets.");

var jwtIssuer = builder.Configuration["Jwt:Issuer"] ?? "Mishon";
var jwtAudience = builder.Configuration["Jwt:Audience"] ?? "MishonUsers";

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        ValidIssuer = jwtIssuer,
        ValidAudience = jwtAudience,
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)),
        ClockSkew = TimeSpan.Zero // Уменьшаем окно до 0 для безопасности
    };

    // Обработка 401
    options.Events = new JwtBearerEvents
    {
        OnMessageReceived = context =>
        {
            var accessToken = context.Request.Query["access_token"];
            var path = context.HttpContext.Request.Path;

            if (!string.IsNullOrWhiteSpace(accessToken) &&
                path.StartsWithSegments("/hubs/chat"))
            {
                context.Token = accessToken;
            }

            return Task.CompletedTask;
        },
        OnAuthenticationFailed = context =>
        {
            if (context.Exception.GetType() == typeof(SecurityTokenExpiredException))
            {
                context.Response.Headers.Append("Token-Expired", "true");
            }
            return Task.CompletedTask;
        }
    };
});

builder.Services.AddAuthorization();

// ==========================================
// CORS
// ==========================================

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFlutter", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader()
              .WithExposedHeaders("Token-Expired", "WWW-Authenticate");
    });
});

// ==========================================
// RATE LIMITING
// ==========================================

builder.Services.AddMemoryCache();
builder.Services.Configure<IpRateLimitOptions>(builder.Configuration.GetSection("IpRateLimiting"));
builder.Services.Configure<IpRateLimitPolicies>(builder.Configuration.GetSection("IpRateLimitingPolicies"));
builder.Services.AddInMemoryRateLimiting();
builder.Services.AddSingleton<IRateLimitConfiguration, RateLimitConfiguration>();

// ==========================================
// DEPENDENCY INJECTION
// ==========================================

// Регистрация репозиториев
builder.Services.AddScoped<IUserRepository, UserRepository>();
builder.Services.AddScoped<IPostRepository, PostRepository>();
builder.Services.AddScoped<ILikeRepository, LikeRepository>();
builder.Services.AddScoped<IFollowRepository, FollowRepository>();
builder.Services.AddScoped<ICommentRepository, CommentRepository>();

// Регистрация сервисов
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IPostService, PostService>();
builder.Services.AddScoped<IFollowService, FollowService>();
builder.Services.AddScoped<ICommentService, CommentService>();
builder.Services.AddScoped<IUserDiscoveryService, UserDiscoveryService>();
builder.Services.AddScoped<IFriendService, FriendService>();
builder.Services.AddScoped<IConversationService, ConversationService>();
builder.Services.AddScoped<IBlockService, BlockService>();
builder.Services.AddScoped<INotificationService, NotificationService>();
builder.Services.AddSingleton<IChatConnectionTracker, ChatConnectionTracker>();
builder.Services.AddSingleton<IChatRealtimeNotifier, ChatRealtimeNotifier>();

// FluentValidation
builder.Services.AddValidatorsFromAssemblyContaining<RegisterDtoValidator>();
builder.Services.AddValidatorsFromAssemblyContaining<CreateCommentDtoValidator>();
builder.Services.AddValidatorsFromAssemblyContaining<UpdateCommentDtoValidator>();
builder.Services.AddValidatorsFromAssemblyContaining<UpdateMessageDtoValidator>();

var app = builder.Build();

// ==========================================
// PIPELINE
// ==========================================

// Apply migrations on startup (для development)
if (app.Environment.IsDevelopment())
{
    using var scope = app.Services.CreateScope();
    var dbContext = scope.ServiceProvider.GetRequiredService<MishonDbContext>();
    try
    {
        await dbContext.Database.MigrateAsync();
    }
    catch (Exception ex)
    {
        var logger = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();
        logger.LogError(ex, "Error applying migrations");
    }
}

if (app.Environment.IsDevelopment())
{
    app.UseDeveloperExceptionPage(); // Детальные ошибки в development
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "Mishon API V1");
    });
}
else
{
    app.UseHsts();
    app.UseGlobalExceptionHandling();
}

if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}
app.UseCors("AllowFlutter");

// Обслуживание статических файлов из wwwroot
app.UseStaticFiles();

// Обслуживание загруженных изображений из папки uploads
var uploadsPath = Path.Combine(Directory.GetCurrentDirectory(), "uploads");
Directory.CreateDirectory(uploadsPath);

app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new PhysicalFileProvider(uploadsPath),
    RequestPath = "/uploads"
});

// Rate limiting
app.UseIpRateLimiting();

app.UseAuthentication();
app.UseMiddleware<UserPresenceMiddleware>();
app.UseAuthorization();

app.MapControllers();
app.MapHub<ChatHub>("/hubs/chat");

app.Run();
