#!/bin/sh
# Roda a API e o nginx no mesmo container. Se um dos dois cair, derruba o
# outro e sai com erro, pra o Coolify reiniciar o container.

su-exec app /usr/local/bin/lang-detector &
app_pid=$!

nginx -g 'daemon off;' &
nginx_pid=$!

shutdown() {
    kill -TERM "$app_pid" "$nginx_pid" 2>/dev/null
    wait
    exit 0
}
trap shutdown TERM INT

# Polling em vez de `wait -n`: no ash do busybox ele só retorna quando o filho
# sai com código 0, então um crash da API passaria despercebido.
while kill -0 "$app_pid" 2>/dev/null && kill -0 "$nginx_pid" 2>/dev/null; do
    sleep 1
done

kill -TERM "$app_pid" "$nginx_pid" 2>/dev/null
wait
exit 1
