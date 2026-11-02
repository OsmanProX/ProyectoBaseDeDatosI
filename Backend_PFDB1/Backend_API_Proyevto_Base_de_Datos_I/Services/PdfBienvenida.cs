using System.Text;

namespace Backend_API_Proyevto_Base_de_Datos_I.Services
{
    // PDF de bienvenida de una página, armado a mano (sin librerías externas).
    // Usa las fuentes estándar Helvetica con WinAnsiEncoding: acepta tildes, ñ y ¡¿.
    // Por seguridad NO incluye la contraseña temporal (esa va solo en el cuerpo del correo).
    public static class PdfBienvenida
    {
        public static byte[] Generar(string nombre, string tipoCliente, string correo, string usuario, DateTime fecha)
        {
            var c = new StringBuilder();

            // Encabezado azul con línea dorada
            c.Append("0.09 0.22 0.37 rg 0 722 612 70 re f\n");
            c.Append("0.78 0.59 0.18 rg 0 718 612 4 re f\n");
            // Logo (mismo ícono Wrench del login): cuadro redondeado + llave en trazo índigo
            c.Append("0.16 0.20 0.36 rg 54 729 m 82 729 l 89.73 729 96 735.27 96 743 c 96 771 l 96 778.73 89.73 785 82 785 c 54 785 l 46.27 785 40 778.73 40 771 c 40 743 l 40 735.27 46.27 729 54 729 c h f\n");
            c.Append("0.51 0.55 0.97 RG 2.33 w 1 J 1 j 71.15 763.65 m 70.94 763.43 70.82 763.13 70.82 762.83 c 70.82 762.53 70.94 762.23 71.15 762.02 c 73.02 760.15 l 73.23 759.94 73.53 759.82 73.83 759.82 c 74.13 759.82 74.43 759.94 74.65 760.15 c 78.27 763.77 l 78.65 764.15 79.28 764.03 79.42 763.52 c 79.89 761.82 79.68 759.95 78.86 758.39 c 78.04 756.83 76.60 755.61 74.94 755.04 c 73.27 754.47 71.39 754.56 69.78 755.28 c 60.56 746.06 l 60.10 745.60 59.45 745.33 58.81 745.33 c 58.16 745.33 57.52 745.60 57.06 746.06 c 56.60 746.52 56.33 747.16 56.33 747.81 c 56.33 748.45 56.60 749.10 57.06 749.56 c 66.29 758.78 l 65.56 760.39 65.47 762.27 66.04 763.94 c 66.61 765.60 67.83 767.04 69.39 767.86 c 70.95 768.68 72.82 768.89 74.52 768.42 c 75.03 768.28 75.15 767.65 74.77 767.27 c 71.15 763.65 l h S\n");
            Texto(c, "F2", 24, 110, 757, "TechCare Solutions", true);
            Texto(c, "F1", 11, 110, 738, "Servicio técnico de equipos de cómputo", true);

            int y = 670;
            Texto(c, "F2", 18, 50, y, $"¡Bienvenido(a), {nombre}!");
            y -= 30;
            foreach (var linea in Partir(
                "Gracias por confiar en TechCare Solutions. A partir de hoy usted forma parte de nuestros clientes " +
                "y podrá consultar en línea el estado de los equipos que nos entregue para reparación.", 88))
            {
                Texto(c, "F1", 11, 50, y, linea);
                y -= 16;
            }

            y -= 14;
            Texto(c, "F2", 13, 50, y, "Datos de su registro");
            y -= 8;
            c.Append($"0.78 0.59 0.18 rg 50 {y} 512 1.5 re f\n");
            y -= 22;
            foreach (var (etiqueta, valor) in new[]
            {
                ("Cliente:", nombre),
                ("Tipo de cliente:", tipoCliente == "EMPRESARIAL" ? "Empresarial" : "Individual"),
                ("Correo:", correo),
                ("Usuario del sistema:", usuario),
                ("Fecha de registro:", fecha.ToString("dd/MM/yyyy HH:mm")),
            })
            {
                Texto(c, "F2", 11, 50, y, etiqueta);
                Texto(c, "F1", 11, 190, y, valor);
                y -= 20;
            }

            y -= 14;
            Texto(c, "F2", 13, 50, y, "¿Cómo ingresar?");
            y -= 8;
            c.Append($"0.78 0.59 0.18 rg 50 {y} 512 1.5 re f\n");
            y -= 22;
            foreach (var paso in new[]
            {
                "1. Abra el sistema TechCare e inicie sesión con su correo.",
                "2. Use la contraseña que recibió en el cuerpo del correo de bienvenida.",
                "3. En \"Mis órdenes\" verá el estado de sus equipos, su factura y el saldo pendiente.",
            })
            {
                Texto(c, "F1", 11, 50, y, paso);
                y -= 18;
            }

            y -= 16;
            foreach (var linea in Partir(
                "Por su seguridad, este documento no incluye su contraseña. No la comparta con nadie: " +
                "el personal de TechCare nunca se la pedirá.", 92))
            {
                Texto(c, "F1", 10, 50, y, linea, gris: true);
                y -= 14;
            }

            // Pie de página
            c.Append("0.09 0.22 0.37 rg 0 0 612 40 re f\n");
            Texto(c, "F1", 9, 50, 16, "TechCare Solutions · Proyecto final de Base de Datos I · UMG", true);

            return Armar(Encoding.Latin1.GetBytes(c.ToString()));
        }

