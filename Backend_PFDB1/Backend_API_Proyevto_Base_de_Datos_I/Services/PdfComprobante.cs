using System.Text;
using Backend_API_Proyevto_Base_de_Datos_I.Models;
using static Backend_API_Proyevto_Base_de_Datos_I.Services.PdfBienvenida;

namespace Backend_API_Proyevto_Base_de_Datos_I.Services
{
    // Comprobante de entrega (Caja → Entregadas): orden, factura, pagos y entrega, en una página.
    public static class PdfComprobante
    {
        private static string Q(decimal n) => "Q " + n.ToString("#,##0.00");

        public static byte[] Generar(OrdenCajaModel o, FacturaModel f, IEnumerable<PagoModel> pagos, EntregaModel e)
        {
            var c = new StringBuilder();
            Encabezado(c);

            int y = 682;
            Texto(c, "F2", 17, 50, y, "Comprobante de entrega");
            Texto(c, "F1", 10, 400, y, $"Orden {o.NumeroOrden}");
            y -= 26;

            void Seccion(string titulo)
            {
                y -= 6;
                Texto(c, "F2", 12, 50, y, titulo);
                y -= 6;
                c.Append($"0.78 0.59 0.18 rg 50 {y} 512 1.2 re f\n");
                y -= 16;
            }
            void Dato(string etiqueta, string valor, int x = 50, int xv = 165)
            {
                Texto(c, "F2", 10, x, y, etiqueta);
                Texto(c, "F1", 10, xv, y, valor);
            }

            Seccion("Cliente y equipo");
            Dato("Cliente:", o.Cliente); y -= 15;
            Dato("NIT:", o.NIT); y -= 15;
            Dato("Equipo:", o.Equipo); y -= 15;
            Dato("Número de serie:", o.NumeroSerie); y -= 15;
            Dato("Ingreso:", o.FechaIngreso.ToString("dd/MM/yyyy HH:mm")); y -= 12;

            Seccion($"Factura {f.NumeroFactura}");
            Dato("A nombre de:", $"{f.NombreFacturacion} · NIT {f.NITFacturacion}"); y -= 15;
            Dato("Emitida:", $"{f.FechaEmision:dd/MM/yyyy HH:mm} por {f.EmitidaPor}"); y -= 18;
            foreach (var (et, val, negrita) in new[]
            {
                ("Mano de obra", f.TotalManoObra, false), ("Repuestos", f.TotalRepuestos, false),
                ("Subtotal", f.Subtotal, false), ("IVA 12 %", f.Impuesto, false), ("Total", f.Total, true),
            })
            {
                Texto(c, negrita ? "F2" : "F1", 10, 300, y, et);
                Texto(c, negrita ? "F2" : "F1", 10, 470, y, Q(val));
                y -= 14;
            }
            y -= 4;

            Seccion("Pagos");
            Texto(c, "F2", 9, 50, y, "Fecha"); Texto(c, "F2", 9, 160, y, "Método");
            Texto(c, "F2", 9, 260, y, "Referencia"); Texto(c, "F2", 9, 400, y, "Monto"); Texto(c, "F2", 9, 470, y, "Cobró");
            y -= 14;
            foreach (var p in pagos)
            {
                Texto(c, "F1", 9, 50, y, p.FechaPago.ToString("dd/MM/yyyy HH:mm"));
                Texto(c, "F1", 9, 160, y, p.Metodo);
                Texto(c, "F1", 9, 260, y, p.Referencia ?? "-");
                Texto(c, "F1", 9, 400, y, Q(p.Monto));
                Texto(c, "F1", 9, 470, y, p.CobradoPor.Length > 22 ? p.CobradoPor[..22] : p.CobradoPor);
                y -= 13;
                if (y < 200) break;
            }
            Texto(c, "F2", 10, 300, y - 2, "Saldo pendiente");
            Texto(c, "F2", 10, 470, y - 2, Q(f.SaldoPendiente));
            y -= 20;

            Seccion("Entrega del equipo");
            Dato("Fecha:", e.FechaEntrega.ToString("dd/MM/yyyy HH:mm")); y -= 15;
            Dato("Recibió:", e.NombreRecibe); y -= 15;
            Dato("Entregó:", e.EntregadoPor); y -= 15;
            if (!string.IsNullOrWhiteSpace(e.Observaciones))
                foreach (var linea in Partir("Observaciones: " + e.Observaciones, 90)) { Texto(c, "F1", 10, 50, y, linea); y -= 14; }

            Texto(c, "F1", 9, 50, 60, "Gracias por confiar en TechCare Solutions.", gris: true);
            c.Append("0.09 0.22 0.37 rg 0 0 612 40 re f\n");
            Texto(c, "F1", 9, 50, 16, $"TechCare Solutions · Generado el {DateTime.Now:dd/MM/yyyy HH:mm}", true);

            return Armar(Encoding.Latin1.GetBytes(c.ToString()));
        }
    }
}
