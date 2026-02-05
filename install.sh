#!/bin/bash
sudo cp /etc/sysctl.conf /etc/sysctl.conf.bk_$(date +%Y%m%d_%H%M%S) && sudo sh -c 'echo "kernel.pid_max = 65535
kernel.panic = 1
kernel.sysrq = 1
kernel.core_pattern = core_%e
kernel.printk = 3 4 1 3
kernel.numa_balancing = 0
kernel.sched_autogroup_enabled = 0

vm.swappiness = 10
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
vm.panic_on_oom = 1
vm.overcommit_memory = 1
vm.min_free_kbytes = 445829

net.core.default_qdisc = fq
net.core.netdev_max_backlog = 4000
net.core.rmem_max = 8388608
net.core.wmem_max = 8388608
net.core.rmem_default = 87380
net.core.wmem_default = 65536
net.core.somaxconn = 2048
net.core.optmem_max = 65536

net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_max_tw_buckets = 32768
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 0

net.ipv4.tcp_rmem = 8192 87380 8388608
net.ipv4.tcp_wmem = 8192 65536 8388608
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_notsent_lowat = 4096
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = 3
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_no_metrics_save = 0

net.ipv4.tcp_max_syn_backlog = 16112
net.ipv4.tcp_max_orphans = 65536
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 3
net.ipv4.tcp_abort_on_overflow = 0
net.ipv4.tcp_stdurg = 0
net.ipv4.tcp_rfc1337 = 0
net.ipv4.tcp_syncookies = 1

net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.ip_no_pmtu_disc = 0
net.ipv4.route.gc_timeout = 100
net.ipv4.neigh.default.gc_stale_time = 120
net.ipv4.neigh.default.gc_thresh3 = 8192
net.ipv4.neigh.default.gc_thresh2 = 4096
net.ipv4.neigh.default.gc_thresh1 = 1024

net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.arp_announce = 2
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.conf.default.arp_ignore = 1" > /etc/sysctl.conf' && sudo sysctl -p

apt-get -y update
apt-get -y install cron
bash <(curl -sL https://raw.githubusercontent.com/komari-monitor/komari-agent/refs/heads/main/install.sh) -e https://monitor.zone.id  --auto-discovery YmWZfcxmwH7RYZc8
apt-get install -y chrony
curl -fsSL https://get.docker.com | sh
apt-get update
apt-get install -y chrony docker.io docker-compose
mkdir -p /opt/backend
cd /opt/backend
bash <(curl -fLSs https://dl.nyafw.com/download/nyanpass-install.sh) rel_backend

>/opt/backend/config.yml
cat > /opt/backend/docker-compose.yaml <<-EOF
services:
  nya:
    image: alpine
    network_mode: host
    restart: always
    volumes:
      - .:/opt/backend
    working_dir: /opt/backend
    command: ./rel_backend
    logging:
      driver: "json-file"
      options:
        max-size: "50m"
        max-file: "3"
  caddy:
    image: caddy:2-alpine
    network_mode: host
    restart: always
    volumes:
      - .:/opt/backend
      - ./caddy:/etc/caddy
      - ./caddy_data:/data
    logging:
      driver: "json-file"
      options:
        max-size: "50m"
        max-file: "3"
EOF

mkdir -p /opt/backend/caddy
cat > /opt/backend/caddy/Caddyfile <<-EOF
{
    servers {
        protocols h1 h2
    }
    https_port 8443
}

domain.com {
    ## TLS 必须配置，请在下面选择一种配置方法

    # TLS 本地证书
    tls /opt/backend/caddy/domain.crt /opt/backend/caddy/domain.key
    # TLS 自动申请（适合 直连面板服务器 的用户）
    # tls your@email.com

    # TLS 自签（适合套 CDN 加速的用户）
    #tls internal

    # 前端资源
    file_server {
        root /opt/backend/public
    }

    # /api/* 反代到 backend
    reverse_proxy /api/* http://127.0.0.1:18888 {
        trusted_proxies 127.0.0.0/8 173.245.48.0/20 103.21.244.0/22 103.22.200.0/22 103.31.4.0/22 141.101.64.0/18 108.162.192.0/18 190.93.240.0/20 188.114.96.0/20 197.234.240.0/22 198.41.128.0/17 162.158.0.0/15 104.16.0.0/13 104.24.0.0/14 172.64.0.0/13 131.0.72.0/22 2400:cb00::/32 2606:4700::/32 2803:f800::/32 2405:b500::/32  2405:8100::/32 2a06:98c0::/29 2c0f:f248::/32
        header_up CF-Connecting-IP {http.request.header.CF-Connecting-IP}
    }
}
EOF
