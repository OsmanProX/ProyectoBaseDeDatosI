namespace Backend_API_Proyevto_Base_de_Datos_I.DTO
{
    public class ResponseDto
    {
        public int codigo { get; set; }
        public string? mensaje { get; set; }
        public object? data { get; set; }
        public object? data_rechazo { get; set; }
    }
}
