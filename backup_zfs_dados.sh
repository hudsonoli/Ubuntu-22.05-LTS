#!/bin/bash
###############################################################################
# Sincronização /DADOS -> /ARQUIVO + Snapshot ZFS
# Server: POWEREDGE
# Manutenção: Mantém os últimos 7 snapshots (1 por dia)
###############################################################################

# ===== VARIÁVEIS =====
DATA=$(date +"%Y-%m-%d_%H-%M")
LOG_DIR="/SCRIPTS/LOGS"
LOG="$LOG_DIR/sync_zfs_$DATA.log"

# Garante que o diretório de log existe
mkdir -p "$LOG_DIR"

ORIGEM="/DADOS"
DESTINO="/ARQUIVO"
POOL="IronWolf10Tb"

PASTAS=(
  "EXECCONTAS"
  "MIDIA"
  "PRODUCAO"
  "FATURAMENTO"
  "FINANCEIRO"
)

# ===== INÍCIO =====
echo "===============================" >> "$LOG"
echo "Início: $(date)" >> "$LOG"
echo "===============================" >> "$LOG"

# ===== LOOP DE SINCRONIZAÇÃO E SNAPSHOT =====
for PASTA in "${PASTAS[@]}"; do
    echo "" >> "$LOG"
    echo ">>> Processando $PASTA" >> "$LOG"

    # 1. Sincronismo RSYNC
    rsync -avh --delete \
        "$ORIGEM/$PASTA/" \
        "$DESTINO/$PASTA/" >> "$LOG" 2>&1

    if [ $? -eq 0 ]; then
        echo "OK - Sync $PASTA concluído" >> "$LOG"
        
        # 2. Criação do Snapshot (SÓ CRIA SE O SYNC DEU CERTO)
        SNAPSHOT_NAME="$POOL/$PASTA@daily-$DATA"
        echo "Criando snapshot: $SNAPSHOT_NAME" >> "$LOG"
        zfs snapshot "$SNAPSHOT_NAME" >> "$LOG" 2>&1

        # 3. Limpeza Automática (Mantém os 7 mais recentes)
        echo "Limpando snapshots antigos de $PASTA..." >> "$LOG"
        # Lista snapshots, ordena por criação (S), pega os nomes (-o name) 
        # e apaga todos a partir do 8º (tail -n +8)
        zfs list -t snapshot -H -S creation -o name | grep "$POOL/$PASTA@" | tail -n +8 | xargs -n 1 zfs destroy >> "$LOG" 2>&1
    else
        echo "ERRO CRÍTICO - Falha no sync de $PASTA. Snapshot não realizado." >> "$LOG"
    fi
done

# ===== FIM =====
echo "" >> "$LOG"
echo "Fim: $(date)" >> "$LOG"
echo "===============================" >> "$LOG"
