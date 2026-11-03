/* ==========================================================
   15_cliente_correo_unico.sql
   Un correo no se puede repetir entre clientes.
   Índice único FILTRADO: permite varios clientes sin correo (NULL),
   pero no dos clientes con el mismo correo.
   Antes de crearlo se verifica que no existan duplicados.
   ========================================================== */
IF EXISTS (SELECT 1 FROM dbo.Cliente WHERE Correo IS NOT NULL
           GROUP BY LOWER(LTRIM(RTRIM(Correo))) HAVING COUNT(*) > 1)
BEGIN
    SELECT LOWER(LTRIM(RTRIM(Correo))) AS CorreoRepetido, COUNT(*) AS Veces
    FROM dbo.Cliente WHERE Correo IS NOT NULL
    GROUP BY LOWER(LTRIM(RTRIM(Correo))) HAVING COUNT(*) > 1;
    THROW 51871, 'Hay correos repetidos entre clientes: corríjalos antes de crear el índice.', 1;
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_Cliente_Correo')
    CREATE UNIQUE NONCLUSTERED INDEX UX_Cliente_Correo ON dbo.Cliente (Correo) WHERE Correo IS NOT NULL;
GO

-- Verificación: debe salir UX_Cliente_Correo con is_unique = 1
SELECT OBJECT_NAME(object_id) AS Tabla, name AS Indice, is_unique, filter_definition
FROM sys.indexes WHERE name IN ('UQ_Usuario_Correo', 'UX_Cliente_Correo');
GO
