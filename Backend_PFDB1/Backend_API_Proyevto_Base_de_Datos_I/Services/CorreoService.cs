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
                                                string usuario, string? contrasenaTemporal)
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
                        <table role="presentation" cellpadding="0" cellspacing="0"><tr><td style="padding-right:12px"><img src="cid:logo" width="44" height="44" alt="TechCare" style="display:block;border-radius:10px"></td><td><h2 style="margin:0">TechCare Solutions</h2></td></tr></table>
                        <small>Servicio técnico de equipos de cómputo</small>
                      </div>
                      <div style="padding:20px">
                        <p>¡Hola, <b>{nombreSeguro}</b>!</p>
                        <p>Gracias por confiar en TechCare. Le creamos una cuenta para que consulte
                           en línea el estado de sus equipos.</p>
                        <p><b>Correo:</b> {WebUtility.HtmlEncode(destino)}<br>
                           <b>Usuario:</b> {WebUtility.HtmlEncode(usuario)}<br>
                           {(contrasenaTemporal is null
                               ? "<b>Contraseña:</b> la que usted eligió al registrarse."
                               : $"<b>Contraseña:</b> <code style=\"font-size:15px\">{WebUtility.HtmlEncode(contrasenaTemporal)}</code>")}</p>
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

            await Enviar(mensaje, remitente, clave);
        }

        // "¿Olvidó su contraseña?": envía la contraseña temporal nueva
        public async Task EnviarRecuperacionAsync(string destino, string nombre, string usuario, string contrasenaTemporal)
        {
            if (!Configurado)
                throw new InvalidOperationException("el correo del sistema no está configurado en user-secrets.");

            var remitente = _config["Correo:Remitente"]!;
            var clave = _config["Correo:ClaveAplicacion"]!.Replace(" ", "");
            using var mensaje = new MailMessage
            {
                From = new MailAddress(remitente, "TechCare Solutions"),
                Subject = "Recuperación de contraseña - TechCare Solutions",
                IsBodyHtml = true,
                Body = $"""
                    <div style="font-family:Arial,sans-serif;color:#222b38;max-width:560px">
                      <div style="background:#17375e;color:#fff;padding:16px 20px;border-bottom:4px solid #c8962e">
                        <table role="presentation" cellpadding="0" cellspacing="0"><tr><td style="padding-right:12px"><img src="cid:logo" width="44" height="44" alt="TechCare" style="display:block;border-radius:10px"></td><td><h2 style="margin:0">TechCare Solutions</h2></td></tr></table>
                      </div>
                      <div style="padding:20px">
                        <p>Hola, <b>{WebUtility.HtmlEncode(nombre)}</b>.</p>
                        <p>Recibimos una solicitud para recuperar su contraseña.</p>
                        <p><b>Usuario:</b> {WebUtility.HtmlEncode(usuario)}<br>
                           <b>Contraseña:</b> <code style="font-size:15px">{WebUtility.HtmlEncode(contrasenaTemporal)}</code></p>
                        <p>Inicie sesión con ella y cámbiela en "Cambiar contraseña".</p>
                        <p style="color:#666;font-size:12px">Si usted no lo solicitó, avise a TechCare.</p>
                      </div>
                    </div>
                    """,
            };
            mensaje.To.Add(destino);
            await Enviar(mensaje, remitente, clave);
        }

        // Comprobante de entrega (Caja → Entregadas) con el PDF adjunto
        public async Task EnviarComprobanteAsync(string destino, string nombre, string numeroOrden, byte[] pdf)
        {
            if (!Configurado)
                throw new InvalidOperationException("el envío de correos no está configurado en user-secrets.");

            var remitente = _config["Correo:Remitente"]!;
            var clave = _config["Correo:ClaveAplicacion"]!.Replace(" ", "");
            using var mensaje = new MailMessage
            {
                From = new MailAddress(remitente, "TechCare Solutions"),
                Subject = $"Comprobante de entrega {numeroOrden} - TechCare Solutions",
                IsBodyHtml = true,
                Body = $"""
                    <div style="font-family:Arial,sans-serif;color:#222b38;max-width:560px">
                      <div style="background:#17375e;color:#fff;padding:16px 20px;border-bottom:4px solid #c8962e">
                        <table role="presentation" cellpadding="0" cellspacing="0"><tr><td style="padding-right:12px"><img src="cid:logo" width="44" height="44" alt="TechCare" style="display:block;border-radius:10px"></td><td><h2 style="margin:0">TechCare Solutions</h2></td></tr></table>
                      </div>
                      <div style="padding:20px">
                        <p>Hola, <b>{WebUtility.HtmlEncode(nombre)}</b>.</p>
                        <p>Adjuntamos el comprobante de entrega de su orden <b>{WebUtility.HtmlEncode(numeroOrden)}</b>,
                           con el detalle de la factura y los pagos.</p>
                        <p>Gracias por confiar en TechCare.</p>
                      </div>
                    </div>
                    """,
            };
            mensaje.To.Add(destino);
            mensaje.Attachments.Add(new Attachment(new MemoryStream(pdf), $"Comprobante_{numeroOrden}.pdf", "application/pdf"));
            await Enviar(mensaje, remitente, clave);
        }

        // Logo de TechCare (96x96 PNG) que se incrusta en el correo como imagen cid:logo
        private const string LogoBase64 = "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";

        private static async Task Enviar(MailMessage mensaje, string remitente, string clave)
        {
            if (mensaje.IsBodyHtml && mensaje.Body.Contains("cid:logo"))
            {
                var vista = AlternateView.CreateAlternateViewFromString(mensaje.Body, System.Text.Encoding.UTF8, "text/html");
                var logo = new LinkedResource(new MemoryStream(Convert.FromBase64String(LogoBase64)), "image/png")
                {
                    ContentId = "logo",
                };
                vista.LinkedResources.Add(logo);
                mensaje.AlternateViews.Add(vista);
            }
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
