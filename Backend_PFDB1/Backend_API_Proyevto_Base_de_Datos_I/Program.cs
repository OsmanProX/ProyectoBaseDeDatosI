using System.Text;
using Backend_API_Proyevto_Base_de_Datos_I.BD;
using Backend_API_Proyevto_Base_de_Datos_I.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Services.AddSingleton<DBContext>();
builder.Services.AddScoped<JwtService>();

var jwtKey = builder.Configuration["Jwt:Key"]
    ?? throw new InvalidOperationException("Jwt:Key no esta configurada.");

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)),
            ValidateIssuer = true,
            ValidIssuer = builder.Configuration["Jwt:Issuer"],
            ValidateAudience = true,
            ValidAudience = builder.Configuration["Jwt:Audience"],
            ValidateLifetime = true,
            ClockSkew = TimeSpan.Zero
        };
    });

// Políticas de autorización por rol (el JWT trae el rol como claim role).
// Mapa de roles según 08_permisos.sql:
//   ADMINISTRADOR y RECEPCION: ver, crear y cambiar estado de órdenes
//   TECNICO: ver y cambiar estado
//   BODEGA y CAJA: solo ver
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("VerOrdenes",
        p => p.RequireRole("ADMINISTRADOR", "RECEPCION", "TECNICO", "BODEGA", "CAJA"));
    options.AddPolicy("CrearOrdenes",
        p => p.RequireRole("ADMINISTRADOR", "RECEPCION"));
    options.AddPolicy("CambiarEstadoOrden",
        p => p.RequireRole("ADMINISTRADOR", "RECEPCION", "TECNICO"));
});

// CORS: permite llamar a la API desde el frontend Vue en desarrollo
// (Vite escucha en 127.0.0.1 y localhost; para el navegador son orígenes distintos)
builder.Services.AddCors(options =>
    options.AddPolicy("Frontend", policy =>
        policy.WithOrigins("http://localhost:5173", "http://127.0.0.1:5173")
              .AllowAnyHeader()
              .AllowAnyMethod()));

var app = builder.Build();

// Configure the HTTP request pipeline.

app.UseSwagger();
app.UseSwaggerUI();

app.UseCors("Frontend");

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.Run();
