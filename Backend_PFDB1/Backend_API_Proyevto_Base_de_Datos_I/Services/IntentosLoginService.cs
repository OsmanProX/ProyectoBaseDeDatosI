using System.Collections.Concurrent;

namespace Backend_API_Proyevto_Base_de_Datos_I.Services
{
    // Cuenta los intentos FALLIDOS de inicio de sesión por computadora (IP) y usuario.
    // Después de 5 fallos seguidos, ese usuario queda bloqueado 60 segundos en esa computadora.
    // Vive en la memoria de la API (no usa la base de datos): al reiniciar el backend se limpia.
    public class IntentosLoginService
    {
        public const int MaxIntentos = 5;
        public static readonly TimeSpan Bloqueo = TimeSpan.FromSeconds(60);

        private sealed class Registro
        {
            public int Fallos;
            public DateTime? BloqueadoHasta;
        }

        private readonly ConcurrentDictionary<string, Registro> _registros = new();

        public static string Clave(string? ip, string usuario) =>
            $"{ip ?? "sin-ip"}|{usuario.Trim().ToLowerInvariant()}";

        // Segundos que faltan si está bloqueado; 0 si puede intentar.
        public int SegundosBloqueado(string clave)
        {
            if (!_registros.TryGetValue(clave, out var r) || r.BloqueadoHasta is null) return 0;
            var faltan = r.BloqueadoHasta.Value - DateTime.UtcNow;
            if (faltan <= TimeSpan.Zero)
            {
                _registros.TryRemove(clave, out _); // pasó el minuto: vuelve a empezar
                return 0;
            }
            return (int)Math.Ceiling(faltan.TotalSeconds);
        }

        // Suma un fallo y devuelve cuántos intentos le quedan (0 = queda bloqueado).
        public int RegistrarFallo(string clave)
        {
            var r = _registros.GetOrAdd(clave, _ => new Registro());
            lock (r)
            {
                r.Fallos++;
                var restantes = Math.Max(0, MaxIntentos - r.Fallos);
                if (restantes == 0) r.BloqueadoHasta = DateTime.UtcNow.Add(Bloqueo);
                return restantes;
            }
        }

        public void Limpiar(string clave) => _registros.TryRemove(clave, out _);
    }
}
