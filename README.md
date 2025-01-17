# Monitor Script

Este repositorio contiene un script de monitoreo de recursos del sistema que registra el uso de CPU y RAM, gestiona procesos con alto consumo y envía alertas mediante correo electrónico. El script también inserta los datos de monitoreo en una base de datos MySQL para análisis posterior.

## Requisitos

Asegúrate de cumplir con los siguientes requisitos antes de ejecutar el script:

1. **Sistema Operativo**: Basado en Linux (probado en Ubuntu).
2. **Paquetes necesarios**:
   - `msmtp`: Cliente SMTP para el envío de correos.
   - `mysql-server`: Servidor MySQL para almacenamiento de datos.
   - `bc`: Calculadora básica para operaciones con números decimales.

## Instalación

### 1. Instalar `msmtp`
Ejecuta el siguiente comando para instalar `msmtp`:
```bash
sudo apt-get update
sudo apt-get -y install msmtp
```

### 2. Configurar `msmtp`
Crea el archivo de configuración `.msmtprc` en el directorio del usuario o utiliza el archivo ya proporcionado en este repositorio.

1. Copia el archivo proporcionado a tu directorio de usuario:
   ```bash
   cp .msmtprc ~/.msmtprc
   ```
2. Asigna permisos seguros al archivo:
   ```bash
   chmod 600 ~/.msmtprc
   ```
3. Edita el archivo si es necesario para actualizar las credenciales SMTP.

### 3. Instalar y configurar MySQL

#### Instalar MySQL
Ejecuta el siguiente comando para instalar el servidor MySQL:
```bash
sudo apt-get -y install mysql-server
```

#### Configurar usuario y contraseña
Durante la instalación, se te pedirá que configures una contraseña para el usuario `root`. Asegúrate de recordar esta contraseña.

#### Crear la base de datos y las tablas
1. Ingresa a MySQL:
   ```bash
   mysql -u root -p
   ```
2. Crea la base de datos `monitoreo_recursos`:
   ```sql
   CREATE DATABASE monitoreo_recursos;
   ```
3. Usa la base de datos:
   ```sql
   USE monitoreo_recursos;
   ```
4. Crea las tablas necesarias:
   ```sql
   CREATE TABLE uso_cpu (
       id INT AUTO_INCREMENT PRIMARY KEY,
       porcentaje FLOAT NOT NULL,
       timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
   );

   CREATE TABLE uso_ram (
       id INT AUTO_INCREMENT PRIMARY KEY,
       porcentaje FLOAT NOT NULL,
       timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
   );
   ```

### 4. Descargar y configurar el script
1. Copia el script `monitor.sh` en el directorio deseado. Por ejemplo:
   ```bash
   cp monitor.sh /home/usuario/proyecto_sistemas/
   ```
2. Asigna permisos de ejecución al script:
   ```bash
   chmod +x /home/usuario/proyecto_sistemas/monitor.sh
   ```

### 5. Configurar variables del script
Asegúrate de actualizar las siguientes variables en el script `monitor.sh` según tus necesidades:
- `LOG_FILE`: Ruta donde se registrarán los logs.
- `DEBUG_FILE`: Ruta para el registro de depuración.
- `ADMIN_EMAIL`: Correo electrónico donde se enviarán las alertas.
- `MYSQL_USER` y `MYSQL_PASSWORD`: Credenciales de MySQL.
- `MYSQL_DB`: Nombre de la base de datos (debe ser `monitoreo_recursos`).

## Ejecución
```bash
Abre 'crontab -e', e inserta el codigo
```
@reboot /bin/bash /home/$USER/proyecto_sistemas/monitor.sh &


## Servicio del sistema (opcional)
Para ejecutar el script como un servicio del sistema:
1. Crea un archivo de servicio:
   ```bash
   sudo nano /etc/systemd/system/monitor.service
   ```
2. Añade el siguiente contenido al archivo:
   ```
   [Unit]
   Description=Monitor de Recursos del Sistema
   After=network.target

   [Service]
   ExecStart=/home/usuario/proyecto_sistemas/monitor.sh
   Restart=always

   [Install]
   WantedBy=multi-user.target
   ```
3. Guarda y cierra el archivo.
4. Recarga los servicios del sistema:
   ```bash
   sudo systemctl daemon-reload
   ```
5. Habilita el servicio para que se inicie automáticamente:
   ```bash
   sudo systemctl enable monitor.service
   ```
6. Inicia el servicio:
   ```bash
   sudo systemctl start monitor.service
   ```

## Logs
El script genera logs en las rutas definidas en las variables `LOG_FILE` y `DEBUG_FILE`. Consulta estos archivos para obtener detalles sobre la ejecución y depuración.