        private static void Texto(StringBuilder c, string fuente, int tam, int x, int y, string texto,
                                  bool blanco = false, bool gris = false)
        {
            var color = blanco ? "1 1 1" : gris ? "0.40 0.44 0.50" : "0.13 0.17 0.22";
            c.Append($"BT {color} rg /{fuente} {tam} Tf {x} {y} Td ({Escapar(texto)}) Tj ET\n");
        }

        // En PDF los paréntesis y la barra invertida se escapan; lo que no exista en Latin1 se cambia por ?
        private static string Escapar(string s) =>
            s.Replace("\\", "\\\\").Replace("(", "\\(").Replace(")", "\\)");

        private static IEnumerable<string> Partir(string texto, int max)
        {
            var linea = new StringBuilder();
            foreach (var palabra in texto.Split(' '))
            {
                if (linea.Length + palabra.Length + 1 > max && linea.Length > 0)
                {
                    yield return linea.ToString();
                    linea.Clear();
                }
                if (linea.Length > 0) linea.Append(' ');
                linea.Append(palabra);
            }
            if (linea.Length > 0) yield return linea.ToString();
        }

        // Estructura mínima: catálogo, páginas, página, 2 fuentes y el contenido; luego la tabla xref.
        private static byte[] Armar(byte[] contenido)
        {
            const string fuente = "<< /Type /Font /Subtype /Type1 /BaseFont /{0} /Encoding /WinAnsiEncoding >>";
            var objetos = new List<byte[]>
            {
                Encoding.ASCII.GetBytes("<< /Type /Catalog /Pages 2 0 R >>"),
                Encoding.ASCII.GetBytes("<< /Type /Pages /Kids [3 0 R] /Count 1 >>"),
                Encoding.ASCII.GetBytes("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] " +
                                        "/Resources << /Font << /F1 4 0 R /F2 5 0 R >> >> /Contents 6 0 R >>"),
                Encoding.ASCII.GetBytes(string.Format(fuente, "Helvetica")),
                Encoding.ASCII.GetBytes(string.Format(fuente, "Helvetica-Bold")),
                Unir(Encoding.ASCII.GetBytes($"<< /Length {contenido.Length} >>\nstream\n"),
                     contenido, Encoding.ASCII.GetBytes("\nendstream")),
            };

            using var ms = new MemoryStream();
            void Escribir(string s) { var b = Encoding.ASCII.GetBytes(s); ms.Write(b, 0, b.Length); }

            Escribir("%PDF-1.4\n");
            var offsets = new List<long>();
            for (int i = 0; i < objetos.Count; i++)
            {
                offsets.Add(ms.Position);
                Escribir($"{i + 1} 0 obj\n");
                ms.Write(objetos[i], 0, objetos[i].Length);
                Escribir("\nendobj\n");
            }
            long xref = ms.Position;
            Escribir($"xref\n0 {objetos.Count + 1}\n0000000000 65535 f \n");
            foreach (var o in offsets) Escribir($"{o:D10} 00000 n \n");
            Escribir($"trailer\n<< /Size {objetos.Count + 1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n");
            return ms.ToArray();
        }

        private static byte[] Unir(params byte[][] partes) => partes.SelectMany(p => p).ToArray();
    }
}
