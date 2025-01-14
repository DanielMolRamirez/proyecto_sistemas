#!/bin/bash
# Archivo: monitor.sh
# Ruta: /home/daniel/proyecto_sistemas/monitor.sh

# Archivo de log para estadísticas
LOG_FILE="/home/daniel/proyecto_sistemas/monitor_log.txt"

# Dirección de correo
ADMIN_EMAIL="daniel.molina@ucuenca.edu.ec"
SMTP_CONFIG="/home/daniel/.msmtprc"

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

# Función para monitorear y registrar estadísticas
monitor_resources() {
    echo "--- $(date) ---" >> "$LOG_FILE"

    # Uso de CPU por procesador
    mpstat -P ALL 1 1 | awk '/^[0-9]/ {printf "CPU%s: %.2f%%\n", $2, 100-$NF}' >> "$LOG_FILE"

    # Procesos con mayor consumo de CPU y RAM
    echo "Procesos más consumidores de recursos:" >> "$LOG_FILE"
    ps -eo pid,%cpu,%mem,comm --sort=-%cpu | head -n 10 >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
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
            # Cambiar prioridad si CPU supera el 60%
            renice +10 "$pid" > /dev/null
            send_email "[ALERTA] Prioridad de proceso modificada" \
                "Se cambió la prioridad del proceso:\n\
                - PID: $pid\n\
                - Nombre: $name\n\
                - Uso de CPU: $cpu%\n\
                - Uso de RAM: $ram%"
            echo "Prioridad ajustada - PID: $pid, Nombre: $name, CPU: $cpu%, RAM: $ram%" >> "$LOG_FILE"
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
