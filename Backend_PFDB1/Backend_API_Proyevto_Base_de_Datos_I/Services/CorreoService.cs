using System.Net;
using System.Net.Mail;
using System.Security.Cryptography;

namespace Backend_API_Proyevto_Base_de_Datos_I.Services
{
    // Envía el correo de bienvenida con Gmail (SMTP).
    // El correo y la contraseña de aplicación se leen de user-secrets (NUNCA del repositorio):
    //   dotnet user-secrets set "Correo:Remitente" "techcare.grupo@gmail.com"
    //   dotnet user-secrets set "Correo:ClaveAplicacion" "xxxx xxxx xxxx xxxx"
    public class CorreoService
    {
        private readonly IConfiguration _config;

        public CorreoService(IConfiguration config)
        {
            _config = config;
        }

        public bool Configurado =>
            !string.IsNullOrWhiteSpace(_config["Correo:Remitente"]) &&
            !string.IsNullOrWhiteSpace(_config["Correo:ClaveAplicacion"]);

        public async Task EnviarBienvenidaAsync(string destino, string nombre, string tipoCliente,
                                                string usuario, string contrasenaTemporal)
        {
            if (!Configurado)
                throw new InvalidOperationException("el correo del sistema no está configurado en user-secrets (Correo:Remitente y Correo:ClaveAplicacion).");

            var remitente = _config["Correo:Remitente"]!;
            var clave = _config["Correo:ClaveAplicacion"]!.Replace(" ", "");
            var nombreSeguro = WebUtility.HtmlEncode(nombre);

            using var mensaje = new MailMessage
            {
                From = new MailAddress(remitente, "TechCare Solutions"),
                Subject = "Bienvenido(a) a TechCare Solutions",
                IsBodyHtml = true,
                Body = $"""
                    <div style="font-family:Arial,sans-serif;color:#222b38;max-width:560px">
                      <div style="background:#17375e;color:#fff;padding:16px 20px;border-bottom:4px solid #c8962e">
                        <h2 style="margin:0">TechCare Solutions</h2>
                        <small>Servicio técnico de equipos de cómputo</small>
                      </div>
                      <div style="padding:20px">
                        <p>¡Hola, <b>{nombreSeguro}</b>!</p>
                        <p>Gracias por confiar en TechCare. Le creamos una cuenta para que consulte
                           en línea el estado de sus equipos.</p>
                        <p><b>Correo:</b> {WebUtility.HtmlEncode(destino)}<br>
                           <b>Usuario:</b> {WebUtility.HtmlEncode(usuario)}<br>
                           <b>Contraseña temporal:</b> <code style="font-size:15px">{WebUtility.HtmlEncode(contrasenaTemporal)}</code></p>
                        <p>Adjuntamos su carta de bienvenida en PDF.</p>
                        <p style="color:#666;font-size:12px">No comparta su contraseña. El personal de TechCare nunca se la pedirá.</p>
                      </div>
                    </div>
                    """,
            };
            mensaje.To.Add(destino);
            mensaje.Attachments.Add(new Attachment(
                new MemoryStream(PdfBienvenida.Generar(nombre, tipoCliente, destino, usuario, DateTime.Now)),
                "Bienvenida_TechCare.pdf", "application/pdf"));

            using var smtp = new SmtpClient("smtp.gmail.com", 587)
            {
                EnableSsl = true,
                Credentials = new NetworkCredential(remitente, clave),
            };
            await smtp.SendMailAsync(mensaje);
        }

        // Contraseña temporal de 10 caracteres (sin letras confusas como O/0, l/1)
        public static string GenerarContrasenaTemporal()
        {
            const string letras = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz";
            const string numeros = "23456789";
            var c = new char[10];
            for (int i = 0; i < c.Length; i++)
            {
                var fuente = i % 3 == 2 ? numeros : letras;   // asegura números
                c[i] = fuente[RandomNumberGenerator.GetInt32(fuente.Length)];
            }
            return new string(c);
        }
    }
}
