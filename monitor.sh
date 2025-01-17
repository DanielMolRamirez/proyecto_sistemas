#!/bin/bash
#Archivo: monitor.sh
#Ruta: /home/daniel/proyecto_sistemas/monitor.sh

#Archivos de log
LOG_FILE="/home/daniel/proyecto_sistemas/monitor_log.txt" #Archivo donde se registran los logs principales
DEBUG_FILE="/home/daniel/proyecto_sistemas/debug_log.txt" #Archivo donde se registran los detalles de depuración

#Dirección de correo
ADMIN_EMAIL="daniel.molina@ucuenca.edu.ec" #Dirección de correo para alertas
SMTP_CONFIG="/home/daniel/.msmtprc" #Configuración del cliente de correo msmtp

#Configuración de MySQL
MYSQL_USER="root" #Usuario de la base de datos
MYSQL_PASSWORD="root" #Contraseña de la base de datos
MYSQL_DB="monitoreo_recursos" #Nombre de la base de datos

#Tiempo de espera para validación del consumo
THRESHOLD_TIME=30 #Tiempo en segundos entre cada iteración del monitoreo

#Límites de consumo
CPU_THRESHOLD=60 #Umbral para ajustar prioridades basado en uso de CPU
CPU_KILL_THRESHOLD=90 #Umbral para terminar procesos basado en uso de CPU
RAM_THRESHOLD=60 #Umbral para uso de RAM

#Función para enviar correos electrónicos
send_email() {
    local subject="$1" #Título del correo
    local body="$2" #Cuerpo del correo
    #Envía el correo utilizando msmtp con la configuración indicada
    echo -e "Subject: $subject\n\n$body" | msmtp --file="$SMTP_CONFIG" "$ADMIN_EMAIL"
}

#Función para insertar datos en la base de datos con debugging
insert_into_db() {
    local cpu_usage="$1" #Porcentaje de uso de CPU
    local ram_usage="$2" #Porcentaje de uso de RAM

    #Reemplazar comas por puntos para compatibilidad con MySQL
    cpu_usage=$(echo "$cpu_usage" | sed 's/,/./g')
    ram_usage=$(echo "$ram_usage" | sed 's/,/./g')

    #Registro en archivo de depuración
    echo "Intentando insertar datos en la base de datos:" >> "$DEBUG_FILE"
    echo "CPU Usage: $cpu_usage" >> "$DEBUG_FILE"
    echo "RAM Usage: $ram_usage" >> "$DEBUG_FILE"

    #Comandos SQL para insertar los datos
    local sql_cpu="INSERT INTO uso_cpu (porcentaje) VALUES ($cpu_usage);"
    local sql_ram="INSERT INTO uso_ram (porcentaje) VALUES ($ram_usage);"

    echo "Comando SQL CPU: $sql_cpu" >> "$DEBUG_FILE"
    echo "Comando SQL RAM: $sql_ram" >> "$DEBUG_FILE"

    #Ejecutar los comandos SQL
    mysql -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DB" -e "$sql_cpu" 2>> "$DEBUG_FILE"
    mysql -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DB" -e "$sql_ram" 2>> "$DEBUG_FILE"
}

#Función para monitorear y registrar estadísticas
monitor_resources() {
    #Agregar una cabecera con la fecha actual al log
    echo "--- $(date) ---" >> "$LOG_FILE"

    #Configurar el formato numérico para decimales en el entorno
    export LC_NUMERIC="en_US.UTF-8"

    #Obtener el uso global de CPU y RAM del sistema
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')
    local ram_usage=$(free | grep Mem | awk '{print $3/$2 * 100.0}')

    #Obtener el proceso que más consume CPU
    local max_cpu_process=$(ps -eo pid,%cpu,%mem,comm --sort=-%cpu | awk 'NR==2')
    #Obtener el proceso que más consume RAM
    local max_ram_process=$(ps -eo pid,%cpu,%mem,comm --sort=-%mem | awk 'NR==2')

    #Extraer detalles del proceso que más consume CPU
    local max_cpu_pid=$(echo $max_cpu_process | awk '{print $1}')
    local max_cpu_name=$(echo $max_cpu_process | awk '{print $4}')

    #Extraer detalles del proceso que más consume RAM
    local max_ram_pid=$(echo $max_ram_process | awk '{print $1}')
    local max_ram_name=$(echo $max_ram_process | awk '{print $4}')

    #Registrar los datos obtenidos en el log principal
    echo "CPU Global: $cpu_usage%, RAM Global: $ram_usage%" >> "$LOG_FILE"
    echo "Proceso mayor CPU: PID=$max_cpu_pid, Nombre=$max_cpu_name" >> "$LOG_FILE"
    echo "Proceso mayor RAM: PID=$max_ram_pid, Nombre=$max_ram_name" >> "$LOG_FILE"

    #Registrar uso de CPU y RAM del script actual
    local script_cpu_usage=$(ps -p $$ -o %cpu=) #Obtiene el uso de CPU del script
    local script_ram_usage=$(ps -p $$ -o %mem=) #Obtiene el uso de RAM del script
    echo "Monitor script: CPU=$script_cpu_usage%, RAM=$script_ram_usage%" >> "$LOG_FILE"

    #Insertar los datos en la base de datos
    insert_into_db "$cpu_usage" "$ram_usage"
}

#Función para ajustar prioridades o terminar procesos
handle_high_usage() {
    #Obtener procesos con uso de CPU superior al umbral
    local high_usage_processes=$(ps -eo pid,%cpu,%mem,comm --sort=-%cpu | awk -v cpu_th=$CPU_THRESHOLD 'NR>1 && $2>cpu_th {print}')

    #Iterar sobre los procesos identificados
    while IFS= read -r process; do
        local pid=$(echo $process | awk '{print $1}')
        local cpu=$(echo $process | awk '{print $2}')
        local ram=$(echo $process | awk '{print $3}')
        local name=$(echo $process | awk '{print $4}')

        #Validar que el uso de CPU no exceda el 100%
        if (( $(echo "$cpu <= 100" | bc -l) )); then
            if (( $(echo "$cpu > $CPU_KILL_THRESHOLD" | bc -l) )); then
                #Terminar el proceso si supera el umbral crítico
                kill -9 "$pid"
                send_email "[ALERTA] Proceso terminado" \
                    "Se terminó el proceso con los siguientes detalles:\n\
                    - PID: $pid\n\
                    - Nombre: $name\n\
                    - Uso de CPU: $cpu%\n\
                    - Uso de RAM: $ram%"
                echo "Proceso terminado - PID: $pid, Nombre: $name, CPU: $cpu%, RAM: $ram%" >> "$LOG_FILE"
            elif (( $(echo "$cpu >= $CPU_THRESHOLD" | bc -l) )); then
                #Ajustar la prioridad del proceso si supera el umbral
                renice +10 "$pid" > /dev/null
                send_email "[ALERTA] Prioridad de proceso modificada" \
                    "Se cambió la prioridad del proceso:\n\
                    - PID: $pid\n\
                    - Nombre: $name\n\
                    - Uso de CPU: $cpu%\n\
                    - Uso de RAM: $ram%"
                echo "Prioridad ajustada - PID: $pid, Nombre: $name, CPU: $cpu%, RAM: $ram%" >> "$LOG_FILE"
            fi
        fi
    done <<< "$high_usage_processes"
}

#Bucle principal que ejecuta las funciones periódicamente
while true; do
    monitor_resources #Monitorea y registra estadísticas
    sleep $THRESHOLD_TIME #Espera antes de la próxima iteración
    handle_high_usage #Gestiona procesos con alto consumo
done
