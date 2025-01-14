#!/bin/bash
# Archivo: monitor.sh
# Ruta: /home/daniel/proyecto_sistemas/monitor.sh

# Archivo de log para estadísticas
LOG_FILE="/home/daniel/proyecto_sistemas/monitor_log.txt"

# Dirección de correo
ADMIN_EMAIL="daniel.molina@ucuenca.edu.ec"
SMTP_CONFIG="/home/daniel/.msmtprc"

# Configuración de MySQL
MYSQL_USER="root"
MYSQL_PASSWORD="root"
MYSQL_DB="monitor_stats"

# Tiempo de espera para validación del consumo
THRESHOLD_TIME=30

# Limites de consumo
CPU_THRESHOLD=60
CPU_KILL_THRESHOLD=90
RAM_THRESHOLD=60

# Función para enviar correo
send_email() {
    local subject="$1"
    local body="$2"
    echo -e "Subject: $subject\n\n$body" | msmtp --file="$SMTP_CONFIG" "$ADMIN_EMAIL"
}

# Función para insertar datos en la base de datos
insert_into_db() {
    local cpu_usage="$1"
    local ram_usage="$2"
    local max_cpu_pid="$3"
    local max_cpu_name="$4"
    local max_ram_pid="$5"
    local max_ram_name="$6"

    mysql -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DB" <<EOF
INSERT INTO resource_usage (cpu_usage, ram_usage, max_cpu_pid, max_cpu_name, max_ram_pid, max_ram_name)
VALUES ($cpu_usage, $ram_usage, $max_cpu_pid, '$max_cpu_name', $max_ram_pid, '$max_ram_name');
EOF
}

# Función para monitorear y registrar estadísticas
monitor_resources() {
    echo "--- $(date) ---" >> "$LOG_FILE"

    # Uso de CPU y RAM global
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')
    local ram_usage=$(free | grep Mem | awk '{print $3/$2 * 100.0}')

    # Procesos con mayor consumo de CPU y RAM
    local max_cpu_process=$(ps -eo pid,%cpu,%mem,comm --sort=-%cpu | awk 'NR==2')
    local max_ram_process=$(ps -eo pid,%cpu,%mem,comm --sort=-%mem | awk 'NR==2')

    local max_cpu_pid=$(echo $max_cpu_process | awk '{print $1}')
    local max_cpu_name=$(echo $max_cpu_process | awk '{print $4}')

    local max_ram_pid=$(echo $max_ram_process | awk '{print $1}')
    local max_ram_name=$(echo $max_ram_process | awk '{print $4}')

    # Registrar en el archivo de log
    echo "CPU Global: $cpu_usage%, RAM Global: $ram_usage%" >> "$LOG_FILE"
    echo "Proceso mayor CPU: PID=$max_cpu_pid, Nombre=$max_cpu_name" >> "$LOG_FILE"
    echo "Proceso mayor RAM: PID=$max_ram_pid, Nombre=$max_ram_name" >> "$LOG_FILE"

    # Insertar en la base de datos
    insert_into_db "$cpu_usage" "$ram_usage" "$max_cpu_pid" "$max_cpu_name" "$max_ram_pid" "$max_ram_name"
}

# Función para ajustar prioridades o terminar procesos
handle_high_usage() {
    # Procesos que superan el umbral
    local high_usage_processes=$(ps -eo pid,%cpu,%mem,comm --sort=-%cpu | awk -v cpu_th=$CPU_THRESHOLD 'NR>1 && $2>cpu_th {print}')

    while IFS= read -r process; do
        local pid=$(echo $process | awk '{print $1}')
        local cpu=$(echo $process | awk '{print $2}')
        local ram=$(echo $process | awk '{print $3}')
        local name=$(echo $process | awk '{print $4}')

        # Verificar que el uso de CPU sea un valor numérico válido
        if ! [[ $cpu =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            echo "Error: Uso de CPU no válido ($cpu%) para PID: $pid, Nombre: $name" >> "$LOG_FILE"
            continue
        fi

        # Ignorar valores absurdos o erróneos (> 100%)
        if (( $(echo "$cpu > 100" | bc -l) )); then
            echo "Advertencia: Uso de CPU mayor a 100% detectado ($cpu%) para PID: $pid, Nombre: $name" >> "$LOG_FILE"
            continue
        fi

        # Si supera el 90% de CPU, matar el proceso
        if (( $(echo "$cpu > $CPU_KILL_THRESHOLD" | bc -l) )); then
            kill -9 "$pid"
            send_email "[ALERTA] Proceso terminado" \
                "Se terminó el proceso con los siguientes detalles:\n\
                - PID: $pid\n\
                - Nombre: $name\n\
                - Uso de CPU: $cpu%\n\
                - Uso de RAM: $ram%"
            echo "Proceso terminado - PID: $pid, Nombre: $name, CPU: $cpu%, RAM: $ram%" >> "$LOG_FILE"
        else
            # Cambiar prioridad si CPU supera el 60% por más de 30 segundos
            if (( $(echo "$cpu >= $CPU_THRESHOLD" | bc -l) )); then
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

# Monitoreo continuo
while true; do
    monitor_resources

    # Validar consumo elevado por más de 30 segundos
    sleep $THRESHOLD_TIME

    handle_high_usage

done
