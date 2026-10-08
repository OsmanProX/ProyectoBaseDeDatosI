USE db_acf53d_dbfinal2026;

-- Tabla 1: Rol
CREATE TABLE Rol(
    RolId       INT IDENTITY(1,1) PRIMARY KEY,
    Nombre      VARCHAR(30)  NOT NULL UNIQUE,
    Descripcion VARCHAR(100) NULL,
    Activo      BIT          NOT NULL DEFAULT 1,
    CHECK (Nombre IN ('ADMINISTRADOR','RECEPCION','TECNICO','BODEGA','CAJA'))
);

-- Tabla 2: Usuario
CREATE TABLE Usuario(
    UsuarioId       INT IDENTITY(1,1) PRIMARY KEY,
    NombreUsuario   VARCHAR(30)  NOT NULL UNIQUE,
    ContrasenaHash  VARCHAR(255) NOT NULL,
    NombreCompleto  VARCHAR(100) NOT NULL,
    Correo          VARCHAR(100) NOT NULL UNIQUE,
    Telefono        VARCHAR(15)  NULL,
    Activo          BIT          NOT NULL DEFAULT 1,
    FechaCreacion   DATETIME     NOT NULL DEFAULT GETDATE()
);



-- Tabla 3: UsuarioRol
CREATE TABLE UsuarioRol(
    RolId INT FOREIGN KEY REFERENCES Rol (RolID) NOT NULL,
    UsuarioId INT FOREIGN KEY REFERENCES Usuario (UsuarioId) NOT NULL,
    FechaAsignacion DATETIME NOT NULL DEFAULT GETDATE(),
    PRIMARY KEY (RolId, UsuarioId)
);